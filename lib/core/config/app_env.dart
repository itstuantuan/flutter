/// 由 --dart-define-from-file 注入，修改配置后需要停止并重新运行。
abstract final class AppEnv {
  static const name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
}
