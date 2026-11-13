import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'chat_message.dart';
import 'voice_storage.dart';

abstract interface class VoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start();
  Future<String?> stop();
  Future<void> cancel();
  Future<void> delete(String path);
  Future<void> dispose();
  Stream<double> get levels;
  Stream<void> get interruptions;
}

class DeviceVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();
  @override
  Future<void> start() async => _recorder.start(
    RecordConfig(
      encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
      sampleRate: 24000,
      bitRate: 64000,
      numChannels: 1,
    ),
    path: await newVoicePath(),
  );
  @override
  Future<String?> stop() async {
    final path = await _recorder.stop();
    if (path == null || !await voiceFileExists(path)) {
      if (path != null) await deleteVoiceFile(path);
      return null;
    }
    return path;
  }

  @override
  Future<void> cancel() => _recorder.cancel();
  @override
  Future<void> delete(String path) => deleteVoiceFile(path);
  @override
  Future<void> dispose() => _recorder.dispose();
  @override
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((level) => ((level.current + 60) / 60).clamp(0.0, 1.0));
  @override
  Stream<void> get interruptions => _recorder
      .onStateChanged()
      .where((state) => state != RecordState.record)
      .map((_) {});
}

/// Lazily opens the microphone only after an explicit tap. A pending take is
/// retained if persistence fails; cancellation and page disposal delete drafts.
class VoiceCapture extends ChangeNotifier {
  VoiceCapture({VoiceRecorder? backend, Duration Function()? elapsed})
    : _recorder = backend,
      _elapsedOverride = elapsed;
  VoiceRecorder? _recorder;
  final Duration Function()? _elapsedOverride;
  final _watch = Stopwatch();
  Timer? _timer;
  StreamSubscription<double>? _levels;
  StreamSubscription<void>? _interruptions;
  bool _disposed = false;
  bool _deviceActive = false;
  int _generation = 0;
  Future<void>? _starting;
  Future<VoiceClip?>? _finishing;
  bool busy = false, recording = false;
  double level = 0;
  Duration elapsed = Duration.zero;
  VoiceClip? pending;
  String? error;

  Duration get _duration => _elapsedOverride?.call() ?? _watch.elapsed;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() {
    if (busy || recording || pending != null || _disposed) {
      return Future.value();
    }
    final future = _start();
    _starting = future;
    return future;
  }

  Future<void> _start() async {
    final generation = ++_generation;
    busy = true;
    error = null;
    _notify();
    try {
      final recorder = _recorder ??= DeviceVoiceRecorder();
      if (!await recorder.hasPermission()) {
        error = '未获得麦克风权限，请在系统设置中允许，或继续文字聊天。';
        return;
      }
      if (_disposed || generation != _generation) return;
      await recorder.start();
      _deviceActive = true;
      if (_disposed || generation != _generation) {
        await recorder.cancel();
        _deviceActive = false;
        return;
      }
      recording = true;
      elapsed = Duration.zero;
      _watch
        ..reset()
        ..start();
      _levels = recorder.levels.listen(
        (value) {
          level = value;
          _notify();
        },
        onError: (_) {
          level = 0;
          _notify();
        },
      );
      _interruptions = recorder.interruptions.listen((_) {
        if (recording && !busy) {
          unawaited(
            cancel().then((_) {
              error = '录音已中断，请重新录制。';
              _notify();
            }),
          );
        }
      });
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        elapsed = _duration;
        _notify();
        if (elapsed >= const Duration(minutes: 2)) unawaited(finish());
      });
    } catch (_) {
      error = '无法开始录音，请检查麦克风是否可用后重试。';
      try {
        await _recorder?.cancel();
      } catch (_) {
        /* Best-effort device release. */
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _stopMonitoring() async {
    _timer?.cancel();
    _watch.stop();
    await _levels?.cancel();
    await _interruptions?.cancel();
    _levels = null;
    _interruptions = null;
    level = 0;
  }

  Future<VoiceClip?> finish() {
    if (busy || _disposed) return Future.value(null);
    final future = _finish();
    _finishing = future;
    return future;
  }

  Future<VoiceClip?> _finish() async {
    if (busy || _disposed) return null;
    if (pending != null) return pending;
    if (!recording) return null;
    busy = true;
    elapsed = _duration;
    recording = false;
    _notify();
    try {
      await _stopMonitoring();
      final path = await _recorder!.stop();
      _deviceActive = false;
      if (_disposed) {
        if (path != null) await _recorder!.delete(path);
        return null;
      }
      if (path == null || elapsed < const Duration(milliseconds: 500)) {
        if (path != null) await _recorder!.delete(path);
        error = '录音太短或没有有效音频，请重新录制。';
        return null;
      }
      pending = VoiceClip(path: path, duration: elapsed, ephemeral: kIsWeb);
      return pending;
    } catch (_) {
      error = '录音保存失败，请重试。';
      try {
        await _recorder?.cancel();
      } catch (_) {
        /* Best-effort device release. */
      }
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Transfer ownership to the saved conversation after persistence succeeds.
  void accept() {
    pending = null;
    error = null;
    _notify();
  }

  Future<void> cancel() async {
    ++_generation;
    // An in-flight permission/start operation checks the generation before
    // opening the mic, or immediately cancels after the platform start returns.
    if (busy) {
      await _starting;
      await _finishing;
      if (busy) return;
    }
    busy = true;
    recording = false;
    _notify();
    try {
      await _stopMonitoring();
      if (_deviceActive) {
        await _recorder?.cancel();
        _deviceActive = false;
      }
      final clip = pending;
      if (clip != null) await _recorder?.delete(clip.path);
      pending = null;
      elapsed = Duration.zero;
    } catch (_) {
      error = '无法取消录音，请重试。';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_close());
    super.dispose();
  }

  Future<void> _close() async {
    await _starting;
    await _finishing;
    await _stopMonitoring();
    try {
      if (_deviceActive) await _recorder?.cancel();
      if (pending != null) await _recorder?.delete(pending!.path);
    } catch (_) {
      /* Dispose must still release the platform recorder. */
    }
    try {
      await _recorder?.dispose();
    } catch (_) {
      /* Device already closed. */
    }
  }
}
