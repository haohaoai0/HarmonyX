# 红眼僵尸 X 备用图标设计

使用内置 image_gen，参考用户提供的荧绿黏液字体与红眼僵尸头像生成。X 为主体，红眼僵尸从右上角啃咬；保留黏液滴落、深绿厚边、浅绿顶部高光。角色与字形为同一前景，深色底板独立导出。

- `source.png`：生成原图，保留原始像素与透明度。
- `foreground.png`：1024 × 1024 透明前景。
- `background.png`：1024 × 1024 全不透明深色背景，上浅下深。
- `preview.png`：1024 × 1024 合成图，无预制圆角。
- `preview-48.png`、`preview-96.png`、`preview-192.png`：小尺寸视觉检查。
- `prompt.txt`：完整生成提示词。
- `verification.json`：尺寸、透明度、前景边界与原图校验值。

导出：`powershell -NoProfile -File tools/Export-ZombieXIcon.ps1`。有本地 `source.png` 时可直接重新导出。

已以 `zombie_x` 注册到应用备用图标列表，名称为“红眼僵尸 X”，同时支持手动选择和定时切换。前景、背景及完整预览放在 `AppScope/resources/base/media`。X-new 与 Croak-X 工作区均已接入；系统桌面切换效果需单独验证。
