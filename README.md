# Bots

Flutter 项目。

## 产品流程规划

[ViiTor 首版流程与接口规划](docs/product-flow-plan.md) 记录已确认需求、首次使用与回访流程、数据模型草案、建议接口、实施阶段及待确认问题。UI 尚未定稿；该文档不表示功能或接口已经实现。

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

应用显示名为 Bots，iOS Bundle ID / Android applicationId 统一为 `com.viitor.bot`。
申请 Google OAuth 客户端或 Apple 签名时请使用此标识。

## APNs 与调试入口

iOS 使用系统通知授权、APNs token 及后端设备登记。真机联调见
[APNs 接入说明](docs/apns.md)。App 从正式开屏和登录流程启动，已移除应用内调试菜单及独立预览路由。

## 11.13 更新版 UI

以 Figma `Ee34W01RdusrU2afb7rvhP / 271:1401` 的最新设计为准：
开屏 → 恢复会话；首次使用依次进入两页引导 → 手机号 → 六位验证码 → 名字 → 新用户注册对话。
注册对话的欢迎、正常对话、录音是同一流程的三种状态。点“跳过”进入首页，点“先去探索世界”进入兴趣选择；
完成状态按账号保存在本机，之后从首页打开的是老用户聊天页。未完成时重启继续注册对话。
已有会话直接进首页；有注册历史但已退出的用户直接进入手机号登录。引导进度和名字本地保存，登录响应 `registered=1` 用于区分新旧用户聊天状态。
本地恢复仅表示已有保存的账号凭证，后端 token 校验与过期策略仍待鉴权接口接入。
首页左下角“逛一逛”首次进入兴趣选择，选择并保存后进入广场；完成状态按账号保存在本机，之后直接进入广场；支持三种发现卡片、分页点和原有“去看看”入口。
协议入口按要求先保留占位，可通过登录页回调接入正式链接；没有自动发送短信。

首页聊天与实际模拟发现沿用原有本地模拟逻辑；设计卡片是静态示例。
广场每次新进入随机播放十个本地剧情之一，按原台词顺序以纵向弹幕淡入上移，名字浅蓝、台词白色；
长句延长阅读时间，支持回看，播完停留。进入其他页面或切到后台时暂停，返回继续；连续两次不重复。
好友按钮、广场更多按钮和老用户聊天分享按钮按设计的透明度 0 隐藏。

首页右下角聊天按钮进入新的全屏聊天页，麦克风按钮进入后申请录音权限并开始录音。
支持欢迎、正常对话、录音和老用户四种状态；录音可取消、保存并点击语音气泡回放。
iOS / Android / macOS 录音存于应用本地目录，记录随本机体验进度保存；Web 录音仅在当前聊天页有效。
录音最长两分钟，退到后台或退出页面会停止并清理未保存录音。
预览页面保留本地模拟；真实聊天已接入语音上传、转写及附件消息发送，AI 语音回复（TTS）尚未接入。

页面采用原生文字和交互控件，装饰使用 UI 切图。设计尺寸为 375×812；
短屏先收紧留白，空间不足时滚动内容，不按高度缩窄整页；长屏背景等比裁切。
按钮和标题栏遵守系统安全区，大字体自然换行并增加内容高度。
系统状态栏和手势条由设备绘制。素材与节点对应关系见
[11.12 UI 实现说明](docs/ui/11-12.md)。

**本次新增了素材，停止当前调试后重新 F5 启动，不能只热重载。**

验证：`flutter analyze`、`flutter test`；iOS 构建沿用上方本地环境配置。

## 真实聊天 SSE（2026-11-16）

开发环境 `API_BASE_URL=https://bot-test.viitor.live`，地址填写域名，不附加
`/api/v1/chat`；修改后须完整重启运行，热重载不能刷新 dart-define。
协议依据后端 `viitor-bots-v1-reviewed-20261113/docs/FRONTEND_INTEGRATION_V1.md`。

已登录用户的对话入口使用独立、不签名的 `ChatService`，每个 REST/SSE 请求
从当前账号会话读取 token、uid，并使用与登录相同的设备标识读取方式，发送
`Authorization: Bearer …`、`X-User-Id`、`X-Device-ID`、`X-Channel`
（iOS 300 / Android 200）。账号服务本身仍使用原来的签名客户端。

登录后的主流程先 GET me，必要时用已保存的称呼 bootstrap，再读取 home、历史并订阅 SSE。
快照按轮次 id 替换合并，保留早期历史；发送成功显示 202 回执，网络失败保留草稿
和该次请求的 clientMessageId，同正文重试复用 ID。断流按 1/2/4/8/10 秒退避重连，
不重新发送消息；首页、广场和聊天共用订阅，进入后台或退出账号关闭，回前台重新拉取历史。401 清理登录态
并进入登录页。凭证和消息正文不记录到 HTTP 日志。

已接入文本聊天、snapshot、探索、完成弹卡/确认、首页结果定位及语音输入。
录音完成后以 multipart 上传，轮询附件至 ready，再携带 attachmentIds 发送聊天；失败保留录音，显式重试复用附件及聊天幂等 ID。
退出聊天取消语音上传/轮询；成功后清理本地录音。完整历史浏览 UI、远程音频回放和 TTS 尚未接入。

验证：`flutter analyze`、`flutter test test/features/chat`。

模拟器联调记录：当前登录会话通过 me/bootstrap、home、历史和 SSE 鉴权；发送
`hello` 收到 `Hello! How’s your day going?`。另一次生成曾返回
`UPSTREAM_HTTP_403`，页面按失败轮次展示错误码，属于模型上游返回，未绕过鉴权。
聊天/登录回归共 61 项通过。若仓库同时包含不带资源的软著导出源码副本，使用
`flutter analyze lib test` 单独检查实际应用与测试；根目录分析可能报告副本资源缺失。

探索/首页/定位的最新产品约定、真实验证与后端差异见 [2026-11-16 联调记录](docs/backend-integration-20261116.md)。


### 系统语音输入

真实聊天的麦克风入口现在调用系统语音识别（speech_to_text），后台实时识别中文，界面保留原设计的取消、声波、时长及圆形发送按钮，不展示转写预览。
点击「发送」停止收音，等待最后识别结果后直接走普通文本消息接口，不上传录音附件；发送失败保留文字供重试。
取消恢复原草稿；中断保留已识别文字；离开页面或进入后台停止收音。
iOS 需要麦克风和语音识别授权，系统识别可能联网；不承诺所有设备离线可用。
系统可能因静音或时长限制提前结束，此时文字仍可编辑发送。
原附件语音服务保留用于兼容，真实聊天入口不再调用它。
