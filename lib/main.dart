import 'package:flutter/material.dart';

import 'features/auth/account_service.dart';
import 'features/auth/auth_debug_log.dart';
import 'features/auth/login_demo_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AuthDebugLog.event('Demo 启动 · diagnostics-v2 · Debug 日志已启用');
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3659C9)),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      home: LoginDemoPage(service: account),
    );
  }
}
