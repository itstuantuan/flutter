# 2026-11-16 前端主流程联调

依据：`viitor-bots-frontend-20261116/01-完整接口参考.md`、`02-产品流程联调指南.md`。
冲突时以本次用户确认的前端交互为准，不依据后端 nextPage 改写页面流程。
测试环境：`https://bot-test.viitor.live`。生产地址未改。

## 已确认的产品行为

- 设置名字后保留首次对话页；对后端是普通聊天，可跳过，不增加特殊聊天类型。
- 首页“去看看”进入聊天，通过探索 taskId 定位原消息，用 materialId 定位该消息内相应内容。
- 整次探索完成后发布聊天结果。后端负责生成一条完整的 discovery 消息，前端直接显示 assistantText，不拼接或重复附加卡片正文。
- 首页/发现弹窗使用后端卡片数据，按实际数量展示，最多三条。本次真实测试返回两条；不补造第三条。
- 广场每次轮询都读取 progress.cards。searching 时也展示本次新返回的卡片，同一任务按 materialId 去重。同批返回的一起展示，上一批关闭后再展示下一批。complete、empty 或 failed 时结束轮询。
- 广场保留现有前端随机静态情景对白，不读取或显示后端 square/discussions。
- 首页保留上次结果直到有新的非空结果，跨天和空探索均不清空。

## 本次接入

- 当前账号主流程持有一个 ChatController/SSE；首页、广场、聊天共用状态。应用退后台暂停，回前台恢复；普通页面切换不取消探索。
- me/bootstrap 初始化资料与会话；读取 home 和聊天历史。
- 首次出发读取 me/interests，用最新 Account.revision 保存选择，再 POST explorations。
- 并发点击防重；有 activeExploration 时恢复原任务。探索幂等 ID 在 POST 前按环境/账号持久保存，超时重试复用；恢复已受理任务后清除旧操作 ID。
- 广场轮询 progress，完成由服务端 phase 判定；退出页面停止轮询。完成事件来自 SSE 或 completions，不由前端造消息。
- REST/SSE 共用 eventId 集合。弹窗呈现或聊天结果可见后，先保存已展示记录，再 PUT acknowledgement；失败保留待确认记录，在重连/回前台补确认。
- locate 返回 anchorTurnId 与前后消息；前端合并原消息、滚动、高亮。单卡标题能在后端原文中找到时定位该段，否则定位整条消息。
- 从卡片进入后，发送追问携带原探索 referenceTaskId 和 referenceMaterialId；离开该聊天页面清除引用。
- 重连用 messages/after 补收已知最新 ID 后的记录，避免仅取最新50轮漏掉离线期间的消息。

## 首页跨天兼容及后端差异

`GET /home` 文档明确只返回当天的最近有效发现，与用户确认的保留规则不同。
当前前端保留已显示的卡片；当 home.cards 为空时，查询 `/explorations` 历史，检查
`progress.phase=complete` 且 cards 非空，再通过 locate 验证发布消息并恢复首页结果。
恢复的全部内容来自服务端，不改 SSE、不开新探索、不使用前端虚构结果。

建议后端将 `/home.cards` 改为不受日期限制的最近非空且已发布结果，这样可以减少
历史、进度和定位的额外请求。当前跨天恢复通过模拟服务测试验证，未通过改变设备日期
或修改后端数据库伪造真实跨天验收。

其他观察与待确认项：

- 本次 discovery.assistantText 开头为“我通过平台素材探索和AI模拟交流带回了这些发现”。
  这是后端原文，前端未改写；若产品不希望出现该表述，应由后端调整分享生成/降级模板。
- 当前账号的若干普通聊天历史存在 UPSTREAM_HTTP_403，另一些成功。属于后端模型上游失败，
  App 的身份鉴权及本次探索/定位请求成功。模型服务稳定性需后端继续排查。
- 失败聊天/探索的 retry 接口是否被其他进行中的探索一并限制，文档仍有歧义。
  本次未对后端强造 failed 任务；不据此新增产品限制。

## 真实模拟器验证

iPhone 17 Pro Max，保留已登录会话，通过应用实际操作验证：

| 步骤 | 结果 |
|---|---|
| GET me / home / interests | HTTP 200 |
| 选择“音乐”，PUT interests | HTTP 200 |
| POST explorations | HTTP 202 |
| SSE 完成事件 | 现有广场发现弹窗展示两条真实结果 |
| PUT acknowledgement | HTTP 200 |
| 回首页 | 两张实际卡片，无示例占位卡片 |
| 点击第二张“去看看” | locate HTTP 200，定位到后端汇总消息相应内容 |
| 聊天正文 | 只显示一次后端 assistantText，不重复追加 exploration.cards |

测试探索 taskId：`2b7651b1-8c5a-4289-86e4-e983f1f68fb9`（供后端定位联调记录）。
未记录 token、设备鉴权凭证或签名密钥。

## 自动验证与范围

`flutter test test/features/chat test/features/exploration test/features/plaza test/features/auth test/features/home`
共81项通过，覆盖原有界面、首次对话保留、结果定位、事件去重/确认失败、幂等重试和历史恢复。
静态分析使用 `flutter analyze lib test`，避免工作区其他任务导出的无资源源码副本干扰。

语音上传/ASR、系统APNs注册与推送点击、完整历史浏览UI仍不在本次接入范围。


## 语音输入后续接入

- 真实聊天页面已连接录音回调：POST attachments（multipart file）→ 轮询附件至 ready → POST messages（空 message、attachmentIds，保留卡片追问引用）。
- 附件 failed 不自动无限重试；用户再次点击发送时查询状态，必要时调用附件 retry。轮询最多120次，退出页面取消上传/轮询。
- 消息发送失败保留录音、附件 ID，沿用 ChatController 的 clientMessageId 防重；成功后清理本地音频。
- 纯附件消息显示“语音消息”，通过现有 SSE 接收 AI 文本回复。远程音频回放和 TTS 不在此实现内。
- 已补充模拟服务测试；真实 COS/ASR 可用性与真机录音效果尚未联调验收。
