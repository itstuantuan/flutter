# Google 登录：实现与配置

## 已实现的流程

Demo 首页已有「使用 Google 账号登录」按钮，当前接入 iOS / Android 原生授权。
Flutter Web、桌面端未接入此按钮的授权流程，点击会给出明确提示，不回退到 WebView。

1. 用户点击按钮，校验当前产品/平台签名配置和 Google OAuth Client ID。
2. `google_sign_in` 调用 Google 原生 SDK，用户在 Google 界面选择账号并确认授权。
3. 读取 `GoogleSignInAccount.email` 和 `authentication.idToken`。
4. 使用现有签名客户端，发送 `POST /account/google_login`：

   ```json
   {
     "email": "由 Google SDK 返回",
     "idToken": "Google 原生 OAuth ID Token",
     "ip": "",
     "utm_source": "",
     "uuid": "从当前移动设备读取",
     "product": "bots",
     "platform": "ios"
   }
   ```

5. `Authorization` 仍是原有 HMAC 签名。Google ID Token 放在 JSON 的 `idToken` 字段，
   不是 Bearer 请求头，也不是 Firebase ID Token 或 Google Access Token。
6. `status == 0` 且账号数据合法时，保存账号系统返回的用户信息及业务 token。
   iOS/Android 使用原有安全存储，沿用本地会话恢复和退出流程。
   Google 用户可以没有手机号，界面显示邮箱以及“手机号未绑定”。
7. 移动端在授权前读取设备 uuid（iOS 为 identifierForVendor，Android 为 ANDROID_ID），
   读取失败时中止登录。ip 和 utm_source 默认空字符串，utm_source 可通过 utmSource 参数传入。
   status=4 表示 Google ID Token 无效，页面和日志提示重新授权，不自动重试。
8. Google ID Token 仅用于本次交换，不写入缓存或日志。授权步骤结束后清理 SDK 临时登录态，
   不撤销 Google 授权。后端失败不会替换已有业务会话；取消授权不调用账号接口。

后端免登录鉴权接口尚未提供，因此“恢复本地会话”依然不表示服务端确认业务 token 有效。

## 从 Web 项目借鉴了什么

读取了 `/Users/admin/Documents/viitor-memo-web/src/services/google-auth.ts` 和 `referrals.ts`。
邀请页用 Firebase `signInWithPopup` 做 Google 网页授权，取的是
`GoogleAuthProvider.credentialFromResult(result).idToken`，然后把 email/idToken 提交给邀请服务。
邀请服务会继续调用账号系统，并额外处理邀请绑定。

该文件注明了其来源 `viitor-rtvt-web/components/auth/Login.vue`，因此继续核对了该项目的
`server/api/google_login.post.ts` 和 `server/utils/request.ts`：确认账号端路径是
`/account/google_login`，字段为 email、idToken、ip、product、platform，且使用现有 HMAC 签名。

Flutter 保留“Google 证明身份 → 账号服务签发业务 token”的协议，改用适合手机的原生 SDK。
没有复制 Firebase 网页弹窗、Web Cookie、邀请绑定、浏览器 Origin 或 Web 项目的 rtvt 密钥。
没有修改这两个参考项目。

`bots / ios` 是否在后端开启 Google 登录，以及是否接受所选 OAuth audience，仍需用户系统负责人确认。
已根据用户系统提供的 Google 登录文档校正：请求包含 email、idToken、ip、utm_source、product、platform，
iOS/Android 必须带设备 uuid；响应解析 registered、uid、nick、email、product、platform、token。
Google 响应不要求 phone/avatar，缺省按空字符串处理；邮箱必须与授权结果匹配。
错误码处理为 0 成功、-1 内部错误、1 参数错误、4 非法 idToken。
文档示例中的 viitor-ai/android 是示例值，当前请求仍使用已约定的 bots/ios 和对应签名密钥。

## 需要谁提供什么

| 负责人 | 配置或确认项 | 说明 |
| --- | --- | --- |
| Google Cloud / Firebase 项目管理员 | GOOGLE_IOS_CLIENT_ID | OAuth 类型为 iOS，Bundle ID 必须与实际 iOS App 一致。当前为 com.viitor.bot |
| Google Cloud / Firebase 项目管理员 + 用户系统后端 | GOOGLE_SERVER_CLIENT_ID | OAuth 类型为 Web application，用作服务器验证 ID Token 的 audience；不是 iOS Client ID |
| 用户系统后端 | bots / ios 的 Google 登录和 audience 校验 | 确认 /account/google_login 可用，接受上述 Web Client ID，按需要配置原生客户端的 authorized party / azp |
| Google Cloud 项目管理员 | OAuth 同意屏幕 | 应用名称、支持邮箱、使用范围、测试用户；Testing 阶段给测试账号放行，正式上线时完成适用的发布/验证要求 |
| Android 发布负责人（测试 Android 时） | Android OAuth 客户端 | 注册实际 applicationId（当前 com.viitor.bot）以及 debug/release/Google Play App Signing 对应 SHA-1；Firebase 项目按要求也登记 SHA-256 |
| 用户系统负责人（测试 Android 时） | bots / android 签名密钥 | 当前配置只有 bots / ios，不可把 iOS 密钥用于 Android |

优先在现有 Google 项目中创建原生客户端，并让 Web 类型的服务器客户端与之属于同一项目。
参考 Web 项目用的是 `viitorai` Firebase 项目，但它的 Firebase apiKey / appId 不能当作这些 OAuth Client ID。
若产品采用别的 Google 项目，必须同步调整服务器 audience 白名单。

后端应验证 Google token 的签名、issuer、audience、有效期，并以验证后的身份声明为准；
请求中的 email 不是可独立信任的身份证明。不要为了联调跳过 audience 校验。

App 不需要 Google OAuth client secret，也不需要服务账号私钥。
本实现直接使用原生 Google 登录，不依赖 Firebase Auth SDK，也不需要复制 Firebase Web 配置。
Android 通过显式 serverClientId 初始化，本实现不要求接入 google-services.json 插件；
iOS 通过 Dart 传 Client ID，通过 URL Scheme 接收回调。

## 配置和启动

在 `env/development.local.json` 保留现有账号签名配置，补全两个公开 ID：

```json
{
  "GOOGLE_IOS_CLIENT_ID": "实际iOS客户端ID.apps.googleusercontent.com",
  "GOOGLE_SERVER_CLIENT_ID": "实际Web客户端ID.apps.googleusercontent.com"
}
```

上述值只是格式示意，需替换为控制台生成的 ID；不用修改已有 API_SECRET_KEY。
仓库模板中的 Google 配置故意留空，缺配置时手机号登录仍可使用，Google 按钮会提示具体缺项。

VS Code Debug/Profile 已添加 preLaunchTask：从 `env/development.local.json` 生成
`ios/Flutter/GoogleSignIn.local.xcconfig`。Release 使用 `env/production.json`。
生成文件只含反转后的 iOS Client ID，不含签名密钥；文件已加入 Git 忽略。
Info.plist 的 CFBundleURLSchemes 通过该值配置原生 Google 回调。

命令行或 CI 启动前执行（两条命令必须使用同一个配置文件）：

```bash
python3 scripts/configure_google_sign_in.py --config env/development.local.json
flutter run --dart-define-from-file=env/development.local.json
```

添加插件或修改 OAuth 配置后需停止并重新构建，不能只热重载。
直接在 Xcode 构建时，先运行配置脚本和对应 Flutter 构建命令，保证 Generated.xcconfig 中的 Dart defines 正确。
不要在同一工作区并行构建使用不同 Google Client ID 的环境，以免生成的 iOS 配置相互覆盖。

## 联调步骤

1. 填入上述 ID，确认手机能访问 Google 登录服务，启动 iOS Demo。
2. 点击 Google 登录并选测试账号。可先测试取消：不应发出账号服务请求，也不应清除旧会话。
3. 授权成功后查看诊断日志：Google 原生授权 OK → `/account/google_login` 的 HTTP/status。
4. status=0 后应显示 UID、邮箱、业务 token 已保存；重启验证恢复，退出验证本地清理。
5. 再验证另一账号、后端拒绝和网络失败。不要把 ID Token、业务 token 或完整请求体发到聊天/日志中。

常见问题：

- 缺 GOOGLE_SERVER_CLIENT_ID / GOOGLE_IOS_CLIENT_ID：补环境文件并完整重启。
- iOS 不能回到 App：核对 iOS Client ID、Bundle ID、生成的反转 Client ID URL Scheme。
- Android 选账号后自动取消 / clientConfigurationError：核对包名、签名 SHA 和 Web serverClientId。
- Google 授权成功但账号接口失败：后端检查 bots/平台开关、Google audience/azp、签名密钥和返回 status。
- 网络错误：Google 服务不可达时原生授权无法完成；本代码不会绕过 Google 身份校验。

## 参考资料

- [google_sign_in 官方插件](https://pub.dev/packages/google_sign_in)
- [iOS 配置说明](https://pub.dev/packages/google_sign_in_ios)
- [Android 配置说明](https://pub.dev/packages/google_sign_in_android)
