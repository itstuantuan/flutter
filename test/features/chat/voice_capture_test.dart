import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bots/features/chat/voice_capture.dart';

class FakeVoiceRecorder implements VoiceRecorder {
  bool permitted = true;
  int permissionCalls = 0, starts = 0, stops = 0, cancels = 0, disposals = 0;
  Completer<bool>? permission;
  Completer<void>? starting;
  Object? stopError;
  Completer<String?>? stopping;
  final deleted = <String>[];
  final volume = StreamController<double>.broadcast();
  final interrupted = StreamController<void>.broadcast();
  @override
  Future<bool> hasPermission() async {
    permissionCalls++;
    return permission?.future ?? permitted;
  }

  @override
  Future<void> start() async {
    starts++;
    await starting?.future;
  }

  @override
  Future<String?> stop() async {
    stops++;
    if (stopError != null) throw stopError!;
    return stopping?.future ?? '/tmp/test-recording.m4a';
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await volume.close();
    await interrupted.close();
  }

  @override
  Stream<double> get levels => volume.stream;
  @override
  Stream<void> get interruptions => interrupted.stream;
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('permission denied never starts recording', () async {
    final backend = FakeVoiceRecorder()..permitted = false;
    final capture = VoiceCapture(backend: backend);
    await capture.start();
    expect(backend.starts, 0);
    expect(capture.recording, isFalse);
    expect(capture.error, contains('麦克风权限'));
    capture.dispose();
    await flush();
  });

  test(
    'repeated start and cancellation during permission cannot open microphone',
    () async {
      final backend = FakeVoiceRecorder()..permission = Completer<bool>();
      final capture = VoiceCapture(backend: backend);
      final first = capture.start();
      await capture.start();
      final cancel = capture.cancel();
      backend.permission!.complete(true);
      await first;
      await cancel;
      expect(backend.permissionCalls, 1);
      expect(backend.starts, 0);
      capture.dispose();
      await flush();
    },
  );

  test(
    'dispose during platform startup closes late microphone activation',
    () async {
      final backend = FakeVoiceRecorder()..starting = Completer<void>();
      final capture = VoiceCapture(backend: backend);
      final start = capture.start();
      await flush();
      capture.dispose();
      backend.starting!.complete();
      await start;
      await flush();
      expect(backend.cancels, 1);
      expect(backend.disposals, 1);
    },
  );

  test(
    'real levels, duration and pending take are retained until accepted',
    () async {
      final backend = FakeVoiceRecorder();
      final capture = VoiceCapture(
        backend: backend,
        elapsed: () => const Duration(seconds: 3),
      );
      await capture.start();
      backend.volume.add(.72);
      await flush();
      expect(capture.level, .72);
      final clip = await capture.finish();
      expect(clip?.duration, const Duration(seconds: 3));
      expect(clip?.path, '/tmp/test-recording.m4a');
      expect(await capture.finish(), same(clip));
      expect(backend.stops, 1);
      capture.accept();
      capture.dispose();
      await flush();
      expect(backend.deleted, isEmpty);
      expect(
        backend.cancels,
        0,
        reason: 'closing must not remove an accepted file',
      );
    },
  );

  test(
    'short takes are removed and cancelling a pending take removes its file',
    () async {
      final backend = FakeVoiceRecorder();
      var duration = const Duration(milliseconds: 100);
      final capture = VoiceCapture(backend: backend, elapsed: () => duration);
      await capture.start();
      expect(await capture.finish(), isNull);
      expect(backend.deleted, hasLength(1));
      duration = const Duration(seconds: 2);
      await capture.start();
      await capture.finish();
      await capture.cancel();
      expect(backend.deleted, hasLength(2));
      expect(capture.pending, isNull);
      capture.dispose();
      await flush();
    },
  );

  test(
    'interruption cancels microphone instead of silently resuming',
    () async {
      final backend = FakeVoiceRecorder();
      final capture = VoiceCapture(backend: backend);
      await capture.start();
      backend.interrupted.add(null);
      await flush();
      await flush();
      expect(backend.cancels, 1);
      expect(capture.recording, isFalse);
      expect(capture.error, contains('中断'));
      capture.dispose();
      await flush();
    },
  );

  test(
    'cancellation waits for finishing and deletes the uncommitted file',
    () async {
      final backend = FakeVoiceRecorder()..stopping = Completer<String?>();
      final capture = VoiceCapture(
        backend: backend,
        elapsed: () => const Duration(seconds: 2),
      );
      await capture.start();
      final finish = capture.finish();
      await flush();
      final cancel = capture.cancel();
      backend.stopping!.complete('/tmp/finishing.m4a');
      await finish;
      await cancel;
      expect(capture.pending, isNull);
      expect(backend.deleted, contains('/tmp/finishing.m4a'));
      expect(capture.busy, isFalse);
      capture.dispose();
      await flush();
    },
  );

  test('stop failure releases device and exposes a retryable error', () async {
    final backend = FakeVoiceRecorder()..stopError = StateError('no space');
    final capture = VoiceCapture(
      backend: backend,
      elapsed: () => const Duration(seconds: 1),
    );
    await capture.start();
    expect(await capture.finish(), isNull);
    expect(backend.cancels, 1);
    expect(capture.busy, isFalse);
    expect(capture.error, contains('保存失败'));
    capture.dispose();
    await flush();
  });
}
