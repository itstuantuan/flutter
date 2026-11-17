import 'dart:async';

import 'package:bots/features/chat/chat_page.dart';
import 'package:bots/features/chat/system_dictation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDictation extends SystemDictation {
  Completer<void>? finishGate;
  String? finalWords;
  @override
  Future<void> start() async {
    active = true;
    text = '';
    notifyListeners();
  }

  void words(String value) {
    text = value;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    await finishGate?.future;
    if (finalWords != null) text = finalWords!;
    active = false;
    notifyListeners();
  }

  @override
  Future<void> cancel() async {
    active = false;
    notifyListeners();
  }
}

void main() {
  testWidgets('dictation sends final text directly on send tap', (
    tester,
  ) async {
    final speech = FakeDictation();
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          onExit: () {},
          onExplore: () {},
          useSystemDictation: true,
          dictation: speech,
          initialDraft: '原草稿',
          showWelcome: false,
          onSend: (text) async {
            sent.add(text);
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.byTooltip('开始录音'));
    await tester.pump();
    speech.words('识别文字');
    await tester.pump();
    expect(find.text('原草稿 识别文字'), findsNothing);
    expect(find.text('00:00'), findsOneWidget);
    expect(sent, isEmpty);
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    expect(sent, ['原草稿 识别文字']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'send waits for final words, prevents duplicates and retains failed text',
    (tester) async {
      final speech = FakeDictation()
        ..finishGate = Completer<void>()
        ..finalWords = '最终识别文字';
      final sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            onExit: () {},
            onExplore: () {},
            useSystemDictation: true,
            dictation: speech,
            onSend: (value) async {
              sent.add(value);
              return false;
            },
          ),
        ),
      );
      await tester.tap(find.byTooltip('开始录音'));
      await tester.pump();
      speech.words('中间结果');
      await tester.pump();
      await tester.tap(find.byTooltip('发送'));
      await tester.pump();
      expect(sent, isEmpty);
      await tester.tap(find.byTooltip('发送'));
      speech.finishGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(sent, ['最终识别文字']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '最终识别文字',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cancel restores draft and does not send', (tester) async {
    final speech = FakeDictation();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          onExit: () {},
          onExplore: () {},
          useSystemDictation: true,
          dictation: speech,
          initialDraft: '保留草稿',
        ),
      ),
    );
    await tester.tap(find.byTooltip('开始录音'));
    await tester.pump();
    speech.words('不要的文字');
    await tester.pump();
    await tester.tap(find.byTooltip('取消录音'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '保留草稿',
    );
    expect(speech.active, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
