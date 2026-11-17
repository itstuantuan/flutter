import 'dart:async';
import 'dart:typed_data';

import '../../core/network/api_client.dart';
import 'chat_message.dart';
import 'chat_service.dart';
import 'voice_storage.dart';

/// Keeps a received attachment ID across explicit retries of the same take.
/// Uploading never sends a chat message; only ready attachments may be sent.
class VoiceInput {
  VoiceInput(
    this.service, {
    this.pollInterval = const Duration(seconds: 1),
    this.maxPolls = 120,
    Future<Uint8List> Function(String)? readBytes,
  }) : _readBytes = readBytes ?? readVoiceBytes;

  final ChatService service;
  final Duration pollInterval;
  final int maxPolls;
  final Future<Uint8List> Function(String) _readBytes;
  final _cancel = CancelToken();
  String? _path, _attachmentId;
  bool _busy = false;

  Future<bool> send(
    VoiceClip clip, {
    required Future<bool> Function(String) sendAttachment,
  }) async {
    if (_busy || _cancel.isCancelled) return false;
    _busy = true;
    try {
      if (clip.duration > const Duration(seconds: 120)) {
        throw const ChatException('录音不能超过120秒，请重新录制');
      }
      if (_path != clip.path) {
        _path = clip.path;
        _attachmentId = null;
      }
      Map<String, dynamic> attachment;
      if (_attachmentId == null) {
        final bytes = await _readBytes(clip.path);
        if (_cancel.isCancelled) throw _cancel.cancelError!;
        attachment = await service.uploadVoice(
          bytes,
          wav: clip.ephemeral,
          cancelToken: _cancel,
        );
        final id = attachment['attachmentId'];
        if (id is! String || id.isEmpty) {
          throw const ChatException('上传响应缺少附件信息，请重试');
        }
        _attachmentId = id;
      } else {
        attachment = await service.request(
          '/attachments/${Uri.encodeComponent(_attachmentId!)}',
          cancelToken: _cancel,
        );
        // Retry processing only on a new, explicit user attempt.
        if (attachment['status'] == 'failed') {
          attachment = await service.request(
            '/attachments/${Uri.encodeComponent(_attachmentId!)}/retry',
            method: 'POST',
            cancelToken: _cancel,
          );
        }
      }
      for (var attempt = 0; attempt <= maxPolls; attempt++) {
        if (_cancel.isCancelled) throw _cancel.cancelError!;
        switch (attachment['status']) {
          case 'ready':
            if ((attachment['text'] as String? ?? '').trim().isEmpty) {
              throw const ChatException('没有识别到语音，请取消后重新录制');
            }
            return await sendAttachment(_attachmentId!);
          case 'failed':
            throw ChatException(_failureMessage(attachment['errorCode']));
          case 'queued':
          case 'processing':
            break;
          default:
            throw const ChatException('语音处理状态异常，请重试');
        }
        if (attempt == maxPolls) break;
        await Future.any([
          Future<void>.delayed(pollInterval),
          _cancel.whenCancel,
        ]);
        if (_cancel.isCancelled) throw _cancel.cancelError!;
        attachment = await service.request(
          '/attachments/${Uri.encodeComponent(_attachmentId!)}',
          cancelToken: _cancel,
        );
      }
      throw const ChatException('语音识别仍在处理中，录音已保留，请稍后重试');
    } finally {
      _busy = false;
    }
  }

  String _failureMessage(Object? code) => switch (code) {
    'ASR_NO_SPEECH' || 'MEDIA_EMPTY_RESULT' => '没有识别到语音，请取消后重新录制',
    'AUDIO_DURATION_EXCEEDED' => '录音超过120秒，请取消后重新录制',
    'AUDIO_INVALID' => '录音格式无效，请取消后重新录制',
    'ASR_TIMEOUT' => '语音识别超时，录音已保留，请重试',
    _ => '语音识别失败，录音已保留，请重试或取消',
  };

  void dispose() => _cancel.cancel();
}
