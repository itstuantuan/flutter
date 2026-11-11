# 给后端的 APNs 推送接入说明

更新：2026-11-11。方案已确定为 iOS 直接接苹果 APNs。本文说明后端具体要做什么；下方业务接口是建议协议，还未上线，路径和响应封装可按后端现有规范调整后反馈给前端。

## 先看目标：先发通一条，再接探索

用户离开 App 后，AI 探索完成，手机出现“你的 AI 有新发现”。用户点击通知，打开对应的发现详情。

```text
App 获取苹果给的设备地址（device token）
  → App 将地址登记到我们的后端
  → 后端保存“用户 → 设备地址”的关联
  → 探索结果保存成功
  → 后端请求苹果 APNs 发通知
  → 手机显示通知
  → 用户点击，App 用 discoveryId 向后端查询详情
```

第一步不用等 AI 探索做好：先用一个测试账号、一台 iPhone、一条真实可查询的测试发现，手动触发通知，把收发链路跑通。

**后端需要交付：设备登记、设备解绑、发现查询，以及一个内部发送通知的方法。** 不需要给普通 App 用户开放“随意发送通知”的接口。

## 1. 准备苹果配置

让 Apple Developer 账号负责人提供以下配置。前端无需接收私钥。

| 配置 | 是什么 | 放在哪里 |
| --- | --- | --- |
| APNs `.p8` 文件 | 后端向苹果证明身份的私钥 | 服务端密钥管理，不进 App 或 Git |
| Key ID | 这把私钥的编号 | 后端配置 |
| Team ID | 苹果开发团队编号 | 后端配置 |
| Bundle ID | 我们 App 的标识，目前是 `com.viitor.bot` | 后端作为 `apns-topic` |
| 推送环境 | 开发 sandbox 或正式 production | 与设备 token 对应保存 |

当前 iOS Debug、Release、Profile 统一使用团队 `85Q2285229`（ViiTor Tech Ltd.）。所有构建配置的 Bundle ID 已统一为 `com.viitor.bot`；开发者后台的 App ID、签名描述文件和推送控制台也需与此一致。真机签名与 APNs 投递仍需实际验证。

账号负责人还要为该 App 开启 Push Notifications，并更新签名描述文件；前端配合重新构建。

开发环境发往 `https://api.sandbox.push.apple.com`，生产环境发往 `https://api.push.apple.com`。**不能把开发包的 token 发到生产环境，也不能只按业务 API 是测试还是生产来推断推送环境。** 以 App 实际签名中的 `aps-environment` 为准，前后端联调确认。

## 2. 做一个设备登记接口

通俗说：App 告诉后端“当前用户在这台设备上，通知请发到这个地址”。

建议：`PUT /push/installations/{installationId}`

`installationId` 是前端生成并本地保存的安装标识，重开 App 保持不变；不是登录 UUID，也不是 APNs token。目前前端还未实现该标识及上传，待本协议确认后补接。

请求示例：

```json
{
  "platform": "ios",
  "provider": "apns",
  "deviceToken": "苹果返回的完整token",
  "environment": "sandbox",
  "permission": "authorized"
}
```

建议成功响应：

```json
{"status": 0, "data": {"registered": true}}
```

后端处理顺序：

1. 校验登录身份，从登录凭证取得用户 ID，不能相信客户端另传的 userId。业务 token 放哪里需后端确认；项目已有签名 Authorization，不能直接覆盖。
2. 校验平台、环境与权限枚举。permission 建议支持 authorized、provisional、ephemeral、denied、notDetermined；仅前三种允许发送可见通知。token 原样存储，不假设固定长度；无 token 时允许仅同步权限，但不能激活发送。
3. 按安装标识更新记录，保存 userId、deviceToken、environment、permission、enabled、updatedAt 和绑定版本。重复请求不能新增重复设备。
4. 同一安装切换账号时，原子替换旧绑定；同一环境/应用/token 不能同时归属两个账号。发送时再次检查当前绑定，防止旧任务发给新账号。
5. 返回明确成功或错误；鉴权失败与参数错误需区分。后端将最终响应封装和错误码提供给前端。

前端会在登录后、token 更新后、权限变化后调用。permission 关闭时停止向该安装发送；一个用户是否给所有有效设备发送，首版建议全部发送，需产品确认。

## 3. 做一个设备解绑接口

通俗说：用户退出账号后，不能继续收到这个账号的通知。

建议：`DELETE /push/installations/{installationId}`，使用当前用户登录凭证。

- 校验记录属于当前用户，再取消绑定；重复解绑按成功处理。
- 不能让账号 A 的延迟退出请求删除已经归属账号 B 的绑定。建议校验用户与绑定版本。
- 前端应先尝试解绑再清理登录凭证；网络失败不能冒充解绑成功，需安排重试。服务端如能处理会话注销，应同时失效该会话的推送关联。离线退出的即时解绑无法仅靠客户端保证。
- 解绑无法撤回已经送达或正在投递的通知，所以通知正文只用简短通用提示；点击后仍要验证发现归属。

建议成功响应：`{"status":0,"data":{"unregistered":true}}`。

## 4. 在后端实现“发一条通知”

建议内部方法：`sendDiscoveryNotification(userId, discoveryId, eventId)`。它不是 App 公开接口。

### 4.1 方法内部怎么做

1. 查询 discoveryId，确认结果已保存且属于 userId。
2. 查找该用户允许接收通知的设备；没有有效设备就跳过，结果仍保留在应用发现列表中。
3. 根据每条设备记录的环境选择苹果地址，构造通知内容并发送。
4. 记录 eventId、安装标识、APNs 请求标识、结果和错误原因；不记录私钥或完整 token。
5. 通过 eventId + 安装标识 + 绑定版本去重，发送前检查绑定仍有效。网络超时可能已被苹果接收，不能承诺严格只送一次。

### 4.2 发给苹果的请求长什么样

使用支持 HTTP/2 的服务端客户端或 APNs 库。下面是协议示意，不是直接粘贴可运行的脚本：

```http
POST https://api.sandbox.push.apple.com/3/device/{deviceToken}
Authorization: bearer {服务端生成的APNs_JWT}
apns-topic: com.viitor.bot
apns-push-type: alert
apns-priority: 10
Content-Type: application/json
```

请求正文：

```json
{
  "aps": {
    "alert": {
      "title": "你的 AI 带回了新发现",
      "body": "探索完成了，来看看吧"
    },
    "sound": "default"
  },
  "type": "discovery",
  "discoveryId": "真实可查询的发现ID",
  "eventId": "本次事件的唯一ID"
}
```

`aps` 告诉 iPhone 展示什么；外面的 type、discoveryId 告诉 App 点击后去哪里；eventId 用于追踪和去重。不要在正文中放私人聊天原文或整份探索结果。

APNs_JWT 不是用户登录 token，也不是 device token。它由服务端用 `.p8` 签名生成：算法 ES256，header 包含 kid（Key ID），claims 包含 iss（Team ID）和 iat（UTC 秒）。使用成熟库生成并缓存，在一小时有效窗口内刷新，不要每条通知重新生成。参考 [苹果鉴权文档](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns)。

请求格式及环境以 [苹果发送通知文档](https://developer.apple.com/documentation/UserNotifications/sending-notification-requests-to-apns) 为准。

### 4.3 苹果返回错误怎么办

| 结果 | 后端动作 |
| --- | --- |
| HTTP 200 | 记录“苹果已接受”，不能当成用户已经看到或点开 |
| token 失效，如 Unregistered / 410 | 停用对应旧注册；结合失效时间/注册版本，避免误停刚更新的 token |
| BadDeviceToken / DeviceTokenNotForTopic | 检查环境、Bundle ID 和 token，不盲目重试 |
| 鉴权错误 / 403 | 检查密钥、JWT 时钟与有效期；不是设备问题，别删除用户设备 |
| 限流、服务暂不可用或网络错误 | 按错误原因及苹果建议做有限次数退避重试，超出上限记录失败 |

队列建议设置消息过期时间；内容过期就停止重试。推送失败不回滚探索结果。苹果官方 [响应处理说明](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns) 是错误分类的依据。

## 5. 提供发现详情，并连接探索任务

建议：`GET /discoveries/{discoveryId}`，需要用户鉴权。

最小响应草案：

```json
{
  "status": 0,
  "data": {
    "discoveryId": "发现ID",
    "taskId": "探索任务ID",
    "aiId": "当前AI的ID",
    "title": "发现标题",
    "summary": "简短摘要",
    "content": "详情内容",
    "createdAt": "2026-11-11T08:00:00Z"
  }
}
```

后端确认内容类型、字段和错误码；只能读取当前用户有权限的发现。目标已删除、无权限、网络错误时，前端显示提示并返回主体验，不展示其他用户内容。

第一条测试通知成功后，再接探索业务：**先保存结果，再把推送任务交给后台队列。** 建议使用事务消息/可靠任务记录，避免结果已提交但发送任务丢失。探索完成后无需等待用户保持 App 在线。

首版建议一个探索完成事件发一次提醒；首条发现是否单独推、免打扰和频率限制由产品确认，不默认每条 AI 消息都推。App 再次打开仍查询发现列表，不能只依赖通知。

## 联调时，双方各做什么

| 顺序 | 后端 | 前端 / 测试 | 通过标准 |
| --- | --- | --- | --- |
| 1 | 配好苹果密钥与 sandbox，提供接口协议 | 配签名，在真机允许通知 | 成功取得 token，不代表已收到推送 |
| 2 | 上线登记、解绑接口 | 登录后上传设备信息 | 数据库中用户与设备关联正确 |
| 3 | 建一条可查询发现，内部手动调用发送方法 | App 退到后台 | 锁屏/通知栏出现通知 |
| 4 | 提供发现详情查询 | 点击通知，分别测试后台和完全关闭后启动 | 身份恢复后进入正确详情 |
| 5 | 接探索完成触发与重试 | 测拒绝权限、退出、换号、断网和失效目标 | 不串号，失败可恢复，没通知也能查结果 |

苹果返回 200、设备展示通知、用户点击通知是三种不同结果，联调分别检查。使用真机验收，模拟器编译成功不能证明实际投递成功。

## 当前进度：别把草案当成已上线

- 前端已实现：iOS 权限申请、APNs token 获取、失败重试、设置入口、前台横幅，以及点击信息的基础桥接。
- 前端尚未实现：安装标识生成与后端登记、更新/解绑联动、真实详情查询与鉴权后跳转、事件去重；等待协议后接入。
- 当前点击通知只提示已收到点击，不能打开真实发现；冷启动场景仍需联调。
- 后端尚未在本项目中提供上述接口或发送服务；Apple Developer 能力和真机投递尚未确认。
- 本地实现位置：`ios/Runner/AppDelegate.swift`、`lib/features/notifications/push_service.dart`。本阶段不依赖静默推送或客户端后台探索。

## 后端现在回复这五项即可开始对接

1. 设备登记、解绑、发现详情的最终接口路径、请求响应和错误码。
2. 用户业务 token 的鉴权方式；如何与现有请求签名共存。
3. APNs 密钥是否准备好，sandbox 是否可发测试通知。
4. 是否接受上述通知字段 type、discoveryId、eventId，以及一条可联调的真实发现 ID。
5. 一个接口联调联系人及测试环境地址。

## 前端本地模拟测试（不需要后端）

调试版右上角菜单 → **5 秒后发送本地测试通知** → 允许通知 → 回到桌面 → 点击通知。
系统约 5 秒后显示“模拟发现已准备好”，点击打开固定的“模拟发现详情”。可在首次引导任意步骤测试，不需要登录或等待探索完成；返回后仍保留原流程进度。

这是 iOS 本地通知，不经过 APNs，不需要设备 token 或服务端发送。它只能验证系统展示与前端跳转，不能证明远程投递成功。拒绝权限后需在系统设置中允许再试。

测试入口及原生调度仅调试版启用，固定通知 ID 再次安排会替换尚未触发的同名通知。模拟数据不映射真实 discoveryId，也不标记真实发现为已读。冷启动点击同时通过 SceneDelegate 交接；最终仍需真机验证。原生改动后请完整重建 App，不能只热重载。
