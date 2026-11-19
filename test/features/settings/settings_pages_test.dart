import 'dart:async';

import 'package:bots/features/settings/feedback_page.dart';
import 'package:bots/features/settings/profile_page.dart';
import 'package:bots/features/settings/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'profile edits and persists name, copies UID and shows avatar options',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = SettingsStore();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePage(
            name: '原名字',
            uid: '818949',
            onSave: (profile) => store.saveProfile('818949', profile),
            onLogout: () async {},
          ),
        ),
      );
      Finder trailingIcon(String label) => find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Row))
            .first,
        matching: find.byType(SvgPicture),
      );
      expect(
        tester.getRect(trailingIcon('ViiTor UID')).right,
        tester.getRect(trailingIcon('昵称')).right,
      );
      await tester.tap(find.text('昵称'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '新名字');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('新名字'), findsOneWidget);
      expect((await store.profile('818949')).name, '新名字');
      expect((await store.profile('different-user')).name, isNull);
      await tester.tap(find.text('818949'));
      await tester.pumpAndSettle();
      expect(copied, '818949');
      expect(find.text('UID 已复制'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('更换头像'));
      await tester.pumpAndSettle();
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('从相册中选择'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('拍照'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'logout keeps confirmation and the separate account action is direct',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final completion = Completer<void>();
      var logoutCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePage(
            name: '名字',
            uid: '818949',
            onSave: (_) async {},
            onLogout: () {
              logoutCalls++;
              return completion.future;
            },
          ),
        ),
      );
      final logout = find.widgetWithText(TextButton, '退出登录');
      final accountAction = find.widgetWithText(TextButton, '注销账号');
      expect(
        tester.getCenter(accountAction).dy,
        greaterThan(tester.getCenter(logout).dy),
      );
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(logoutCalls, 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.tap(accountAction);
      await tester.tap(accountAction);
      expect(logoutCalls, 1);
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.widget<TextButton>(accountAction).onPressed, isNull);

      completion.complete();
      await tester.pumpAndSettle();
      await tester.tap(logout);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.text('退出登录'),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(logoutCalls, 2);
    },
  );
  testWidgets('name validation and save errors keep editable page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditNamePage(
          name: '名字',
          onSave: (_) async => throw Exception('offline'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('请设置 1-7 个字符'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '新名字');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.byType(EditNamePage), findsOneWidget);
  });
  testWidgets('feedback selectors, validation and draft survive reopening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = SettingsStore();
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(uid: 'user', store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('提交反馈'));
    await tester.tap(find.text('提交反馈'));
    await tester.pumpAndSettle();
    expect(find.text('请填写详细描述'), findsOneWidget);
    await tester.ensureVisible(find.text('请选择功能').first);
    await tester.tap(find.text('请选择功能').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('对话聊天'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('请选择问题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('速度太慢'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '发消息后等待时间过长');
    await tester.enterText(fields.at(1), 'me@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('提交反馈'));
    await tester.tap(find.text('提交反馈'));
    await tester.pumpAndSettle();
    final draft = await store.feedback('user');
    expect(draft?['function'], '对话聊天');
    expect(draft?['type'], '速度太慢');
    expect(draft?['description'], '发消息后等待时间过长');
    expect(await store.feedback('other-user'), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPage(uid: 'user', store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('对话聊天'), findsOneWidget);
    expect(find.text('速度太慢'), findsOneWidget);
    expect(find.text('发消息后等待时间过长'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('forms fit small screens, landscape and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 568), const Size(812, 375)]) {
      tester.view.physicalSize = size;
      for (final page in <Widget>[
        ProfilePage(
          name: '用户名字七个字',
          uid: '818949',
          onSave: (_) async {},
          onLogout: () async {},
        ),
        const FeedbackPage(uid: 'responsive'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.text(page is ProfilePage ? '退出登录' : '提交反馈');
        await tester.ensureVisible(button);
        await tester.pump();
        expect(button.hitTestable(), findsOneWidget);
        if (page is ProfilePage) {
          final accountAction = find.text('注销账号');
          await tester.ensureVisible(accountAction);
          await tester.pump();
          expect(accountAction.hitTestable(), findsOneWidget);
        }

        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
