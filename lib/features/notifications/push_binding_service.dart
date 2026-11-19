import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import '../auth/account_service.dart';
import '../chat/chat_service.dart';

abstract interface class PushBindingStore {
  Future<List<Map<String, dynamic>>> read(String scope);
  Future<void> write(String scope, List<Map<String, dynamic>> records);
}

class SecurePushBindingStore implements PushBindingStore {
  const SecurePushBindingStore();
  static const _storage = FlutterSecureStorage();
  String _key(String scope) => 'bots.apns.bindings.v1.$scope';
  @override
  Future<List<Map<String, dynamic>>> read(String scope) async {
    final raw = await _storage.read(key: _key(scope));
    if (raw == null) return [];
    // Do not silently discard a damaged ledger and claim that unbinding worked.
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<void> write(String scope, List<Map<String, dynamic>> records) =>
      _storage.write(key: _key(scope), value: jsonEncode(records));
}

/// One authenticated owner, one serial queue. Records contain no login token.
/// An unfinished registration is journaled before sending, so a timeout or
/// process death can be reconciled on the next login to this same account.
class PushBindingService {
  PushBindingService({
    required this.account,
    required this.session,
    required this.service,
    required this.apiEnvironment,
    this.store = const SecurePushBindingStore(),
    this.onChanged,
    this.requestTimeout = const Duration(seconds: 6),
    this.logoutTimeout = const Duration(seconds: 8),
  }) {
    account.beforeLogout.add(unbind);
  }

  final AccountService account;
  final AccountSession session;
  final ChatService service;
  final String apiEnvironment;
  final PushBindingStore store;
  final void Function()? onChanged;
  final Duration requestTimeout, logoutTimeout;
  String? error;
  bool syncing = false;
  bool _disposed = false, _stopping = false, _force = false;
  String? _token, _environment;
  bool _enabled = false;
  int _revision = 0, _attempt = 0;
  Timer? _retry;
  CancelToken? _requestCancel;
  Future<void> _tail = Future.value();
  Future<void>? _pump;
  final Map<String, List<Map<String, dynamic>>> _records = {};

  bool get _valid => !_disposed && identical(account.session, session);
  String _scope(String environment) => jsonEncode([
    apiEnvironment,
    session.product,
    session.platform,
    session.uid,
    environment,
  ]);
  Future<List<Map<String, dynamic>>> _load(String environment) async =>
      _records[environment] ??= await store.read(_scope(environment));
  Future<void> _save(String environment) =>
      store.write(_scope(environment), _records[environment]!);

  Future<void> synchronize({
    required String? token,
    required String? environment,
    required bool enabled,
    bool force = false,
  }) {
    if (!_valid ||
        _stopping ||
        !{'sandbox', 'production'}.contains(environment)) {
      return Future.value();
    }
    final changed =
        token != _token || environment != _environment || enabled != _enabled;
    if (!changed && !force) return _pump ?? Future.value();
    _token = token;
    _environment = environment;
    _enabled = enabled;
    _force |= force;
    _revision++;
    _attempt = 0;
    _retry?.cancel();
    return _startPump();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _startPump() => _pump ??= _enqueue(() async {
    syncing = true;
    onChanged?.call();
    try {
      var processed = -1;
      while (_valid && !_stopping && processed != _revision) {
        processed = _revision;
        final force = _force;
        _force = false;
        try {
          await _reconcile(_environment!, _token, _enabled, force);
          error = null;
          _attempt = 0;
        } catch (e) {
          error = _message(e);
          if (processed != _revision) continue;
          if (_retryable(e) && _attempt < 2 && _valid && !_stopping) {
            _attempt++;
            _retry = Timer(Duration(seconds: _attempt * 2), () {
              if (_valid && !_stopping) {
                _force = true;
                unawaited(_startPump());
              }
            });
          }
          break;
        }
      }
    } finally {
      syncing = false;
      _pump = null;
      if (!_disposed) onChanged?.call();
    }
  });

  Future<Object?> _request(
    String path, {
    String method = 'POST',
    Object? data,
    String? binding,
  }) async {
    if (!_valid) throw const ChatException('登录状态已变化');
    final cancel = _requestCancel = CancelToken();
    try {
      return await service
          .requestData(
            '/notifications/devices$path',
            method: method,
            data: data,
            extraHeaders: {'X-Device-Binding': ?binding},
            cancelToken: cancel,
          )
          .timeout(
            requestTimeout,
            onTimeout: () {
              cancel.cancel('Push request deadline');
              throw TimeoutException('Push request deadline');
            },
          );
    } finally {
      if (identical(_requestCancel, cancel)) _requestCancel = null;
    }
  }

  Map<String, dynamic> _binding(Object? result, String environment) {
    if (result is! Map ||
        result['deviceId'] is! String ||
        (result['deviceId'] as String).isEmpty ||
        result['bindingId'] is! String ||
        (result['bindingId'] as String).isEmpty ||
        result['enabled'] is! bool ||
        result['environment'] != environment) {
      throw const ChatException('设备登记响应无效，请稍后重试');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<void> _register(
    Map<String, dynamic> record,
    String environment,
    bool enabled,
  ) async {
    final result = _binding(
      await _request(
        '',
        data: {
          'deviceToken': record['token'],
          'environment': environment,
          'enabled': enabled,
        },
      ),
      environment,
    );
    if (!_valid) return; // Never write a late response into another login.
    record.addAll(result);
    record['pending'] = false;
    await _save(environment);
  }

  Future<void> _delete(Map<String, dynamic> record, String environment) async {
    record['pending'] = true;
    await _save(environment);
    if (record['deviceId'] == null || record['bindingId'] == null) {
      // Resolve a previously timed-out POST with the current owner's credentials.
      await _register(record, environment, false);
      record['pending'] = true;
      await _save(environment);
    }
    if (!_valid) throw const ChatException('登录状态已变化');
    try {
      await _request(
        '/${Uri.encodeComponent(record['deviceId'] as String)}',
        method: 'DELETE',
        binding: record['bindingId'] as String,
      );
    } on DioException catch (e) {
      // 404 means this binding is gone or no longer belongs to this user.
      // A 409 can be a concurrent update: retain it for a later attempt.
      if (e.response?.statusCode != 404) rethrow;
    }
    if (!_valid) return;
    _records[environment]!.remove(record);
    await _save(environment);
  }

  Future<void> _reconcile(
    String environment,
    String? token,
    bool enabled,
    bool force,
  ) async {
    final records = await _load(environment);
    if (!_valid || _stopping) return;
    Object? cleanupError;
    for (final old in records.toList()) {
      if (old['token'] == token && old['pending'] != true) continue;
      // With no fresh APNs token, keep the current binding for permission sync.
      if (token == null && old['pending'] != true) continue;
      try {
        await _delete(old, environment);
      } catch (e) {
        cleanupError = e;
      }
      if (!_valid || _stopping) return;
    }
    if (token == null || token.isEmpty) {
      if (!enabled) {
        for (final record in records.toList()) {
          if (record['bindingId'] != null) {
            await _preference(record, environment, false);
          }
        }
      }
      if (cleanupError != null) throw cleanupError;
      return;
    }
    var record = records.where((e) => e['token'] == token).firstOrNull;
    if (record == null) {
      record = {'token': token};
      records.add(record);
      await _save(
        environment,
      ); // Journal before a request can reach the server.
    }
    if (!_valid || _stopping) return;
    if (record['bindingId'] == null || record['pending'] == true) {
      await _register(record, environment, enabled);
    } else if (record['enabled'] != enabled) {
      await _preference(record, environment, enabled);
    } else if (force) {
      await _register(record, environment, enabled);
    }
    if (cleanupError != null) throw cleanupError;
  }

  Future<void> _preference(
    Map<String, dynamic> record,
    String environment,
    bool enabled,
  ) async {
    try {
      final result = _binding(
        await _request(
          '/${Uri.encodeComponent(record['deviceId'] as String)}/preference',
          method: 'PUT',
          data: {'enabled': enabled},
          binding: record['bindingId'] as String,
        ),
        environment,
      );
      if (!_valid) return;
      record.addAll(result);
      await _save(environment);
    } on DioException catch (e) {
      if (!{404, 409}.contains(e.response?.statusCode) ||
          _stopping ||
          !_valid) {
        rethrow;
      }
      await _register(record, environment, enabled);
    }
  }

  /// Failures remain in the account/environment ledger. We do not keep old
  /// credentials for background retries after logout or claim offline success.
  Future<void> unbind() async {
    _stopping = true;
    _retry?.cancel();
    try {
      await _enqueue(() async {
        for (final environment in ['sandbox', 'production']) {
          final records = await _load(environment);
          for (final record in records.toList()) {
            await _delete(record, environment);
          }
        }
      }).timeout(logoutTimeout);
      error = null;
    } catch (_) {
      _requestCancel?.cancel('Logout deadline');
      error = '设备通知解绑尚未确认，下次登录此账号时重试。';
      rethrow;
    }
  }

  bool _retryable(Object e) =>
      e is TimeoutException ||
      e is DioException &&
          (e.response == null && e.type != DioExceptionType.cancel ||
              {409, 429, 500, 502, 503, 504}.contains(e.response?.statusCode));
  String _message(Object e) {
    if (e is DioException) {
      return switch (e.response?.statusCode) {
        400 => '设备登记参数被拒绝，请核对推送环境。',
        401 => '登录已过期，通知同步暂停，请重新登录。',
        403 => '当前账号无法更新此设备通知。',
        409 => '设备绑定发生冲突，请稍后重试。',
        _ => '通知设置尚未同步，请稍后重试。',
      };
    }
    return e is ChatException ? e.message : '通知设置尚未同步，请稍后重试。';
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _requestCancel?.cancel('Push binding disposed');
    account.beforeLogout.remove(unbind);
  }
}
