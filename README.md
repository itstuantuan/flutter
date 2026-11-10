# Bots

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
配置会编译进客户端，签名密钥在客户端无法作为服务端秘密保密。

## 请求签名

公共 `api` 已启用文档中的 POST 签名流程。配置文件需填写：

- `API_BASE_URL`：其他公共接口地址，按后续文档配置。
- `API_PRODUCT`、`API_PLATFORM`：文档中匹配的一组，例如 `rtvt` / `ios`。
- `API_SECRET_KEY`：该组合的 secretkey1 或 secretkey2 原文，任选一个，不做 Base64 解码。

密钥不预置进仓库；可复制环境文件到本地未提交的配置文件，通过
`--dart-define-from-file` 加载。切换平台时必须同时切换平台和对应密钥。

```dart
final result = await api.post<Map<String, dynamic>>(
  '/实际接口路径',
  data: {'字段名': '字段值'},
);
```

请求体只编码一次，按实际 UTF-8 字节计算 SHA-256 十六进制摘要，再对
方法、含非默认端口的小写 Host、路径（不含查询串）、摘要和三个 X 请求头
按指定顺序进行 HMAC-SHA256 / Base64 签名。UTC 时间戳精确到秒。
自动设置 Content-Type、Accept 和 Authorization，不自动跟随重定向。

签名客户端的 Authorization 专用于签名，不能调用 `api.setToken()` 设置 Bearer。
普通不签名服务仍可独立创建不传 signer 的 `ApiClient`。
`signatureErrorMessage(code)` 提供 1101–1104 的中文提示。

## 数据模型与 JSON 生成

业务模型统一放在对应功能的 `models/` 目录，例如账号模型位于
`lib/features/auth/models/`。项目内直接导入真实模型路径，不为旧路径
保留仅用于转发的兼容文件。

JSON 字段映射使用 `json_serializable` 生成。`*.g.dart` 是生成文件，
禁止手动修改。新增模型或修改模型字段后，需要手动执行：

```bash
dart run build_runner build
flutter analyze
flutter test
```

模型中的业务校验仍写在手写的 `.dart` 文件中；生成器只负责
`Map<String, dynamic>` 与 Dart 对象之间的字段转换。以后新增任何
需要人工配置、生成或运行的步骤，必须同步更新本 README 或它链接的
专项文档。


## 手机验证码登录

`lib/features/auth/account_service.dart` 导出公共实例 `account`。
账号服务使用独立的 `ACCOUNT_BASE_URL`，默认值为
`https://account-api.ilivedata.com`。产品、平台和密钥仍从上述环境配置读取，
请求体 product/platform 自动与签名头一致。首页已接入手机登录测试页，可发送验证码、登录、查看会话并退出。

```dart
import 'package:bots/features/auth/account_service.dart';

// 在 Flutter binding 初始化后调用。恢复的是本地凭证，尚未进行服务器有效性校验。
final savedSession = await account.restoreSession();

await account.sendPhoneVerify(
  phone: '$countryCode-$phoneNumber',
  // ip 默认发送空字符串，可按需传入。
  utmSource: '',
  lang: 'zh-CN', // 可省略；其他值使用英文短信
);
// 页面可每秒读取该值更新按钮；按手机号独立计算，进程重启后以服务器限流为准。
final seconds = account.resendSeconds('$countryCode-$phoneNumber');

final session = await account.phoneVerifyLogin(
  phone: '$countryCode-$phoneNumber',
  code: verificationCode, // String，保留前导零
  // ip 默认发送空字符串，可按需传入。
  // uuid 默认从当前设备读取，web 不传。
);
final isNewUser = session.isNewUser; // registered == 1

await account.logout(); // 清除本地会话，不调用未提供的服务端注销接口
```

`ip` 默认传空字符串，不访问第三方 IP 服务。移动端登录自动读取设备标识：
Android 使用 ANDROID_ID，iOS 使用 identifierForVendor，Web 默认不传 uuid。
读取失败或实际运行平台与配置不匹配时中止登录，不生成随机标识兜底。
这些系统标识不是永久硬件 ID，可能随系统重置、签名或应用安装状态变化。
实现使用 [android_id](https://pub.dev/packages/android_id) 和
[device_info_plus](https://pub.dev/packages/device_info_plus)。

发送成功后，同号本地冷却 60 秒；发送期间也阻止重复点击。服务端返回 status=2
时从收到响应起保守冷却 60 秒。日限额、黑名单和登录频率限制以服务器结果为准。
`AccountException.message` 提供业务错误及签名错误的中文提示，
网络错误仍为 `DioException`，异常响应为 `ApiDecodeException`。

成功登录后自动保存完整会话（含 token），保存失败则抛出错误，不更新内存登录态。
iOS/Android 使用 flutter_secure_storage，Web 配置为 sessionStorage（需 HTTPS 或 localhost）。
缓存按环境、账号域名、产品和平台隔离；损坏缓存会清理。
iOS 已配置 Keychain entitlement，Android 已添加网络权限并禁用自动备份，
避免凭证与设备密钥分离恢复。依赖及配置参见
[flutter_secure_storage 文档](https://pub.dev/packages/flutter_secure_storage) 和
[WebOptions](https://pub.dev/documentation/flutter_secure_storage/latest/flutter_secure_storage/WebOptions-class.html)。

登录、恢复和退出应顺序 await 调用；状态操作进行中再次调用会抛出 StateError。
不要打印 session.toJson() 或 token。后续免登录鉴权接口、token 传参位置及过期处理
尚未提供，当前仅保存/恢复凭证，不把 token 写入签名 Authorization。


## 当前 iOS 联调配置

当前产品为 `bots`，平台为 `ios`。开发模板保留空密钥，实际密钥放在
已被 Git 忽略的 `env/development.local.json` 中；VS Code Debug/Profile 使用此文件。
命令行启动：

```bash
flutter run --dart-define-from-file=env/development.local.json
```

本配置用于 iOS，Android 需另外取得对应密钥。生产环境配置仍待确认。

测试步骤：在 iOS 设备启动后输入国家区号和手机号，点击发送验证码，收到短信后填写并登录。
成功后显示 UID 等用户信息；重启应用可验证本地恢复，点击退出可清除凭证。


## Google 登录

Demo 已增加原生 Google 登录按钮（iOS / Android），取得 Google ID Token 后经签名请求
`/account/google_login` 换取账号系统会话。Google 用户无需绑定手机号。
需提供 iOS OAuth Client ID 和服务器接受的 Web OAuth Client ID，当前值留空。
VS Code 启动前自动生成 iOS 回调配置；命令行启动前需运行配置脚本。
实现原理、运维配置清单、启动命令和联调步骤见 [Google 登录说明](docs/google-login.md)。

应用显示名为 Bots，iOS Bundle ID / Android applicationId 统一为 `com.viitor.bots`。
申请 Google OAuth 客户端或 Apple 签名时请使用此标识。
