import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'en.dart';
import 'plaza_en.dart';
import 'ui_en.dart';

class AppTranslations {
  const AppTranslations(this.locale);
  final Locale locale;
  static const delegate = _TranslationsDelegate();
}

class _TranslationsDelegate extends LocalizationsDelegate<AppTranslations> {
  const _TranslationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);
  @override
  Future<AppTranslations> load(Locale locale) =>
      SynchronousFuture(AppTranslations(locale));
  @override
  bool shouldReload(_TranslationsDelegate old) => false;
}

bool isEnglish(BuildContext context) =>
    Localizations.of<AppTranslations>(
      context,
      AppTranslations,
    )?.locale.languageCode ==
    'en';

String translate(BuildContext context, String value) {
  // Standalone legacy previews without the app delegate retain their source copy.
  final locale = Localizations.of<AppTranslations>(
    context,
    AppTranslations,
  )?.locale;
  if (locale?.languageCode != 'en') return value;
  final extraCopy = uiEnglish[value];
  if (extraCopy != null) return extraCopy;
  final storyCopy = plazaEnglish[value];
  if (storyCopy != null) return storyCopy;
  if (english.containsKey(value)) return english[value]!;
  final errorCode = RegExp(r'^请求失败（(?:错误码[： ]|HTTP )(.+)）$').firstMatch(value);
  if (errorCode != null) return 'Request failed (${errorCode[1]}).';
  const failedReply = '这次回复未完成，请重新发送消息再试。';
  if (value.startsWith(failedReply)) {
    return 'This reply could not be completed. Please send your message again.${value.substring(failedReply.length)}';
  }
  final resend = RegExp(r'^(\d+)s 后(?:重发|重新发送)$').firstMatch(value);
  if (resend != null) return 'Resend in ${resend[1]}s';
  if (value.startsWith('验证码发送至')) return 'Code sent to ${value.substring(6)}';
  if (value.startsWith('今天 ')) return 'Today ${value.substring(3)}';
  if (value == '昨天') return 'Yesterday';
  if (value.startsWith('昨天 ')) return 'Yesterday ${value.substring(3)}';
  final date = RegExp(r'^(?:(\d+)年)?(\d+)月(\d+)日 (.+)$').firstMatch(value);
  if (date != null) {
    return '${date[1] == null ? '' : '${date[1]}-'}${date[2]!.padLeft(2, '0')}-${date[3]!.padLeft(2, '0')} ${date[4]}';
  }
  final greeting = RegExp(r'^嗨!我是(.*)\.很高兴见到你!\n在一起探索之前,我想先多了解你一点\.$')
      .firstMatch(value);
  if (greeting != null) {
    return 'Hi! I’m ${greeting[1]}. Nice to meet you!\nBefore we explore together, I’d love to get to know you.';
  }
  final voice = RegExp(r'^语音 (\d+)秒 · (本次会话|仅本机)$').firstMatch(value);
  if (voice != null) {
    return 'Voice ${voice[1]}s · ${voice[2] == '本次会话' ? 'This session' : 'On this device'}';
  }
  final onboarding = RegExp(r'^引导，第 (\d+) 页，共 (\d+) 页$').firstMatch(value);
  if (onboarding != null) {
    return 'Introduction, page ${onboarding[1]} of ${onboarding[2]}';
  }
  final page = RegExp(r'^发现第 (\d+) 页$').firstMatch(value);
  if (page != null) return 'Discovery page ${page[1]}';
  final discovery = RegExp(r'^第 (\d+) 条发现，共 (\d+) 条$').firstMatch(value);
  if (discovery != null) return 'Discovery ${discovery[1]} of ${discovery[2]}';
  if (value.startsWith('移除')) {
    return 'Remove ${translate(context, value.substring(2))}';
  }
  final seconds = RegExp(r'^已探索 (\d+) 秒 · 发现后告诉你$').firstMatch(value);
  if (seconds != null) return 'Exploring for ${seconds[1]}s · Updates soon';
  final minutes = RegExp(r'^已探索 (\d+) 分 (\d+) 秒$').firstMatch(value);
  if (minutes != null) return 'Exploring for ${minutes[1]}m ${minutes[2]}s';
  final interests = RegExp(r'^-  选择(\d+),还可以选择(\d+)个 -$').firstMatch(value);
  if (interests != null) {
    return '${interests[1]} selected · ${interests[2]} more available';
  }
  if (value.endsWith('加载失败，请重试。')) return 'Could not load. Please try again.';
  return value;
}

/// Use only for interface copy, never for user or server-authored content.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => Text(
    translate(context, data),
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}
