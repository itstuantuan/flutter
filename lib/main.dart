import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/app_language.dart';
import 'core/localization/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/character/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.restore();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) => MaterialApp(
        locale: AppLanguage.instance.locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppTranslations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        title: 'Pals',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashPage(),
      ),
    );
  }
}
