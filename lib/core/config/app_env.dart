/// 由 --dart-define-from-file 注入，修改配置后需要停止并重新运行。
abstract final class AppEnv {
  static const enableTestTools = bool.fromEnvironment('ENABLE_TEST_TOOLS');

  static const name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const apiProduct = String.fromEnvironment('API_PRODUCT');
  static const apiPlatform = String.fromEnvironment('API_PLATFORM');
  static const apiSecretKey = String.fromEnvironment('API_SECRET_KEY');

  static const accountBaseUrl = String.fromEnvironment(
    'ACCOUNT_BASE_URL',
    defaultValue: 'https://account-api.ilivedata.com',
  );

  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
}
