# 角色待机预览

入口：流程验证页右上角星光按钮，或网页路由 /character-preview。

启动：`flutter run -d chrome --route /character-preview`

素材：`assets/characters/viitor_idle.png`，由内置 imagegen 从用户参考图提取并重绘为透明角色，非精确无损抠图。正式 UI 素材到位后替换此文件即可。

生成提示词：
> Use case: background-extraction. Input image: edit target, four mobile screens. Extract ONLY the large purple-haired chibi girl from the THIRD screen (home), full body including shoes and raised waving hand and the small doll she holds. Preserve exactly her face, purple hair, navy uniform, purple tie, pose and illustration style. Remove all UI, background, text, floor, other characters. A single centered character cutout on genuine transparent background, modest padding, full body uncropped. Asset for Flutter idle animation. Do not add a shadow or redesign the character.

实现：4 秒循环，最多 3 像素上浮、0.008 弧度摇摆、1.2% 纵向缩放；以脚底为变换基准。可暂停和调整幅度，响应系统减少动画设置。通过 AnimatedBuilder 缓存图片子树，控制器随页面销毁。当前未制作独立眨眼、头发或手臂动画。
