import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bots/core/network/api_client.dart';
import 'package:bots/features/chat/chat_controller.dart';
import 'package:bots/features/chat/chat_service.dart';
import 'package:bots/features/chat/chat_transcript.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object data) => ResponseBody.fromString(
  jsonEncode({'code': 0, 'data': data}),
  200,
  headers: {
    'content-type': ['application/json'],
  },
);

Map<String, dynamic> turn(int id, String text, {int updated = 1}) => {
  'id': id,
  'assistantText': text,
  'userText': '你好',
  'status': 'completed',
  'updateTime': updated,
  'messageType': 'chat',
};

void main() {
  test('voice uploads multipart with auth and supported MIME type', () async {
    final dio = Dio()
      ..httpClientAdapter = Adapter((options) async {
        expect(options.path, '/api/v1/chat/attachments');
        expect(options.headers['Authorization'], 'Bearer test');
        expect(options.contentType, contains('multipart/form-data'));
        final form = options.data as FormData;
        expect(form.files.single.key, 'file');
        expect(form.files.single.value.filename, 'voice.m4a');
        expect(form.files.single.value.contentType.toString(), 'audio/mp4');
        return jsonResponse({'attachmentId': 'audio-1', 'status': 'queued'});
      });
    final service = ChatService(
      client: ApiClient(baseUrl: 'https://test', dio: dio),
      headers: () async => {'Authorization': 'Bearer test'},
    );
    expect(
      (await service.uploadVoice(
        Uint8List.fromList([1, 2, 3]),
        wav: false,
      ))['attachmentId'],
      'audio-1',
    );
    await expectLater(
      () => service.uploadVoice(Uint8List(0), wav: false),
      throwsA(isA<ChatException>()),
    );
  });

  test(
    'SSE handles UTF-8 byte splits, CRLF, comments and multiline data',
    () async {
      final bytes = utf8.encode(
        ': heartbeat\r\nevent: snapshot\r\ndata: {"text":\r\ndata: "你好🌏"}\r\n\r\nevent: stream_error\ndata: {}\n\n',
      );
      final events = await decodeSse(
        Stream.fromIterable(bytes.map((b) => Uint8List.fromList([b]))),
      ).toList();
      expect(events.map((e) => e.type), ['snapshot', 'stream_error']);
      expect(jsonDecode(events.first.data), {'text': '你好🌏'});
    },
  );

  test('SSE drops unfinished frame on disconnect', () async {
    expect(
      await decodeSse(Stream.value(utf8.encode('data: incomplete'))).toList(),
      isEmpty,
    );
  });

  test('older conversation pages merge historical discovery results', () async {
    final stream = StreamController<Uint8List>();
    final streamOpened = Completer<void>();
    final dio = Dio()
      ..httpClientAdapter = Adapter((options) async {
        if (options.path.endsWith('/me')) {
          return jsonResponse({'initialized': true, 'sessionId': 's1'});
        }
        if (options.path.endsWith('/home')) return jsonResponse({});
        if (options.path.endsWith('/stream')) {
          streamOpened.complete();
          return ResponseBody(
            stream.stream,
            200,
            headers: {'content-type': ['text/event-stream']},
          );
        }
        final before = options.queryParameters['before'];
        if (before == null) {
          return jsonResponse({'turns': [turn(51, '最新回复')], 'hasMore': true});
        }
        expect(before, 51);
        return jsonResponse({
          'turns': [
            {
              ...turn(2, '较早的探索推送'),
              'messageType': 'discovery',
              'referenceTaskId': 'old-task',
              'exploration': {
                'cards': [
                  for (var i = 1; i <= 3; i++)
                    {'materialId': 'old-material-$i', 'summary': '历史发现$i'},
                ],
              },
            },
          ],
          'hasMore': false,
        });
      });
    final controller = ChatController(
      ChatService(
        client: ApiClient(baseUrl: 'https://test', dio: dio),
        headers: () async => {},
      ),
      displayName: '测试',
    );
    final running = controller.start();
    await streamOpened.future;
    expect(controller.hasOlderMessages, isTrue);
    await controller.loadOlderMessages();
    expect(controller.hasOlderMessages, isFalse);
    expect(controller.messages.first.cards.first['summary'], '历史发现1');
    expect(controller.messages.last.text, '最新回复');
    controller.pause();
    await stream.close();
    await running;
    controller.dispose();
  });

  test('split discovery waits for all cards and returns to its old place', () async {
    final progress = Completer<ResponseBody>();
    final dio = Dio()
      ..httpClientAdapter = Adapter((options) {
        expect(options.path, '/api/v1/chat/explorations/old-task/progress');
        return progress.future;
      });
    final controller = ChatController(
      ChatService(
        client: ApiClient(baseUrl: 'https://test', dio: dio),
        headers: () async => {},
      ),
      displayName: '测试',
    );
    addTearDown(controller.dispose);
    Map<String, dynamic> cardTurn(int card) => {
      'id': 20 + card,
      'createTime': 2000 + card,
      'messageType': 'discovery',
      'referenceTaskId': 'old-task',
      'status': 'completed',
      'exploration': {
        'cards': [
          {'materialId': 'material-$card', 'summary': '历史发现$card'},
        ],
      },
    };
    controller.merge({
      'turns': [
        {...turn(1, '探索前'), 'createTime': 1000},
        {...turn(2, '探索后'), 'createTime': 3000},
        cardTurn(1),
      ],
    });
    expect(controller.messages.expand((message) => message.cards), isEmpty);
    controller.merge({'turns': [cardTurn(2)]}, live: true);
    expect(controller.messages.expand((message) => message.cards), isEmpty);

    controller.merge({'turns': [cardTurn(3)]}, live: true);
    final entries = chatTranscriptEntries(controller.messages);
    expect(entries.map((entry) => entry.message.text), [
      '你好',
      '探索前',
      '',
      '你好',
      '探索后',
    ]);
    expect(entries[2].cards.map((card) => card['materialId']), [
      'material-1',
      'material-2',
      'material-3',
    ]);
    progress.complete(jsonResponse({'phase': 'searching'}));
  });

  test('smaller discovery waits for the final server result', () async {
    final progress = Completer<ResponseBody>();
    final dio = Dio()
      ..httpClientAdapter = Adapter((_) => progress.future);
    final controller = ChatController(
      ChatService(
        client: ApiClient(baseUrl: 'https://test', dio: dio),
        headers: () async => {},
      ),
      displayName: '测试',
    );
    addTearDown(controller.dispose);
    final cards = [
      {'materialId': 'only-card', 'summary': '这次只有一个结果'},
    ];
    controller.merge({
      'turns': [
        {...turn(1, '探索前'), 'createTime': 1000},
        {...turn(2, '探索后'), 'createTime': 3000},
        {
          ...turn(42, '旧探索'),
          'messageType': 'discovery',
          'referenceTaskId': 'old-task',
          'createTime': 4000,
          'exploration': {'cards': cards},
        },
      ],
    });
    expect(controller.messages.expand((message) => message.cards), isEmpty);
    final done = Completer<void>();
    controller.addListener(() {
      if (controller.messages.any((message) => message.cards.isNotEmpty)) {
        done.complete();
      }
    });
    progress.complete(jsonResponse({
      'phase': 'complete',
      'fullAvailableAt': 2000,
      'cards': cards,
    }));
    await done.future;
    expect(controller.messages.where((message) => !message.isUser).map((m) => m.text), [
      '探索前',
      '旧探索',
      '探索后',
    ]);
  });

  test(
    'snapshots replace by id, retain older history, ignore stale receipts',
    () {
      final controller = ChatController(
        ChatService(
          client: ApiClient(baseUrl: 'https://test'),
          headers: () async => {},
        ),
        displayName: '测试',
      );
      controller.merge({
        'turns': [turn(1, '旧历史'), turn(2, '你')],
      });
      controller.merge({
        'turns': [turn(2, '你好', updated: 3)],
      });
      controller.merge({
        'turns': [turn(2, '过期回执', updated: 2)],
      });
      expect(controller.messages.where((m) => !m.isUser).map((m) => m.text), [
        '旧历史',
        '你好',
      ]);
      controller.dispose();
    },
  );

  test(
    'REST and stream carry all auth headers; retry keeps message id',
    () async {
      final requests = <RequestOptions>[];
      final stream = StreamController<Uint8List>();
      var sends = 0;
      final dio = Dio()
        ..httpClientAdapter = Adapter((options) async {
          requests.add(options);
          if (options.path.endsWith('/me')) {
            return jsonResponse({'initialized': true, 'sessionId': 's1'});
          }
          if (options.path.endsWith('/home')) return jsonResponse({});
          if (options.path.endsWith('/stream')) {
            return ResponseBody(
              stream.stream,
              200,
              headers: {
                'content-type': ['text/event-stream'],
              },
            );
          }
          if (options.method == 'POST') {
            if (++sends == 1) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
              );
            }
            return jsonResponse(turn(3, '收到'));
          }
          return jsonResponse({'turns': [], 'hasMore': false});
        });
      final auth = {
        'Authorization': 'Bearer test-token',
        'X-User-Id': '123',
        'X-Device-ID': 'device',
        'X-Channel': '300',
      };
      final controller = ChatController(
        ChatService(
          client: ApiClient(baseUrl: 'https://test', dio: dio),
          headers: () async => auth,
        ),
        displayName: '测试',
      );
      final running = controller.start();
      while (controller.loading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(await controller.send('你好'), isFalse);
      expect(await controller.send('你好'), isTrue);
      final posts = requests.where((r) => r.method == 'POST').toList();
      expect(
        (posts[0].data as Map)['clientMessageId'],
        (posts[1].data as Map)['clientMessageId'],
      );
      for (final request in requests) {
        for (final entry in auth.entries) {
          expect(request.headers[entry.key], entry.value);
        }
      }
      expect(requests.any((r) => r.path.endsWith('/stream')), isTrue);
      controller.pause();
      await stream.close();
      await running;
      controller.dispose();
    },
  );

  test('401 stops reconnecting and requests login', () async {
    var calls = 0, unauthorized = 0;
    final dio = Dio()
      ..httpClientAdapter = Adapter((options) async {
        calls++;
        return ResponseBody.fromString(
          '{}',
          401,
          headers: {
            'content-type': ['application/json'],
          },
        );
      });
    final controller = ChatController(
      ChatService(
        client: ApiClient(baseUrl: 'https://test', dio: dio),
        headers: () async => {},
      ),
      displayName: '',
      onUnauthorized: () async {
        unauthorized++;
      },
    );
    await controller.start();
    await controller.start();
    expect(calls, 1);
    expect(unauthorized, 1);
    expect(controller.error, contains('重新登录'));
    controller.dispose();
  });
}
