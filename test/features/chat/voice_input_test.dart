import 'dart:typed_data';

import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/chat/chat_controller.dart';
import 'package:bots/features/chat/chat_message.dart';
import 'package:bots/features/chat/chat_service.dart';
import 'package:bots/features/chat/voice_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../exploration/fakes.dart';

class VoiceService extends FakeBotService {
  int uploads = 0, polls = 0, retries = 0;
  String status = 'ready';
  bool failSend = false;
  final sends = <Map<String, dynamic>>[];
  Map<String, dynamic> get attachment => {
    'attachmentId': 'audio-1',
    'status': status,
    'text': '你好',
    'errorCode': 'ASR_NO_SPEECH',
  };
  @override
  Future<Map<String, dynamic>> uploadVoice(
    Uint8List bytes, {
    required bool wav,
    CancelToken? cancelToken,
  }) async {
    uploads++;
    return {...attachment, 'status': 'queued'};
  }

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    if (path == '/attachments/audio-1/retry') {
      retries++;
      status = 'ready';
      return attachment;
    }
    if (path == '/attachments/audio-1') {
      polls++;
      return attachment;
    }
    if (method == 'POST' && path.endsWith('/messages')) {
      sends.add(Map<String, dynamic>.from(data as Map));
      if (failSend) throw const ChatException('timeout');
      return {
        'id': 1,
        'messageType': 'chat',
        'userText': '',
        'attachmentIds': data['attachmentIds'],
        'status': 'queued',
      };
    }
    return super.request(
      path,
      method: method,
      data: data,
      query: query,
      cancelToken: cancelToken,
    );
  }
}

void main() {
  const clip = VoiceClip(path: '/test.m4a', duration: Duration(seconds: 2));
  VoiceInput input(VoiceService service) => VoiceInput(
    service,
    pollInterval: Duration.zero,
    maxPolls: 2,
    readBytes: (_) async => Uint8List.fromList([1, 2, 3]),
  );

  test('ready attachment sends once with references; retry reuses attachment and message ID', () async {
    final service = VoiceService()..failSend = true;
    final chat = ChatController(service, displayName: '测试');
    await chat.initializeSession();
    chat.referenceTaskId = 'discovery-1';
    chat.referenceMaterialId = 'material-1';
    final voice = input(service);
    Future<bool> send(String id) => chat.send('', attachmentIds: [id]);
    expect(await voice.send(clip, sendAttachment: send), isFalse);
    service.failSend = false;
    expect(await voice.send(clip, sendAttachment: send), isTrue);
    expect(service.uploads, 1);
    expect(service.sends[0], service.sends[1]);
    expect(service.sends.last['attachmentIds'], ['audio-1']);
    expect(service.sends.last['referenceTaskId'], 'discovery-1');
    expect(service.sends.last['referenceMaterialId'], 'material-1');
    expect(
      chat.messages.where((message) => message.isUser).single.text,
      '语音消息',
    );
    expect(chat.messages.last.isThinking, isTrue);
    voice.dispose();
    chat.dispose();
    await service.events.close();
  });

  test(
    'failed ASR never sends and only retries on explicit next attempt',
    () async {
      final service = VoiceService()..status = 'failed';
      final voice = input(service);
      var sends = 0;
      Future<bool> send(String id) async {
        sends++;
        return true;
      }

      await expectLater(
        voice.send(clip, sendAttachment: send),
        throwsA(isA<ChatException>()),
      );
      expect(sends, 0);
      expect(service.retries, 0);
      expect(await voice.send(clip, sendAttachment: send), isTrue);
      expect(service.uploads, 1);
      expect(service.retries, 1);
      expect(sends, 1);
      voice.dispose();
      await service.events.close();
    },
  );

  test(
    'processing has bounded polling and disposed input cannot send',
    () async {
      final service = VoiceService()..status = 'processing';
      final voice = input(service);
      var sends = 0;
      Future<bool> send(String id) async {
        sends++;
        return true;
      }

      await expectLater(
        voice.send(clip, sendAttachment: send),
        throwsA(isA<ChatException>()),
      );
      expect(service.polls, 2);
      expect(sends, 0);
      voice.dispose();
      expect(await voice.send(clip, sendAttachment: send), isFalse);
      await service.events.close();
    },
  );
}
