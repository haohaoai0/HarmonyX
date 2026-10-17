# 奶蛙正面备用图标

采用用户选定的原图 `exec-afdf24ca-5ece-4376-ab52-bfb996f7a274.png`，保留正面、黄色皮肤、绿色眼圈、黑色瞳孔及原图构图。头颈、肩部与浅色腹部上缘自然延伸至图标底边。黑白仅指背景颜色。

- `portrait-source.png`：用户选定的透明原图的完整副本。
- `foreground.png`：按原图完整画布缩放至 1024×1024 的透明前景，对应应用资源 `milk_frog_foreground.png`。
- `white.png` / `black.png`：1024×1024 白底、黑底预览，不预制圆角。
- `white-48.png` / `black-48.png`、96 px 版本：小尺寸检查。
- HarmonyOS 7.0 备用图标名：`milk_frog_white`、`milk_frog_black`。
- 双层资源复用已有不透明黑白背景，图标选择与定时设置保持兼容。
- 导出：在工程根目录运行 `./tools/Export-MilkFrogIcons.ps1`。

参考：[奶蛙博物馆中的三视图](https://works.cohub.live/w/157e937b-95da-4c17-add4-f916e37c3574/milk-frog-museum/1980bbadcb26/content/assets/archive-references/mature-official-front-side-back.webp)，采用中间正面朝向的角色作为生成参考。本地为 `reference.webp`，不随 HAP 打包。

制作方式：内置 ImageGen 生成；用户指定采用此图后，仅作整图尺寸导出和背景合成。用户选定的图没有采用后续的放大构图稿。

用户选定原图的生成提示词：

> Create a production app-icon portrait foreground of 奶蛙 / milk frog using ONLY THE MIDDLE CHARACTER of the supplied three-view reference sheet as the character identity and orientation. The middle character is visually the STRAIGHT FRONT VIEW (ignore any inaccurate small caption beneath it). Strictly straight-on, upright, centered, bilateral symmetry, camera level. Both eyes equally large, at EXACTLY THE SAME HEIGHT, looking directly at viewer; equal visible sides of head; center of forehead, mouth, and chest all aligned on the vertical canvas centerline. ZERO leaning, ZERO diagonal pose, ZERO three-quarter turn, ZERO profile. Preserve saturated golden YELLOW skin, light GREEN circular eye surrounds and black circular pupils, subtle thin horizontal small smile from the reference, smooth softly modeled clay material. No white eyeballs. A natural close-up: large head and connected upper chest/shoulders, the yellow sides widen gently downward and CONTINUE THROUGH THE BOTTOM EDGE OF THE CANVAS. Show the head rising naturally from below the icon rather than an isolated round head. No chin-shaped cutout, no bottom transparent gap, no detached head. Square transparent foreground, requested 1024x1024. Head crown at around y=120, head width about 600px, eye centers approximately x=360 and x=664 at y=370, mouth centered near y=510. Connected yellow neck/upper shoulders continue from lower face to bottom y=1024, shoulders cut off by bottom canvas edge; no belly patch, no hands, no arms, no full body. Empty transparent space above and to the sides. Keep the simple slightly awkward character identity of the CENTER FIGURE faithfully. Gentle overhead light with soft orange shadows. No text or captions from the sheet, no background tile, no frame, no rounded corners, no watermark, no scene, no floor shadow.

以用户选定图像为最终交付依据。

验证（2026-10-16）：

- 原图副本 SHA-256：`EFC1DE0B0AF03FC0D09C9A38B515FCFFBA67A5500B830FD19DF67259F84AE75A`，与用户选择的文件一致。
- 导出前景与黑白预览均为 1024×1024；黑白预览全不透明，前景保留 alpha，底边中央 alpha 为 253，无透明间隙。
- 左右绿色眼圈的平均纵坐标约为 373.32 / 373.38 px，保持端正水平。
- `devecocli build --modules entry` 成功。
- 已检查签名 HAP：两份预览像素与导出文件完全一致；资源编译器将分层前景优化为 512×512，绿色眼圈位置及选定构图保持一致。
- 未验证设备桌面上的实际图标切换效果。
