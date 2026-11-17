import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// One recognizer per app: the platform plugin keeps its initialization callbacks.
class SystemDictation extends ChangeNotifier {
  SystemDictation({SpeechToText? recognizer})
    : _speech = recognizer ?? SpeechToText();
  static final shared = SystemDictation();
  final SpeechToText _speech;
  String text = '';
  String? error;
  bool active = false, busy = false;
  int _generation = 0;
  Completer<void>? _final;
  final _listeningTime = Stopwatch();
  bool _systemEndedEarly = false;
  Duration get elapsed => _listeningTime.elapsed;
  double level = 0;
  Timer? _meterTimer;

  Future<void> start() async {
    if (active || busy) return;
    final generation = ++_generation;
    text = '';
    error = null;
    _systemEndedEarly = false;
    _listeningTime.reset();
    level = 0;
    busy = true;
    notifyListeners();
    try {
      final available = await _speech.initialize(
        finalTimeout: const Duration(milliseconds: 800),
        onError: (failure) {
          if (kDebugMode) debugPrint('[Dictation] error=${failure.errorMsg}');
          if (!active) return;
          error = '语音识别已中断，已识别文字会保留，也可以直接打字。';
          unawaited(stop());
        },
        onStatus: (status) {
          if (status == 'done' && active) {
            _systemEndedEarly =
                text.trim().isEmpty &&
                _listeningTime.elapsed < const Duration(seconds: 2);
            unawaited(stop());
          }
        },
      );
      if (generation != _generation) return;
      if (!available) {
        error = '系统语音识别不可用，请检查麦克风和语音识别权限，或直接打字。';
        return;
      }
      final locales = await _speech.locales();
      if (generation != _generation) return;
      final chinese = locales.where(
        (l) => l.localeId.replaceAll('_', '-').toLowerCase() == 'zh-cn',
      );
      if (chinese.isEmpty) {
        error = '当前设备不支持中文语音识别，请使用文字输入。';
        return;
      }
      active = true;
      _listeningTime.start();
      _meterTimer?.cancel();
      _meterTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (active) notifyListeners();
      });
      _final = Completer<void>();
      await _speech.listen(
        onSoundLevelChange: (value) {
          if (generation != _generation || !active) return;
          level = ((value + 60) / 60).clamp(0.0, 1.0);
          notifyListeners();
        },
        onResult: (result) {
          if (generation != _generation || !active) return;
          text = result.recognizedWords;
          if (result.finalResult) {
            if (!_final!.isCompleted) _final!.complete();
            unawaited(stop());
          }
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          localeId: chinese.first.localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
        ),
      );
      if (generation != _generation) await _speech.cancel();
    } catch (_) {
      if (generation == _generation) {
        active = false;
        _meterTimer?.cancel();
        _listeningTime.stop();
        error = '无法开启语音识别，请检查系统权限和网络，或直接打字。';
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void>? _stopping;
  Future<void> stop() =>
      _stopping ??= _stop().whenComplete(() => _stopping = null);
  Future<void> _stop() async {
    if (!active) return;
    final generation = _generation;
    busy = true;
    notifyListeners();
    try {
      await _speech.stop();
      await _final?.future.timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () {},
      );
    } catch (_) {
      error ??= '已保留识别文字，请检查后发送。';
    } finally {
      if (generation == _generation) {
        ++_generation; // Late recognition callbacks must not overwrite edits.
        active = false;
        busy = false;
        _listeningTime.stop();
        _meterTimer?.cancel();
        level = 0;
        if (text.trim().isEmpty) {
          error ??= _systemEndedEarly
              ? '系统语音识别启动后立即结束，请检查设备的语音服务，或直接打字。'
              : '没有识别到语音，请重试或直接打字。';
        }
        notifyListeners();
      }
    }
  }

  Future<void> cancel() async {
    ++_generation;
    _meterTimer?.cancel();
    _listeningTime.stop();
    level = 0;
    active = false;
    busy = false;
    if (_final != null && !_final!.isCompleted) _final!.complete();
    try {
      await _speech.cancel();
    } catch (_) {}
    notifyListeners();
  }
}
