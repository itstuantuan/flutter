import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 类似 useRequest：页面持有实例，通过 ListenableBuilder 监听状态。
/// run 捕获错误并存入 error；重新运行时取消旧请求，只采用最后一次结果。
class RequestController<T> extends ChangeNotifier {
  T? _data;
  Object? _error;
  bool _loading = false;
  bool _disposed = false;
  CancelToken? _token;

  T? get data => _data;
  Object? get error => _error;
  bool get loading => _loading;

  Future<void> run(Future<T> Function(CancelToken token) task) async {
    if (_disposed) return;
    _token?.cancel('请求已被替换');
    final token = CancelToken();
    _token = token;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await task(token);
      if (!_disposed && identical(_token, token)) _data = result;
    } catch (error) {
      if (!_disposed && identical(_token, token) && !token.isCancelled) {
        _error = error;
      }
    } finally {
      if (!_disposed && identical(_token, token)) {
        _loading = false;
        _token = null;
        notifyListeners();
      }
    }
  }

  /// 取消时保留已有数据，不作为请求失败处理。
  void cancel() {
    if (_disposed) return;
    _token?.cancel('请求已取消');
    _token = null;
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel('页面已销毁');
    _token = null;
    super.dispose();
  }
}
