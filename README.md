# sweet

Flutter 项目。

## 环境配置

在 `env/development.json`（开发环境）或 `env/production.json`（生产环境）
中填写 `API_BASE_URL`，例如 `https://api.example.com`，可以包含 `/api/v1` 等路径前缀。
目前地址留空，需要填写实际后端地址后才能调用相对路径接口。

VS Code 的 Debug、Profile 配置使用开发环境，Release 使用生产环境。
环境和构建模式相互独立，也可以在命令行自由组合：

```bash
flutter run --dart-define-from-file=env/development.json
flutter run --release --dart-define-from-file=env/production.json
flutter build ios --release --dart-define-from-file=env/production.json
```

代码通过 `AppEnv.apiBaseUrl` 读取地址，公共客户端 `api` 已接入。
这些是编译时配置；修改后需要停止并重新运行，热重载不会更新配置。
配置会编译进客户端，只用于接口地址等公开配置，不用于保存私钥或服务端密钥。
