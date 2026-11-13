import 'dart:async';

import 'package:bots/features/chat/chat_message.dart';
import 'package:bots/features/chat/chat_artwork.dart';
import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/chat/chat_preview_page.dart';
import 'package:bots/features/chat/voice_capture.dart';
import 'package:bots/features/chat/voice_playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_capture_test.dart' show FakeVoiceRecorder;

class FakePlayback implements VoicePlayback {
  VoiceClip? played;
  int stops = 0;
  @override
  Future<void> play(VoiceClip clip) async {
    played = clip;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
  @override
  Stream<void> get completed => const Stream.empty();
}

void main() {
  testWidgets('keyboard stays after send and dismisses on outside tap', (
    tester,
  ) async {
    final sending = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          onExit: () {},
          onExplore: () {},
          onSend: (_) => sending.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.enterText(field, '你好');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    sending.complete(true);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(field, '继续');
    await tester.pump();
    await tester.tap(find.byTooltip('清空输入'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    await tester.tapAt(const Offset(200, 120));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'conversation scrolls behind the floating banner down to the composer',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const reply = '谢谢你分享！我记住了，我们可以围绕这些兴趣一起探索。\n这是一条需要完整显示的多行回复。\n最后一行也要显示。';
      for (final size in [const Size(414, 736), const Size(430, 932)]) {
        tester.view.physicalSize = size;
        for (final keyboard in [0.0, 280.0]) {
          double? previousBottom;
          for (final count in [2, 4, 8]) {
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    padding: const EdgeInsets.only(top: 20),
                    viewInsets: EdgeInsets.only(bottom: keyboard),
                  ),
                  child: ChatPage(
                    key: ValueKey('$size-$keyboard-$count'),
                    messages: [
                      for (var i = 0; i < count - 1; i++)
                        ChatMessage('历史消息 $i', isUser: i.isEven),
                      const ChatMessage(reply),
                    ],
                    onExit: () {},
                    onExplore: () {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final viewport = tester.getRect(
              find.byKey(const ValueKey('chat-transcript')),
            );
            final latest = tester.getRect(find.byType(ChatBubble).last);
            final text = tester.getRect(find.text(reply));
            final banner = tester.getRect(find.byType(ChatExploreBanner));
            final composer = tester.getRect(find.byTooltip('开始录音'));
            expect(viewport.bottom, closeTo(composer.top - 8, 1));
            expect(viewport.bottom, greaterThan(banner.bottom));
            expect(latest.bottom, closeTo(viewport.bottom, .01));
            expect(text.bottom, lessThanOrEqualTo(latest.bottom));
            expect(text.bottom, lessThanOrEqualTo(viewport.bottom));
            if (previousBottom != null) {
              expect(viewport.bottom, closeTo(previousBottom, .01));
            }
            previousBottom = viewport.bottom;
            final scrolling = tester.state<ScrollableState>(
              find.descendant(
                of: find.byKey(const ValueKey('chat-transcript')),
                matching: find.byType(Scrollable),
              ),
            );
            if (scrolling.position.maxScrollExtent > 50) {
              await tester.dragFrom(
                Offset(size.width - 30, banner.center.dy),
                const Offset(0, 50),
              );
              await tester.pumpAndSettle();
              expect(scrolling.position.pixels, greaterThan(0));
              expect(tester.getRect(find.byType(ChatExploreBanner)), banner);
            }
            scrolling.position.jumpTo(scrolling.position.maxScrollExtent);
            await tester.pump();
            expect(tester.getRect(find.byType(ChatExploreBanner)), banner);
            scrolling.position.jumpTo(0);
            await tester.pump();
            expect(
              tester.getRect(find.text(reply)).bottom,
              lessThanOrEqualTo(viewport.bottom),
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          }
        }
      }
    },
  );

  testWidgets(
    'text composer clears drafts and sends only through the keyboard',
    (tester) async {
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            onExit: () {},
            onExplore: () {},
            onSend: (_) async {
              sends++;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('清空输入'), findsNothing);
      expect(find.byType(ChatSendIcon), findsNothing);
      await tester.enterText(find.byType(TextField), '要删除的文字');
      await tester.pump();
      expect(find.byTooltip('清空输入'), findsOneWidget);
      expect(find.byType(ChatSendIcon), findsNothing);
      await tester.tap(find.byTooltip('清空输入'));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(find.byTooltip('清空输入'), findsNothing);
      expect(sends, 0);
      await tester.enterText(find.byType(TextField), '发送这句话');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(sends, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    },
  );

  testWidgets(
    'three designs keep controls visible on phones, landscape and keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [
        const Size(375, 812),
        const Size(390, 844),
        const Size(320, 568),
        const Size(812, 375),
      ]) {
        tester.view.physicalSize = size;
        for (final state in ChatPreviewState.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: ChatPreviewPage(
                key: ValueKey('$size-$state'),
                state: state,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final control = find.byTooltip(
            state == ChatPreviewState.recording ||
                    state == ChatPreviewState.returning
                ? '完成录音'
                : '开始录音',
          );
          final rect = tester.getRect(control);
          expect(rect.bottom, lessThanOrEqualTo(size.height - 34));
          expect(rect.top, greaterThan(0));
          expect(tester.takeException(), isNull);
        }
      }
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              viewInsets: EdgeInsets.only(bottom: 280),
              textScaler: TextScaler.linear(2),
            ),
            child: ChatPage(onExit: () {}, onExplore: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(TextField)).bottom, lessThan(288));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('text sending retains draft on failure and succeeds on retry', (
    tester,
  ) async {
    var succeeds = false;
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          onExit: () {},
          onExplore: () {},
          onSend: (text) async {
            calls++;
            expect(text, '今天想听音乐');
            return succeeds;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '今天想听音乐');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('今天想听音乐'), findsOneWidget);
    expect(find.text('发送失败，请重试'), findsOneWidget);
    succeeds = true;
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'microphone entry starts recording; cancel preserves typed draft',
    (tester) async {
      final backend = FakeVoiceRecorder();
      final capture = VoiceCapture(backend: backend);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            onExit: () {},
            onExplore: () {},
            voiceCapture: capture,
            initialDraft: '保留这句话',
            startRecordingOnOpen: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(backend.starts, 1);
      expect(find.byTooltip('完成录音'), findsOneWidget);
      expect(find.byType(ChatSendIcon), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('取消录音'));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(backend.cancels, 1);
      expect(find.text('保留这句话'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      capture.dispose();
    },
  );

  testWidgets('permission denial stays in text composer without capture', (
    tester,
  ) async {
    final backend = FakeVoiceRecorder()..permitted = false;
    final capture = VoiceCapture(backend: backend);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(onExit: () {}, onExplore: () {}, voiceCapture: capture),
      ),
    );
    await tester.tap(find.byTooltip('开始录音'));
    await tester.pumpAndSettle();
    expect(backend.starts, 0);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('麦克风权限'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    capture.dispose();
  });

  testWidgets('save failure keeps the same recording for retry', (
    tester,
  ) async {
    final backend = FakeVoiceRecorder();
    final capture = VoiceCapture(
      backend: backend,
      elapsed: () => const Duration(seconds: 2),
    );
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          onExit: () {},
          onExplore: () {},
          voiceCapture: capture,
          onVoiceRecorded: (_) async => ++attempts == 2,
        ),
      ),
    );
    await tester.tap(find.byTooltip('开始录音'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('完成录音'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(capture.pending, isNotNull);
    expect(find.textContaining('录音已保留'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('完成录音'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(capture.pending, isNull);
    expect(backend.stops, 1);
    expect(attempts, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    capture.dispose();
  });

  testWidgets(
    'voice bubble plays saved local file; leaving closes the microphone',
    (tester) async {
      final backend = FakeVoiceRecorder();
      final capture = VoiceCapture(backend: backend);
      final playback = FakePlayback();
      const clip = VoiceClip(
        path: '/tmp/sample.m4a',
        duration: Duration(seconds: 3),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            onExit: () {},
            onExplore: () {},
            messages: const [ChatMessage('', isUser: true, voice: clip)],
            voiceCapture: capture,
            voicePlayback: playback,
          ),
        ),
      );
      await tester.tap(find.text('语音 3秒 · 仅本机'));
      await tester.pumpAndSettle();
      expect(playback.played, same(clip));
      await tester.tap(find.byTooltip('开始录音'));
      await tester.pumpAndSettle();
      expect(playback.stops, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(backend.cancels, 1);
      capture.dispose();
    },
  );
}
