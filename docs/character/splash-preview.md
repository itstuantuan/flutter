# 启动页预览

入口：流程验证页右上角调色盘按钮；网页路由 `/splash-preview`。

原生 Flutter 分层实现渐变标题、网点、斜彩带入场、角色整体呼吸摇摆和星光闪烁。右下角可重播。尊重系统减少动画设置。不伪造系统状态栏；手机使用实际系统状态栏。网页保持参考图的纵向比例。

`assets/characters/viitor_splash.png` 是内置 imagegen 依据截图提取重绘的临时透明素材，并非无损抠图；猫形标志暂用对话图标代替。正式设计资产到位后替换。

生成提示词：
> Extract the foreground full-body purple-haired chibi girl from this reference into a single transparent PNG cutout. Preserve the leaning pose, both large purple eyes, smile, navy school blazer and skirt, purple tie, long lavender hair, white socks, black shoes and small doll held in her hand. Her other arm stays behind her back, NOT waving. Reconstruct only portions hidden by diagonal ribbon, including legs and shoes. Remove ALL background, ribbons, text, logos, shadow and UI. Entire body uncropped, centered with minimal padding on genuine alpha transparency. Match original illustration faithfully.
