# 聊天详情

设计源：Figma `Ee34W01RdusrU2afb7rvhP`，欢迎 `305:3700`、对话 `305:3931`、录音 `305:4176`。

首页右下角「聊天」进入全屏聊天；旁边麦克风进入后开始真实录音。页面复用现有 ExperienceController 文本模拟回复和本机进度；不加入引导页列表。「跳过」返回首页，「先去探索世界」进入广场。

## 素材与布局

`assets/chat/` 全部为本次 Figma 图层素材，文字和交互为 Flutter 控件，没有把整张设计截图作为页面。

| 素材 | 用途与 375×812 设计尺寸 |
| --- | --- |
| background.png | 背景图 cover 铺满，77% 不透明度，上下渐变遮罩 |
| avatar.png | 顶部头像，28×28 |
| greeting_fill / greeting_border / greeting_corner / greeting_star | 343×79 欢迎气泡、内边框与角标；长文字可增高 |
| incoming / incoming_long | 269×78 / 269×96 收到的文字气泡 |
| outgoing / outgoing_long | 94×38 / 269×57 发出的文字气泡，按实际文字自适应 |
| banner_background.svg | 原始 237×40 透明遮罩条带，左移 49px 裁为 188×40，右侧缺口透出场景 |
| banner_star_3 / banner_star_5 / banner_star_10 / banner_ring / banner_chevrons | 条带原有星星、环与箭头 |
| mic / clear | 输入条麦克风和有文字时的清空图标 |
| record_cancel / waveform / send_background + send_arrow | 36px 取消、44×25 音量区域、50px 完成录音按钮 |

正文使用系统 PingFang SC（其他平台由系统回退），录音计时使用随包提供的 Newsreader（OFL）。系统状态栏和手势条由系统绘制。键盘弹出与窄屏会收缩消息区域，空间不足时隐藏探索条带。

文字输入后出现清空按钮，清空后保持键盘焦点；文字通过键盘发送键提交。发送箭头仅用于录音完成，使用节点 `305:4497` 的透明 SVG 原始图层。

## 录音边界

- 点击才申请麦克风权限；iOS、Android、macOS 权限声明已配置。
- 原生端录制 AAC 单声道，本机应用目录保存；保存成功后消息元数据持久化，可点击气泡回放。
- Web 使用 WAV blob，仅当前聊天页有效，离开后释放，不写入永久进度。
- 最长两分钟；少于 500ms 不保存。音量图随采集电平变化。
- 取消、后台切换和页面退出释放麦克风及未保存音频；保存失败保留当前录音供重试。
- 未接语音上传、转写或 AI 语音回复；语音气泡明确标注「仅本机」。文字继续使用原有本地模拟接口。

预览入口：`/chat-preview`、`/chat-conversation-preview`、`/chat-recording-preview`。录音预览只展示状态，不自动采集音频。

验证覆盖：三种设计状态、窄屏/横屏/键盘、文字失败重试、权限拒绝、录音取消、保存重试、回放、录音启动和结束中的退出竞争、本机消息顺序与持久化。真实设备的麦克风收音和系统权限弹窗仍需设备验收。
