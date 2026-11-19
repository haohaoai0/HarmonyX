# Harmony X 更新记录

以下保留各版本原有更新说明。日期为原仓库记录的发布时间，迁移后的 GitHub Release 页面时间会不同。

## Harmony X 4.2.5 · 2026-11-18

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v4.2.5)

构建号 / Build 46

## 中文更新日志

汇总自 GitHub 上一版 4.2.1 以来的改动。

### 首页时间线

- 在「设置 → 默认时间线 → 帖子滑动手势」中，可分别为向左、向右滑动指定回复、点赞、转帖、书签、分享或「不感兴趣」。滑动时会显示对应的操作图标。
- 启用任一方向的帖子手势后，可点按顶部标签切换时间线。

### 视频播放

- 新增「记住播放倍速」，默认开启。在视频查看器里手动选择倍速后，本次应用运行期间切换视频会沿用该倍速。关闭后，切换视频会恢复到 1×。
- 长按临时加速不会覆盖已记住的播放倍速。设置位于「图片与视频 → 视频画面与操作」。

### 发帖、回复与外观

- 普通账号发帖和回复时按 X 的加权规则计算 280 字符上限。超限时会提示并保留可编辑的内容，支持长帖的账号仍可发布长帖。
- 当帖子作者已屏蔽当前账号时，点赞、转帖等操作会显示明确提示。
- 新增「棕榈日落」备用应用图标，可在「设置 → 外观 → 应用图标」中切换。

## English changelog

This covers changes since 4.2.1, the previous GitHub release.

### Home timeline

- Assign a different action to each swipe direction under **Settings → Default timeline → Post swipe gestures**. Choose Reply, Like, Repost, Bookmark, Share, or Not interested. An icon previews the action as you swipe.
- When either swipe action is enabled, tap the tabs at the top to switch timelines.

### Video playback

- **Remember playback speed** is on by default. The video viewer keeps your last manually selected speed when you switch videos in the same app session. Turn the option off to start each new video at 1×.
- Pressing and holding to speed up temporarily preserves your saved speed. Find the option under **Photos and videos** in Settings.

### Posting, replies, and appearance

- Standard posts and replies use X’s weighted 280-character limit. If you go over the limit, the composer shows a message and keeps your text editable. Eligible accounts can still publish longer posts.
- Actions such as liking or reposting now show a clear message when the author has blocked your account.
- **Palm Sunset** is available under **Settings → Appearance → App icon**.

## 下载 / Downloads

- [未签名 App Pack / Unsigned App Pack](https://github.com/haohaoai0/HarmonyX/releases/download/v4.2.5/HarmonyX-v4.2.5-unsigned.app.zip)
- [未签名 HAP / Unsigned HAP](https://github.com/haohaoai0/HarmonyX/releases/download/v4.2.5/HarmonyX-v4.2.5-unsigned.hap)

App Pack 与原始 `.app` 文件内容相同，使用时可将文件名末尾的 `.zip` 去掉。HAP 须使用自己的 HarmonyOS 证书和 Profile 签名后安装。

The App Pack is the original `.app` file. Remove the final `.zip` suffix to use it as an App Pack. Sign the HAP with your own HarmonyOS certificate and profile before installing it.

### SHA-256

```text
2753ca387e7bb4927bf5284170d0596ad81ab30abcf1581e0dbf458d431035fb  HarmonyX-v4.2.5-unsigned.app.zip
71a39f0cbf2fac7750f57ac0a7d4609f16fa843366a17b146fec234e45b93bda  HarmonyX-v4.2.5-unsigned.hap
```


## Harmony X 4.2.1 · 2026-11-16

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v4.2.1)

# Harmony X 4.2.1

2026-11-17 · versionCode 44

## 中文更新日志

构建号为 44。本版改进视频浏览、播放控制和状态栏显示。

### 视频播放与查看

- 视频查看器支持双指缩放和拖动查看画面；缩放操作期间暂停切换视频，避免手势冲突。
- 改进播放位置同步和进度拖动处理，减少播放位置被旧进度覆盖；视频流控制按钮适配卡片尺寸与底部安全区。

### 页面显示与应用图标

- 帖子详情和视频查看器根据页面背景调整状态栏文字颜色，提升阅读对比度。
- 修正备用应用图标在标题栏中的前景图选择，并改进浅色和深色外观下的图标适配。

### 构建说明

- 全量 Node.js 测试 2195 项全部通过，0 失败；devecocli Release 构建成功。
- App Pack 与 HAP 版本均为 4.2.1（versionCode 44），兼容 API 22、目标 API 26。App Pack 内模块与单独提供的未签名 HAP 一致，打包元数据差异：pack.info。
- 发布包均未签名；安装前须使用自己的 HarmonyOS 证书和 Profile 重新签名。本轮未执行目标设备安装与交互验收。

## English changelog

Build number 44. This release improves video viewing, playback controls, and status bar contrast.

### Video playback and viewing

- Pinch to zoom and drag to pan in the video viewer. Video swiping pauses during these gestures to prevent accidental navigation.
- Improve playback-position synchronization and seek handling to prevent stale progress from overriding the current position. Video feed controls adapt to card size and the bottom safe area.

### Page display and app icons

- Post details and the video viewer adjust status bar text color to match the page background for better contrast.
- Correct the title bar foreground used by alternate app icons and improve icon adaptation in light and dark appearance modes.

### Build notes

- All 2195 tests in the complete Node.js suite passed with 0 failures. The devecocli Release build completed successfully.
- App Pack and HAP metadata both report 4.2.1 (versionCode 44), compatible API 22 and target API 26. The App Pack module matches the separately provided unsigned HAP; packaging metadata difference: pack.info.
- Both downloads are unsigned. Re-sign with your own HarmonyOS certificate and Profile before installation. Installation and interaction acceptance on target devices were not performed in this release run.

## 下载与安装 / Downloads and installation

- HarmonyX-v4.2.1-unsigned.app.zip：未签名 App Pack，与构建生成的 .app 内容一致。Unsigned App Pack, identical to the generated .app file.
- HarmonyX-v4.2.1-unsigned.hap：从该 App Pack 提取的未签名模块包。Unsigned module extracted from the App Pack.

安装前请使用自己的 HarmonyOS 证书与 Profile 重新签名，可通过 DevEco Studio 或 hap-sign-tool 完成。
Re-sign with your own HarmonyOS certificate and Profile using DevEco Studio or hap-sign-tool before installing.

## SHA-256

43e2bd34424653f4997ccdd8dda9f9cee95083928d5c23301f1d18356fabe48e  HarmonyX-v4.2.1-unsigned.app.zip
9eded934b1d2de61e9660f825346e145e091e462dea617083ed5f7bece76012a  HarmonyX-v4.2.1-unsigned.hap


## Harmony X 4.2.0 · 2026-11-15

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v4.2.0)

# Harmony X 4.2.0

2026-11-15 · versionCode 43

## 中文更新日志

本版汇总自 GitHub 上一版 4.0.0 以来的用户可见变化，包括 4.0.2 的新增功能。构建号为 43。

### 手表、智慧屏与折叠屏

- 手表新增专用首页，可用触摸和表冠浏览推荐、关注、搜索、书签、通知、私信和帖子详情。可发帖、回复、浏览图片、播放视频和进入 Spaces。圆屏帖子卡片采用贴合屏幕的圆角布局。手表未设置外观时默认使用深色。
- 智慧屏可用遥控器浏览时间线、搜索、通知和帖子详情，并用方向键选择内容、确认和返回。关闭详情或媒体后，焦点回到先前选中的位置。首页和详情提供“完整功能”入口。
- X 登录网页加载失败会给出提示并提供重试，智慧屏可用遥控器确认重试。
- 折叠屏展开、窗口尺寸或显示密度变化时会重新布局时间线并更新安全区。

### 发帖与图片编辑

- 发帖和回复编辑器可在同一个图库选择器里选取图片和视频。每条帖子最多可附带 20 个媒体文件，其中最多 1 个 GIF。编辑器支持预览附件和播放待发视频，草稿会恢复已选媒体及其图片说明。
- 可为每张图片和 GIF 单独添加供屏幕阅读器使用的图片说明（ALT）。裁剪后保留原说明，图片说明提交失败时保留草稿。
- 图片编辑新增自由裁剪、3:4 和 9:16 比例、橡皮擦、马赛克、亮度／对比度／饱和度调节与图片贴纸。多张图可连续编辑并拼成横排、竖排或网格，也可把裁剪区域切成多张竖条并按顺序放回编辑器。

### 媒体查看、剪辑与分享

- 视频流的“剪辑视频”可为符合条件的单视频帖子选择起点及长度，预览后通过已授权的 X 账号将片段发布为新帖，并可附上文案。
- 图片查看器新增可拖动的缩略图条，主图与选中的缩略图同步，支持点按和鼠标滚轮切换。媒体详情会保留当前帖子的整组图片及原先选中的附件。
- 视频封面、暂停按钮及进度条按实际播放画面宽度布置，改善竖屏视频的控制区。划过列表时会延后自动播放和预加载，回到原卡片时保留播放位置。
- 新的帖子分享面板支持搜索私信会话、附留言、复制链接和调用系统分享。设备上有可用应用时也会显示 Telegram 或邮件快捷方式。系统分享到 Harmony X 时，可按原顺序导入多张媒体。
- 可从帖子菜单复制正文、在 X 中打开或生成当前帖子的长图。分享面板的“截图”可把回复链和图片排版成一张图，支持复制到剪贴板。

### 帖子布局与个性化

- 新增紧凑帖子卡片，将用户名和时间并排显示。帖子详情新增独立的原有／紧凑样式设置，回复列表跟随详情样式，卡片和详情样式各自保存。
- 打开一条回复时，详情会补齐原帖到该回复之间的上下文，并把所选回复定位到标题栏下方。详情保留精确到分钟的本地时间，时间线相对时间会随时间推进，浏览量刷新也会同步到对应帖子卡片。
- 编辑个人资料时，可预览未保存的头像、封面、名称和简介。个人主页的悬浮回复按钮可单独关闭，侧边栏可添加“下载与存储”入口。
- 新增 12 款备用应用图标，包括 Silver Circuit、Moon、Mars、Brushed Silver、Graphite、Prism Nebula、Purple Nebula、Light Leak、Chrome、Green Circuit、Hologram 和 Ice Orb。标题栏可使用所选图标，X 标志可随主题自动切换黑白。
- X 图标样式新增首次点赞、普通点赞与下拉刷新动效，并遵循减少动态效果设置。

### 私信、表情和 Spaces

- 支持从 X 私信发起一对一原生语音及视频通话，本版本暂无法接听来电。通话中支持静音、开关视频和切换摄像头，并改善了对端挂断的状态提示。音视频通话和增强通话隐私开关会按服务端确认结果更新。
- 更新 XChat，改进多媒体私信、动图和相册的附件解密与显示，修复部分消息回应和编辑事件的同步。
- 表情面板采用九类表情数据，支持分类跳转、长按选择肤色和其他变体，并按账号记住选择。搜索覆盖全部 3,944 个 Unicode 17 表情并保留最近使用。
- Spaces 新增可选提示音，在成功加入直播或主动离开时播放。

### 文章阅读与稳定性

- 帖子外链菜单新增“阅读文章”，可提取正文，在原生阅读页调整字号、恢复阅读进度和打开离线副本。网页加载失败可以重试，正文提取失败时可继续查看原网页。
- 改善首页列表返回定位与分页去重，修复图片缩略图显示失败后无法恢复的问题。媒体请求会跟随当前可见内容，减少切换标签或滚动离开后继续加载。

### 构建与验证

- DevEco CLI Release 构建成功，2,195 项自动化回归测试全部通过。已核对 App Pack 和 HAP 的版本、设备声明及 API 级别，最低兼容 API 22，目标 API 26。
- 本次提供未签名 App Pack 和 HAP，两份包内的模块一致。安装前需使用自己的 HarmonyOS 证书和 Profile 签名。

## English changelog

This release covers user-facing changes since the previous GitHub release, 4.0.0, including changes from 4.0.2. The build number is 43.

### Watches, smart TVs, and foldables

- The watch home supports touch and crown navigation for For You, Following, search, bookmarks, notifications, direct messages, and post details. You can post, reply, view photos, play videos, and open Spaces. Cards fit round screens, and dark mode is the default when no appearance preference is saved.
- Browse timelines, search, notifications, and post details using the smart TV remote. Focus returns to the prior selection after you exit a thread or media viewer. The full interface is accessible from the TV home and post details.
- The X sign-in page shows a retry action when it fails to load. You can confirm the retry with the TV remote.
- Timelines reflow and safe areas update when a foldable opens or when window dimensions or display density change.

### Composing and photo editing

- The post and reply composer uses one gallery picker for photos and videos. Attach up to 20 media files per post, with at most one GIF. Preview attachments and play selected videos in the composer. Drafts restore selected media and their image descriptions.
- Add alt text for screen readers to each photo or GIF. Cropping preserves the description, and a failed description upload leaves the draft available.
- The photo editor adds freeform cropping, 3:4 and 9:16 ratios, an eraser, mosaic, brightness, contrast and saturation adjustments, and photo stickers. Edit multiple photos in sequence, arrange them in rows, columns, or a grid, or split a crop into vertical strips and return them to the composer in order.

### Media viewing, video clips, and sharing

- Clip an eligible single-video post from the video feed. Choose the start and length, preview the clip, and publish it as a new post with optional text using an authorized X account.
- The photo viewer adds a draggable thumbnail strip synchronized with the main photo, with tap and mouse-wheel navigation. Opening an attachment from media details retains the full post gallery and the selected item.
- Video covers, pause buttons, and seek bars follow the displayed video width, improving controls for portrait videos. Scrolling defers autoplay and preloading while preserving the playback position when you return to a card.
- The redesigned post share sheet supports direct-message search, a message to the recipient, link copying, and system sharing. Telegram and email shortcuts appear when a compatible app is available. Incoming system shares can import multiple media items in the original order.
- The post menu can copy the body, open the post in X, or export a long image of the selected post. The share sheet can capture a screenshot with reply context and photos and copy it to the clipboard.

### Post layouts and personalization

- Compact cards place the username and timestamp side by side. Choose classic or compact post details independently of the timeline card layout. Replies follow the detail layout, and both preferences are saved.
- Opening a reply loads the context back to the original post and positions the selected reply below the title bar. Details show local time to the minute, relative timestamps keep updating in timelines, and refreshed view counts reach matching cards.
- Preview unsaved changes to your avatar, banner, name, and bio. You can independently hide the profile's floating reply button and add a Downloads and storage shortcut to the sidebar.
- The new alternate icons are Silver Circuit, Moon, Mars, Brushed Silver, Graphite, Prism Nebula, Purple Nebula, Light Leak, Chrome, Green Circuit, Hologram, and Ice Orb. The title bar can show the selected icon, and the X mark can switch between black and white with the theme.
- X-style symbols add first-like, regular like, and pull-to-refresh animations that follow the reduced-motion setting.

### Direct messages, emoji, and Spaces

- You can start native one-to-one voice and video calls from X direct messages. You cannot answer incoming calls in this release. During a call, you can mute the microphone, turn video on or off, and switch cameras. Call status better reflects when the other person hangs up. The call and enhanced call privacy switches reflect the settings confirmed by X.
- The XChat update improves attachment decryption and display for media messages, GIFs, and albums and fixes syncing for some reactions and edits.
- The emoji picker has nine categories, category navigation, long-press skin tones and other variants, and per-account variant preferences. Search covers all 3,944 Unicode 17 emoji and retains recents.
- Spaces can play optional sounds when you successfully join or choose to leave a live room.

### Article reading and stability

- The Read article action extracts text from an external post link into the native reader. It supports text sizing, reading position, and offline copies. Failed page loads can be retried, and the original page remains available if extraction fails.
- Home better preserves scroll position and deduplicates paginated posts. Thumbnails can recover from load errors, and media loading follows visible content more closely when you switch tabs or scroll away.

### Build and verification

- The DevEco CLI Release build succeeded and all 2,195 automated regression tests passed. App Pack and HAP metadata were verified for version, device types, compatible API 22, and target API 26.
- The unsigned App Pack and HAP contain the same module. Sign with your own HarmonyOS certificate and Profile before installation.

## 下载与安装 / Downloads and installation

- **App Pack** · `HarmonyX-v4.2.0-unsigned.app.zip`。此文件与构建生成的 `.app` 内容一致。需要 `.app` 时，移除文件名末尾的 `.zip`。
- **HAP** · `HarmonyX-v4.2.0-unsigned.hap`。从该 App Pack 提取的未签名模块。

The App Pack download is the original `.app` with a `.zip` suffix. Remove the final `.zip` if your tool expects `.app`. The HAP is the unsigned module extracted from that App Pack.

## SHA-256

```text
77803ff65fa624249fb05f0ee684032b68339433d44731a5f91bfb9b83299604  HarmonyX-v4.2.0-unsigned.app.zip
556aa63da284080704e806bffb99ab44a513fdd1d7d2999e21eaa42228d87c69  HarmonyX-v4.2.0-unsigned.hap
```


## Harmony X 4.0.0 · 2026-11-12

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v4.0.0)

# Harmony X 4.0.0

2026-11-13 · versionCode 40

## 中文更新日志

本版新增宽版帖子布局、媒体显示比例、Chirp 字体、X 图标风格与自定义图片文件名，完善页面背景选色、视频查看和列表成员管理。构建版本为 40。

### 新增功能

- **经典与宽版帖子布局**：可在布局设置中选择经典或宽版卡片。宽版将头像和作者信息放在顶部，让正文、图片、视频与操作栏使用卡片的完整内容宽度；切换立即生效并保存在本机，已有用户默认沿用经典布局。
- **图片和视频显示比例**：支持以 5% 为步长，在 50% 至 100% 之间调整帖子媒体大小，保持原始宽高比，并同步调整混合媒体、长图和视频预览的显示区域。
- **Chirp 字体与 X 图标风格**：内置 Chirp UI 字体及多种字重，缺失字符回退到系统字体；图标可在 HarmonyOS Symbol 与 X 风格之间切换，覆盖底栏、帖子操作和多个页面入口，并保留选择。
- **自定义图片文件名**：可按所选顺序组合发帖日期、作者用户名、图片序号、原始图片代码与帖子 ID，并预览文件名。单张保存、批量保存和下载记录使用一致的命名规则，保留原始扩展名与图片在完整帖子中的序号，自动跳过缺失信息并清理不安全字符。
- **页面背景选色**：在支持的设备上提供原生颜色选择器，可收藏常用颜色并在后续使用时恢复。

### 改进与修复

- **视频查看衔接**：轻点信息流中的视频可从当前播放位置进入独立查看器；封面尚未就绪或播放失败时仍能进入查看器。媒体预览保留所选视频及来源，GIF 继续支持在卡片内播放。
- **媒体与帖子排版**：优化宽版布局下的媒体宽度、横向图片溢出判断与线程连接线；缩小视频时同步调整预览和播放区域，保留可用的播控空间，并按实际显示区域识别双击快进、快退。
- **列表成员管理**：更新添加、移除列表成员的请求与结果确认，完整保留较长的列表和用户 ID；改善私密列表、成员归属、分页和失败重试，避免对结果不明的写入自动重复提交。
- **底栏外观偏好**：液态底栏指示器默认关闭，已有选择继续保留，并与标签和底栏样式分别保存。
- **设备兼容性**：眼动阅读入口先检查设备能力，不支持或检测失败时安全降级；完善字体恢复、主题图标和相关页面的外观一致性。
- **版本信息**：统一应用、中英文说明及全部 21 份本地化版本文案为 4.0.0（`versionCode` 40），最低兼容 API 22、目标 API 26。

### 构建说明

- 完整 Node.js 测试集共 2046 项全部通过，0 失败；`devecocli build --product default --build-mode release` 构建成功。
- 已核对 App Pack 与 HAP 内版本均为 4.0.0（`versionCode` 40），兼容 API 22、目标 API 26，HAP 为 Release 模式，App Pack 内模块与单独提供的未签名 HAP 完全一致。
- 发布包均未签名，安装前须使用自己的 HarmonyOS 证书和 Profile 重新签名；本轮未执行目标设备上的安装与交互验收。
- 本次仅发布安装包，源码修改保留在本地。

## English changelog

This release adds wide post cards, media sizing, the Chirp font, X-style icons, and custom image filenames, with improvements to background colors, video viewing, and List membership management. The build number is 40.

### New features

- **Classic and wide post cards**: Choose a layout in Layout settings. Wide cards place the avatar and author at the top, giving text, photos, videos, and actions the full content width. Changes apply immediately and persist locally; existing installations keep the classic layout by default.
- **Photo and video sizing**: Adjust post media from 50% to 100% in 5% steps while preserving its aspect ratio. Mixed-media strips, tall photos, and video previews follow the selected size.
- **Chirp font and X-style icons**: Built-in Chirp UI includes multiple font weights and falls back to the system font for missing characters. Switch between HarmonyOS Symbols and X-style icons across the bottom bar, post actions, and many page controls, with the choice preserved.
- **Custom image filenames**: Combine the post date, author username, image number, original image code, and post ID in your chosen order, with a filename preview. Single saves, batch saves, and download history share the naming rules, preserving original extensions and each photo's position in the complete post while skipping missing metadata and removing unsafe characters.
- **Background color picker**: Supported devices offer a native color picker with saved favorite colors.

### Improvements and fixes

- **Video viewing**: Tap a feed video to open the dedicated viewer at its current playback position, including when the inline cover is not ready or playback has failed. Media previews retain the selected video and its source, while GIFs can still play within the card.
- **Media and post layout**: Refine media widths, horizontal photo overflow, and thread connectors in wide cards. Scaled videos keep their previews and playback surfaces aligned, retain usable controls, and calculate double-tap seek regions from the visible frame.
- **List membership management**: Update add/remove member requests and success confirmation while preserving long List and user IDs. Improve private Lists, membership state, pagination, and retry handling without automatically repeating writes whose outcome is uncertain.
- **Bottom-bar appearance preferences**: The liquid bottom-bar indicator defaults to off, preserves existing choices, and is saved independently of labels and bar style.
- **Device compatibility**: Check device capabilities before exposing eye-controlled reading, with a safe fallback when unsupported or detection fails. Improve font restoration, themed icons, and visual consistency across related pages.
- **Version information**: App metadata, bilingual documentation, and all 21 localized version labels use 4.0.0 (`versionCode` 40), with compatible API 22 and target API 26.

### Build notes

- All 2046 tests in the complete Node.js suite passed with 0 failures. `devecocli build --product default --build-mode release` completed successfully.
- App Pack and HAP metadata both report 4.0.0 (`versionCode` 40), compatible API 22 and target API 26. The HAP uses Release mode, and the App Pack contains exactly the separately provided unsigned HAP.
- Both downloads are unsigned. Re-sign with your own HarmonyOS certificate and Profile before installation. Installation and interaction acceptance on target devices were not performed in this release run.
- This release publishes binaries only; source changes remain local.

## 下载与安装 / Downloads and installation

- `HarmonyX-v4.0.0-unsigned.app.zip`：未签名 App Pack，与原始 `.app` 内容一致。Unsigned App Pack, identical to the original `.app` file.
- `HarmonyX-v4.0.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。Unsigned module extracted from the App Pack.

安装前请使用自己的 HarmonyOS 证书与 Profile 重新签名，可通过 DevEco Studio 或 `hap-sign-tool` 完成。
Re-sign with your own HarmonyOS certificate and Profile using DevEco Studio or `hap-sign-tool` before installing.

## SHA-256

```text
41faeea35acc1957b4c88a513695193ce559cdd96b9c29454c7407a99195f01d  HarmonyX-v4.0.0-unsigned.app.zip
392870bca4cee5a7b81fb54bc55bfbd7143acedcaf2d400968ee66124caf8282  HarmonyX-v4.0.0-unsigned.hap
```


## Harmony X 3.9.0 · 2026-11-10

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.9.0)

## 3.9.0 — 2026-11-10

本版新增原生分段页签样式，统一单列帖子信息流的滚动与按压手势，并完善视频、评论预览、个人主页材质按钮和媒体阅读位置恢复。构建版本为 36。

### 新增功能

- **原生分段页签**：紧凑页签样式新增原生分段选项，可在首页、通知、探索和搜索结果等切换区域使用。分段控件采用固定的原生材质外框，页签内容可在框内横向滚动，并支持超过五个入口、较长标题、重复轻点打开选项以及 RTL 布局；普通轻点不会误触上一入口的选项菜单。

### 改进与修复

- **单列信息流手势**：书签、社区、列表时间线、通知帖子、全球趋势、引用与互动以及个人主页信息流在单列布局下统一使用原生 `List`，由列表接管按压、拖动和惯性滚动；显式双列、大屏和桌面布局继续使用 `WaterFlow`，嵌套页面的父子滚动交接保持原规则。
- **视频与评论预览**：改善内嵌视频的圆角裁切、播控高度和显示状态，轻点视频优先操作当前播放器；返回信息流时保留用户选择的暂停状态，已离开页面的迟到画中画回调不会重新拉起视频。视频评论预览修正紧凑控件与轻点响应区域，调整预览尺寸或收起预览时不再误触发页面暂停。
- **媒体与阅读位置恢复**：旋转、连续缩放窗口或在 `List` / `WaterFlow` 之间切换时，按帖子标识保留当前阅读帖和卡片内偏移，新帖子插入列表也不会跳回首页顶部；评论和混合媒体重新出现时继续恢复图片、视频及横向滑动位置。
- **个人主页材质按钮**：Grok、搜索、更多、通知、分享和编辑资料等主页操作在 API 26 上改为各自使用原生材质按钮宿主，保留按钮尺寸与位置，同时改善按压形变、光照和降级样式。
- **版本信息**：统一应用、中英文说明与全部 21 份本地化版本文案为 3.9.0（`versionCode` 36），最低兼容 API 22、目标 API 26。

### 构建说明

- 发布验证：完整 Node.js 测试集共 2023 项全部通过（0 失败）；`devecocli build --product default --build-mode release` 构建成功，签名工具确认 HAP 签名块、代码签名、原生库和权限签名有效。包内版本为 3.9.0（`versionCode` 36）。
- 本 Release 提供由本次源码生成并经签名校验的 HAP。安装可用性仍取决于目标设备、系统版本和本地调试签名 Profile，请以实际安装测试为准。
- 本轮发布以自动化回归为主；不同窗口宽度、设备折叠/旋转、真实视频播放、画中画和评论手势仍需在目标设备上完成视觉与交互验收。

---

### 发布产物

- 未签名 App Pack: HarmonyX-v3.9.0-unsigned.app.zip
- 大小: 71444555 字节
- SHA-256: DCA63571DF8ADAB73FE8F85ED384EC6A2ECFB30E07E26AC5585BE9F2B000653B
- 签名 HAP: entry-default-signed.hap
- 大小: 108408803 字节
- SHA-256: 3F68442328D73ACA29888DF457DD6F4C88D77390C1D5278DFFBB81920B944438

GitHub 不允许直接上传 .app 扩展名，因此 App Pack 以 zip 提供。未签名包可使用自己的 HarmonyOS 证书和 Profile 重新签名。

> 安装可用性仍取决于目标设备、系统版本和本地调试签名 Profile。本轮以自动化回归为主，目标设备上的视觉与交互验收仍需单独完成。


## Harmony X 3.8.0 · 2026-10-31

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.8.0)

# Harmony X 3.8.0 (35)

本版新增本地关注分组，完善个性化话题时间线与 Grok 入口，提供更多媒体保存方式和异常退出后的日志恢复，并改善评论看图、信息流切换与页面背景性能。构建版本为 35。

### 新增功能

- **本地关注分组**：从已关注账户中选择成员，设置分组名称和表情图标，并可固定到首页。分组按当前登录账号保存在本机，汇总成员帖子并按时间排列，支持分页、去重及失败重试；编辑分组不会修改 X 列表或关注关系。
- **个性化话题时间线**：读取 X 为当前账号提供的话题分类，使用对应的个性化首页信息流，支持固定和取消固定。分类、固定状态及阅读缓存按账号隔离，改善重启后保留、分页重试和切换账号时的状态处理。
- **Grok 独立入口**：可从侧边栏直接进入 Grok 进行普通对话，沿用设置中的网页或 API 模式；从帖子进入时继续携带该帖上下文。
- **四种媒体保存方式**：可在数据与存储设置中选择直接保存到图库、通过系统安全保存按钮保存、保存到已授权目录，或每次另存为。目录选项按设备能力提供，取消或失败时保留可重试状态。
- **异常退出日志恢复**：发生 ArkTS 或原生崩溃后，下次启动提示导出诊断日志，并可打开开发者反馈草稿。日志限制留存数量，清理凭证和敏感请求内容，保存位置由用户选择；取消或导出失败不会清除待处理记录。

### 改进与修复

- **评论弹窗内看图**：在评论弹窗内复用图片查看器，返回后保留评论列表、滚动位置和回复草稿；再次打开图片沿用原有多图顺序，图片背景延伸至弹窗底部。
- **首页切换与刷新**：话题筛选合并更新，仅调整受影响的帖子行，减少切换时的重复过滤与列表重建；新帖子提示、分页游标和各时间线阅读位置保持独立。
- **页面背景性能**：页面和外观预览复用已合成的背景纹理，减少重复绘制；切换背景或离开页面时处理过期任务和纹理释放，编辑页继续提供实时预览。
- **帖子按压与搜索布局**：拖动或取消手势及时恢复帖子按压效果，避免影响滚动；搜索结果沿用首页的列表与分栏选择，保持一致的卡片布局。
- **翻译体验**：改善翻译入口的显示判断，保留诗歌缩进、空行及原始换行；缓存区分正文、目标语言和服务配置，避免切换设置后复用错误译文。
- **返回桌面提示**：开启返回提示时，根页面首次返回仅显示 Toast，再次返回桌面；侧边栏、嵌套页面及图片查看器优先处理自己的返回操作。
- **版本信息**：统一应用、中英文说明与全部 21 份本地化版本文案为 3.8.0（`versionCode` 35），最低兼容 API 22、目标 API 26。

### 构建说明

- 本版提供未签名 Release App Pack 与 HAP，安装前需使用自己的 HarmonyOS 证书与 Profile 重新签名。
- 本轮验证覆盖 2,002 项非全语言目录审计测试；初次发现的两处测试夹具不匹配已补齐，相关 18 项测试重跑全部通过。Release 编译通过，并核验包内版本、设备类型、未签名状态和 SHA-256；21 份语言资源键及格式参数一致，17 种语言各有 53 条既有长文案沿用英文回退。
- 本轮发布不包含新的完整真机交互验收；分组时间线、服务器话题固定、Grok、保存授权、崩溃恢复和媒体手势仍需结合目标设备与实际服务验证。

---

This release adds local account groups, improves personalized topic timelines and access to Grok, offers more media saving choices and crash-log recovery, and refines comment photos, feed switching, and page-background performance. The build number is 35.

### New features

- **Local account groups**: Select members from followed accounts, name each group, choose an emoji icon, and optionally pin it to Home. Groups stay on this device and are isolated by the signed-in account. Their feeds merge member posts in time order with pagination, deduplication, and retry support; editing a group preserves X lists and follow relationships.
- **Personalized topic timelines**: Load the topic categories provided by X for the current account and browse their personalized Home feeds, with pin and unpin actions. Categories, pins, and reading caches are account-specific, with improved restart persistence, pagination retries, and account-switch handling.
- **Direct access to Grok**: Open Grok from the sidebar for a general conversation using the configured web or API mode. Opening it from a post continues to include that post as context.
- **Four media saving choices**: In Data & storage, choose direct Gallery saving, the system secure save button, an authorized directory, or Save As for each download. Directory selection follows device capabilities, and cancellation or failure allows retry.
- **Crash-log recovery**: After an ArkTS or native crash, the next launch offers diagnostic-log export and a developer feedback draft. Reports have bounded retention, remove credentials and sensitive request content, and use a user-selected save location. Cancelled or failed exports retain pending reports.

### Improvements and fixes

- **Photos inside comment sheets**: Reuse the photo viewer within the comment sheet while keeping the comment list, scroll position, and reply draft mounted. Reopening retains album order, and the photo background reaches the sheet's bottom edge.
- **Home switching and refresh**: Batch topic-filter changes and update only affected post rows, reducing repeated filtering and list rebuilding. New-post notices, pagination cursors, and reading positions remain independent for each timeline.
- **Page-background performance**: Pages and appearance previews share composed background textures to reduce repeated drawing. Background changes and page exits handle obsolete tasks and texture lifetimes, while the editor retains live previews.
- **Post presses and search layout**: Dragging or cancelling restores post press feedback promptly so scrolling remains stable. Search results follow the same list or column preference as Home.
- **Translation**: Refine translation-action visibility and preserve poetry indentation, blank lines, and original line breaks. Caches distinguish content, target language, and provider settings to avoid stale translations after configuration changes.
- **Back-to-desktop hint**: When enabled, the first Back on a root page shows a toast and the second returns to the desktop. Sidebars, nested destinations, and photo viewers handle their own Back actions first.
- **Version information**: App metadata, bilingual documentation, and all 21 localized version labels use 3.8.0 (`versionCode` 35), with compatible API 22 and target API 26.

### Build notes

- This release provides unsigned Release App Pack and HAP files. Re-sign them with your own HarmonyOS certificate and Profile before installation.
- Verification covers 2,002 tests outside the complete locale-catalog audit. Two initial fixture mismatches were corrected, and all 18 tests in the affected files passed on rerun. Release compilation passed, with package version, device-type, unsigned-state, and SHA-256 checks. All 21 catalogs have matching resource keys and formatter arguments; 17 locales retain 53 existing long English fallback strings each.
- This publication does not include a new complete device interaction acceptance run. Group feeds, server topic pins, Grok, saving authorization, crash recovery, and media gestures still require validation with the target device and live services.

## Local build verification

- Branch: X-new; HEAD: be72e8a20507dbd436a0fc92ea7d94bed93912f0. Includes local working-tree changes.
- Version 3.8.0 (35), Release mode, com.haohaoai0.harmonx, compatible API 22, target API 26.
- Regression verification: 2002 tests verified outside the complete locale-catalog audit. The initial run passed 2000 tests and found 2 fixture mismatches; after updating those fixtures, all 18 tests in the two affected files passed.
- All 21 version labels, catalog keys, and formatter arguments match. 17 locales retain 53 existing long English fallback strings each.
- Standalone and App Pack embedded HAPs confirmed unsigned by hap-sign-tool: signature not found; No Hap Signing Block.
- All 4613 embedded HAP content entries match the unsigned module output; package metadata verified.
- Local signing configuration preserved. No new device interaction or visual acceptance run.

## SHA-256

```text
0f56fbab45de5f8e1e215ddd8f7ad0e5e99d0ec69d2581b0fff3f55748721a0f  HarmonyX-v3.8.0-unsigned.app.zip
56e03f90caa7e72ea8527e6109f08a56d2d729021b57776836397c8a358bf913  HarmonyX-v3.8.0-unsigned.hap
```


## Harmony X 3.7.0 · 2026-10-28

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.7.0)

# Harmony X 3.7.0 (32)

本版重点完善界面定制与视频交互：侧边栏和底栏可独立配置，主页入口与推荐关注可选择；页面背景可沿用预置图案的配套渐变，英文菜单会跟随应用语言；评论与帖子操作栏的性能和布局也得到改善。构建版本为 32。

### 新增功能

- **侧边栏与底栏定制**：可在设置中调整侧边栏项目顺序和显示状态；首页、探索和私信默认隐藏，支持、设置与帮助中心保留在底部分组。底栏可整体隐藏，侧边栏顶部提供默认关闭的可选搜索胶囊。
- **主页入口与推荐关注**：主页标题栏入口可在“搜索”和“添加关注”之间二选一并持久保存；推荐关注内容增加独立开关，关闭后不再插入信息流。
- **页面背景配套渐变**：选择完整页面图案时可同时使用聊天背景中的配套渐变，并根据整段渐变自动调整文字对比度；关闭“保留原始渐变”后可继续使用自定义底色、照片或纹理。
- **帖子计数与宽屏布局**：帖子操作栏的计数可切换为 K/M、万/亿或完整数字；宽屏信息流新增四列与五列选项。
- **外层视频长按选项**：帖子外层视频的长按行为可选择打开操作菜单或长按快进，倍速与取消手势沿用现有长按设置。
- **帖子视频播控选项**：可将播放控制移入视频画面，轻点显示或隐藏并在播放时自动收起；也可在退出视频查看器后保持帖子预览暂停，上述选项均默认关闭并持久保存。

### 改进与修复

- **评论性能**：新增、删除和展开子回复时只更新受影响的评论行，仅在真实排序变化时重载列表；“最多赞”排序改为稳定排序，相同赞数的回复保持原有顺序。
- **帖子操作栏**：按实际卡片宽度分配计数按钮，窄窗口优先收起低优先级入口，避免横向滚动、长计数截断和不同字号下的按钮重叠。
- **深色主页状态栏**：主页沉浸式标题栏根据页面背景明暗选择状态栏内容颜色，改善深色模式竖屏下状态栏图标对比度。
- **英文菜单本地化**：动态拼接和读取的帖子菜单、设置项与提示文案改为遵循应用内语言，不再残留中文；相关文案同步补齐 21 种语言资源。
- **画中画退出清理**：离开帖子、切换帖子或页面销毁时同步关闭画中画，迟到的创建、启动与恢复回调不会重新拉起已离开的视频，并释放保留的解码器。
- **视频返回状态**：从视频查看器返回信息流时保留用户主动暂停状态；画中画与全屏恢复仍复用原播放器，避免重复创建和错误续播。
- **版本信息**：统一应用、中英文说明与本地化版本文案为 3.7.0（`versionCode` 32），最低兼容 API 22、目标 API 26。

### 构建说明

- 本版提供未签名 Release App Pack 与 HAP，安装前需使用自己的 HarmonyOS 证书与 Profile 重新签名。
- 发布前 1,919 项非全语言目录审计测试通过，并执行 Release 编译和包内元数据、未签名状态及 SHA-256 核验。全语言完整性审计仍显示 18 种语言各有 53 条既有长文案沿用英文回退；这不影响本版动态菜单跟随应用语言，但翻译债仍需后续清理。本轮发布不包含重新安装及真机交互验收。
- 侧边栏与底栏切换、状态栏颜色、视频长按、画面内播控及画中画退出属于交互路径，仍需在目标设备上分别验收。

---

This release focuses on interface customization and video interaction: the sidebar and bottom bar can be configured independently, the Home header action and follow suggestions are selectable, page patterns can use their matching gradients, and dynamic menus follow the app language. Comment and post-action performance also improves. The build number is 32.

### New features

- **Sidebar and bottom-bar customization**: Reorder or hide sidebar entries in Settings. Home, Explore, and Messages start hidden, while Support, Settings, and Help remain in a footer group. The bottom bar can be hidden entirely, and an optional search capsule is available at the top of the sidebar, disabled by default.
- **Home header and follow suggestions**: Choose whether the Home title-bar action opens Search or Add Follow, with the choice persisted. Follow suggestions gain an independent switch, and disabling it removes them from the feed.
- **Matching page-background gradients**: Full page patterns can use the matching gradients from chat backgrounds, with foreground contrast calculated across the whole gradient. Turning off Keep original gradient retains custom colours, photos, and textures.
- **Post counts and wide-screen layouts**: Post counts can use K/M, 万/亿, or full numbers. Wide feeds gain four- and five-column options.
- **Inline video long-press options**: Choose whether holding a video in a post opens the action menu or starts temporary fast playback. Speed and cancellation behaviour follow the existing hold settings.
- **Inline video playback options**: Playback controls can move inside the video, appearing on tap and hiding automatically during playback. Post previews can also remain paused after closing the viewer. Both options start disabled and persist across restarts.

### Improvements and fixes

- **Comment performance**: Adding, removing, and expanding child replies now updates only the affected comment rows, reloading the list only for a real reorder. Most-liked ordering uses a stable sort, so replies with equal counts retain their original order.
- **Post action bar**: Counted actions share the actual card width, and narrow layouts drop lower-priority entries first. This removes horizontal scrolling, clipped long counts, and overlap at different text sizes.
- **Dark Home status bar**: The immersive Home title bar now chooses status-bar content colours from the page background luminance, improving icon contrast in dark portrait layouts.
- **English dynamic menus**: Post menus, settings items, and notices built from runtime strings now follow the app language instead of the host locale. All affected copy is synchronized across 21 locales.
- **Picture-in-picture cleanup**: Leaving or changing posts synchronously closes PiP. Late creation, start, and restore callbacks cannot revive a removed post, and retained decoders are released.
- **Video return state**: Returning from the video viewer preserves an intentional pause, while PiP and fullscreen restoration continue to reuse the existing player instead of creating a duplicate or resuming incorrectly.
- **Version information**: App metadata, bilingual documentation, and localized version labels use 3.7.0 (`versionCode` 32), with compatible API 22 and target API 26.

### Build notes

- This release provides unsigned Release App Pack and HAP files. Re-sign them with your own HarmonyOS certificate and Profile before installation.
- Release preparation passed 1,919 tests outside the complete locale-catalog audit, then ran Release compilation and package metadata, unsigned-state, and SHA-256 checks. The complete catalog audit still reports 53 pre-existing long strings falling back to English in each of 18 locales. This does not affect the new dynamic-menu application-language handling, but the translation debt remains. This publication does not include a new installation or device interaction acceptance run.
- Sidebar and bottom-bar switching, status-bar colours, video long press, inline controls, and PiP exit remain interaction paths that require separate target-device acceptance.

## Local build verification

- Branch: X-new; HEAD: be72e8a20507dbd436a0fc92ea7d94bed93912f0. Includes local working-tree changes.
- Version 3.7.0 (32), release mode, com.haohaoai0.harmonx, compatible API 22, target API 26.
- 1,919 tests outside the complete locale-catalog audit passed; App Pack and HAP metadata verified.
- Unsigned HAP confirmed with hap-sign-tool: signature not found; No Hap Signing Block.
- All 4613 embedded HAP content entries match the unsigned module output.
- The complete locale-catalog audit still reports 53 existing long English fallback strings in each of 18 locales.
- Device interaction and visual acceptance were not performed.

## SHA-256

```text
309c45f39d1d3ce67fad9a24adb7b95a0866aa877859d08834a0abc9ba796ca0  HarmonyX-v3.7.0-unsigned.app.zip
1b59672b54af11a89843a1d11f8c2891b7782ad5dece91a9f2c0e6196b6ae530  HarmonyX-v3.7.0-unsigned.hap
```


## Harmony X 3.6.0 · 2026-10-26

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.6.0)

# Harmony X 3.6.0 (30)

本版新增可选的 DNS over HTTPS 网络配置，改善长评论区的加载与阅读体验，并优化原生材质控件、媒体显示和浏览记录稳定性。构建版本为 30。

### 新增功能

- **DNS over HTTPS（DoH）**：在“设置 → 数据与网络”中选择服务商或填写 HTTPS 解析地址，测试后保存；内置阿里 DNS、Cloudflare 和 Google，提供 DNS 解析与 X 连接测试。默认关闭，设置会在重启后保留；社区实例由用户自行填写，已有自定义地址继续保留。
- **DoH 媒体连接**：开启 DoH 并使用应用直连时，帖子、图片、头像、GIF、翻译和媒体下载共用所选解析配置；HTTPS 连接支持读取服务返回的 ECH 配置。视频分段和 HLS 清单也接入相同请求路径，保留应用代理的独立配置。

### 改进与修复

- **评论区性能与阅读状态**：帖子详情改为按需创建评论，加载下一页时保留已有卡片，减少长评论区的重复计算。滚动离开再返回时保留正文展开、译文切换、低质量回复展开及媒体横滑位置；优化深层回复的排序与连接线处理。
- **原生材质交互**：图片、视频查看器等操作按钮接入受支持系统的原生材质变形与光照反馈，统一导航、搜索、回复和媒体控制区的材质处理；旧系统继续使用兼容样式。
- **浏览历史删除**：修复删除、清空或筛选历史记录时，旧列表索引仍触发日期分组更新而导致的崩溃；取消清空或保存失败时保留原记录。
- **视频评论加载**：改善首批评论为空、连续空页和分页失败时的继续加载与重试；保留接口确认的会话回复，避免将推荐内容当作评论，图片和视频的内嵌评论区不再插入推荐帖。
- **GIF 与媒体返回**：改善 GIF 动画、静态缩略图和首帧之间的回退，避免加载失败后出现空白；重新进入媒体时处理失效缓存，并保留混合媒体横滑位置。
- **翻译切换**：已取得的译文可与原文来回切换，减少重复请求；评论复用时根据账号、语言和翻译设置校验保存状态。
- **云端设置同步**：改善本地修改与云端时间差的冲突处理、失败上传重试和清空云端设置；导入其他用户导出的有效配置时仍保留本机登录凭证。
- **版本信息**：统一应用、中英文说明与本地化版本文案为 3.6.0（`versionCode` 30），最低兼容 API 22、目标 API 26。

### 构建说明

- 本版提供未签名 Release App Pack 与 HAP，安装前需使用自己的 HarmonyOS 证书与 Profile 重新签名。
- 发布前执行相关专项测试、Release 编译和包内元数据、未签名状态及 SHA-256 核验，具体结果见 Release 构建记录。本轮发布不包含重新安装及真机交互验收。
- DoH 的连接效果取决于所选服务与当前网络；系统网页登录及独立原生聊天路径仍需分别验证，已打开的内置网页在修改配置后需重新加载。

---

This release adds optional DNS over HTTPS configuration, improves loading and reading in long comment threads, and refines native material controls, media display, and browsing-history stability. The build number is 30.

### New features

- **DNS over HTTPS (DoH)**: Select a provider or enter an HTTPS resolver in Settings → Data & network, test it, and save. Includes AliDNS, Cloudflare, and Google presets, DNS response testing, and an X connection test. DoH starts disabled and its settings survive restarts. Community instances can be entered manually, and existing custom addresses are retained.
- **DoH media connections**: With DoH enabled and app connections set to direct, posts, images, avatars, GIFs, translations, and media downloads share the selected resolver. HTTPS connections can use ECH configuration returned by the service. Video segments and HLS playlists use the same request path, while app proxy settings retain their separate behavior.

### Improvements and fixes

- **Comment performance and reading state**: Post details create comment cards on demand and retain existing cards when another page loads, reducing repeated work in long threads. Returning to a recycled comment preserves expanded text, translation selection, low-quality reply expansion, and horizontal media position. Deep reply ordering and connector handling are also improved.
- **Native material interaction**: Photo and video viewer buttons use native material deformation and lighting on supported systems. Navigation, search, reply, and media controls share consistent material handling, with compatible styling on older systems.
- **Browsing-history deletion**: Fixed a crash when deleting, clearing, or filtering history left old list indexes updating date headings. Cancelling a clear or failing to save retains the original records.
- **Video comments**: Improved continuation and retry after empty first pages, consecutive empty pages, and paging failures. Replies confirmed by conversation modules are retained, recommendations are excluded from comment results, and embedded photo and video comments no longer insert recommendation posts.
- **GIFs and media return**: Improved fallback between animations, static thumbnails, and decoded first frames to avoid blank failed previews. Reopening media handles expired cache files and preserves horizontal position in mixed-media strips.
- **Translation switching**: Switch between an available translation and the original without repeating the request. Recycled comments validate saved state against the account, language, and translation preferences.
- **Cloud settings**: Improved conflict handling between local edits and remote clock differences, failed-upload retries, and clearing cloud settings. Importing a valid settings file exported by another user retains local sign-in credentials.
- **Version information**: App metadata, bilingual documentation, and localized version labels use 3.6.0 (`versionCode` 30), with compatible API 22 and target API 26.

### Build notes

- This release provides unsigned Release App Pack and HAP files. Re-sign them with your own HarmonyOS certificate and Profile before installation.
- Release preparation runs related focused tests, Release compilation, and package metadata, unsigned-state, and SHA-256 checks. Exact results accompany the release build record. This publication does not include a new installation or device interaction acceptance run.
- DoH connectivity depends on the selected service and current network. System web sign-in and the separate native chat path require their own verification. Reload open embedded web pages after changing the configuration.

## Local build verification

- Branch: X-new; HEAD: be72e8a20507dbd436a0fc92ea7d94bed93912f0. Includes local working-tree changes.
- Version 3.6.0 (30), release mode, com.haohaoai0.harmonx, compatible API 22, target API 26.
- 660 focused tests passed; App Pack and HAP metadata verified. Unsigned HAP confirmed with hap-sign-tool.
- 5 native transport tests passed. The community preset is absent from compiled code and resources; custom DoH and ECH remain supported.
- All 4613 HAP content entries match the module output; PackageApp regenerates pack.info.
- Device interaction and visual acceptance were not performed.

## SHA-256

```text
e4774c9dfe31b22684d081ed5b157fce0f9f08d565164b61ef098715f10a728c  HarmonyX-v3.6.0-unsigned.app.zip
f16e2fa6b90e65dd1dd4de6eb0039952bc943bc0560658cab41a22bd805eec11  HarmonyX-v3.6.0-unsigned.hap
```


## Harmony X 3.5.0 · 2026-10-24

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.5.0)

# Harmony X 3.5.0 (28)

本版新增离线视频库、全球趋势、搜索联想与最近访问记录，扩展启动动画选择，并改善背景图库管理、帖子链接与长图显示及大屏信息流稳定性。构建版本为 28。

### 新增功能

- **离线视频库**：可将帖子视频保存到应用内，在“离线视频”页面搜索、按日期浏览和直接播放，并查看空间占用、删除单项或确认后清空。文件与记录按账号管理，重复保存会去重，取消或下载失败不会留下完成记录。
- **全球趋势**：增加独立的全球趋势页面，支持查看服务提供的国家或地区、分类、话题及相关帖子，并继续加载内容。切换账号后重新加载，过期请求不会覆盖当前账号的数据。
- **搜索联想与最近访问**：输入关键词时显示相关话题和用户建议；搜索页记录最近访问的用户，支持长按确认删除单条用户或关键词记录。搜索结果使用独立页面，从结果页修改或取消关键词时保留原有结果。
- **启动动画选择**：提供“直接进入”“保持图标”“iOS 风格”“灵动开场”四种模式；灵动开场支持 0.5× 至 2× 的七档速度。首页加载与开场并行，设置会持久保存并纳入外观云同步；减少动态效果及异常播放均有退出处理。
- **棱镜混色主题**：新增棱镜主题，为主导航和操作控件提供不同配色，适配浅色与深色外观。

### 改进与修复

- **背景图库管理**：页面背景与聊天背景共用图库操作组件，支持删除已保存图片并确认操作；删除当前选中图片后回退到有效背景，保存或删除失败时保留可恢复的记录。
- **帖子链接显示**：正文、长帖、引用和转帖优先按接口提供的原始地址展开短链接；点击时保留完整路径、参数和片段，避免将省略后的显示文案当成实际目标。兼顾表情符号、编号列表、缩进与正文显示范围。
- **译文链接保护**：翻译时保留原文网址和编号链接，译文中的链接仍可直接打开；翻译服务遗漏或改写地址时不采用损坏的链接结果。
- **长图与媒体布局**：横滑图片按原始比例展示，减少长截图上下内容被裁切；改善媒体拖动时的头像与操作区反馈，保持信息流和详情布局一致。
- **大屏信息流与视频预览**：保持视频封面与播放器的显示高度一致，收到原生首帧前继续显示封面；搜索信息流按需创建内容并保留稳定分栏，减少播放加载及滚动时的跳动。
- **首页与搜索布局**：可单独设置单击首页标签回到顶部，双击和下拉刷新沿用各自设置；调整首页指示器及探索分类间距，并统一搜索、浏览历史和离线视频页面的搜索框样式。
- **启动画面衔接**：统一开场视频、末帧与外层背景色，补齐视频色彩矩阵和范围标记，减少不同解码路径下的背景色块；开场结束、切到后台或退出页面时清理遮罩与计时器。
- **版本信息**：统一应用、中英文说明和 21 份本地化版本文案为 3.5.0（`versionCode` 28），最低兼容 API 22、目标 API 26。

### 构建说明

- 本版提供未签名 Release App Pack 与 HAP；安装前需使用自己的 HarmonyOS 证书与 Profile 重新签名。
- 本次发布通过 390 项专项测试及 Release 编译，并核对 App Pack / HAP 包内版本、包名与 API 元数据，结果随发布产物保存。本轮不包含真机交互与视觉验收，离线播放、趋势服务、旋转及 API 22 设备仍需分别验证。

---

This release adds an offline video library, global trends, search suggestions and recent profiles, expands launch animation options, and improves background photo management, post links, long images, and large-screen feed stability. The build number is 28.

### New features

- **Offline video library**: Save post videos inside the app, search and browse them by date, play local copies, inspect storage usage, delete individual items, or clear the library after confirmation. Files and records belong to their account, repeated saves are deduplicated, and cancelled or failed downloads do not appear as completed items.
- **Global trends**: A dedicated page shows service-provided countries or regions, categories, topics, and related posts, with further loading. Account changes reload the page and stale requests cannot replace the current account's data.
- **Search suggestions and recent profiles**: Typing shows related topics and suggested users. Search remembers recently visited profiles and supports confirmed removal of individual profiles or keywords with a long press. Results open in a separate page, retaining the original results when a query edit is cancelled.
- **Launch animation options**: Choose Direct entry, Keep icon, iOS style, or Dynamic opening. Dynamic opening offers seven speeds from 0.5× to 2×. Home loads alongside the animation, preferences persist and join appearance cloud synchronization, and reduced motion or playback failure can exit safely.
- **Prism mixed theme**: Added a Prism palette with distinct navigation and action colours for light and dark appearances.

### Improvements and fixes

- **Background photo management**: Page and chat backgrounds share gallery controls with confirmed deletion of saved images. Removing a selected photo falls back to a valid background, while failed writes or deletions retain recoverable records.
- **Post links**: Post bodies, long notes, quotes, and reposts expand short links using original URLs supplied by the service. Opening a link retains its full path, query, and fragment instead of using an abbreviated display label, while preserving emoji, numbered lists, indentation, and body display ranges.
- **Links in translations**: Translations preserve original URLs and numbered links, and translated links remain directly accessible. Responses with missing or rewritten addresses are not accepted as valid link results.
- **Long images and media layout**: Horizontal photo strips preserve source aspect ratios to reduce cropping of long screenshots. Gallery dragging improves avatar and action feedback, with consistent layouts in feeds and post details.
- **Large-screen feeds and video previews**: Preview and player heights stay consistent, and the preview remains visible until the native first frame. Search feeds render content lazily with stable columns to reduce movement during loading, playback, and scrolling.
- **Home and search layout**: A separate preference controls scrolling to the top with a single Home tap; double taps and pull-to-refresh retain their own settings. Adjusted the Home indicator and Explore category spacing, and unified search fields in search, browsing history, and offline videos.
- **Launch transitions**: Aligned video, final-frame, and surrounding background colours, and added video colour-matrix and range metadata to reduce background blocks across decoder paths. Completion, backgrounding, and page exit clean up covers and timers.
- **Version information**: App metadata, bilingual documentation, and all 21 localized version strings use 3.5.0 (`versionCode` 28), with compatible API 22 and target API 26.

### Build notes

- This release provides unsigned Release App Pack and HAP files. Re-sign them with your own HarmonyOS certificate and Profile before installation.
- All 390 focused tests and Release compilation passed. App Pack / HAP version, bundle, and API metadata are checked and the results accompany the artifacts. Device interaction and visual acceptance are outside this build; offline playback, trends, rotation, and API 22 devices still need separate verification.

## Local build verification

- Branch: X-new; HEAD: 3cca5537cd2035a91a749986fb644c13a722de0a. Includes local working-tree changes.
- Version 3.5.0 (28), release mode, com.haohaoai0.harmonx, compatible API 22, target API 26.
- 390 focused tests passed; App Pack and HAP metadata verified. Unsigned HAP confirmed with hap-sign-tool.
- All 4611 HAP content entries match the module output; PackageApp regenerates pack.info.
- Device interaction and visual acceptance were not performed.

## SHA-256

```text
bfa7bcdf3d770f52297b31def03e71f9636460dc92d13a2f8fd44eadd8b270a0  HarmonyX-v3.5.0-unsigned.app.zip
8e671ddbf7ee64f23b7e8697310c0afa08f3a0e64db8bf03462c44042a404cf9  HarmonyX-v3.5.0-unsigned.hap
```


## Harmony X 3.4.0 · 2026-10-21

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.4.0)

# Harmony X 3.4.0

## 中文更新日志

本版新增随应用图标变化的启动动画、底部导航与首页标签排序、帖子操作栏自定义、混合媒体横滑和设置配置导入导出，并改善视频下载提示、画中画返回、系统媒体封面及个人主页滚动。构建版本为 26。

### 新增功能

- **图标启动动画**：冷启动按当前桌面图标和浅色、深色外观播放本地动画，末帧衔接首页后淡出。覆盖现有备用图标，开启低动态效果或播放失败时快速进入首页；启动动画不等待网络内容。
- **导航与首页排序**：可分别调整底部导航和首页“推荐”“关注”、列表、社区及主题标签的顺序，立即生效并可恢复默认。隐藏标签、点击切换、左右滑动和液态指示器沿用调整后的顺序，信息流内容及阅读位置仍归属原内容源。
- **帖子操作栏自定义**：可分别显示或隐藏回复、转帖、点赞、浏览量、收藏、分享和翻译入口，并独立控制数字显示。信息流与详情使用统一操作栏；接口未提供的收藏数量不会显示为虚构的零。
- **混合媒体横滑**：同一帖子中的多段视频，以及图片、视频和 GIF 混排附件，按原顺序横向滑动浏览，统一行高并保留各自比例。首页与详情共用布局；纯图片帖子保留原有展示方式。
- **设置配置导入导出**：华为账号面板增加本地 JSON 配置文件导入与导出，可分享或迁移支持的偏好设置。导入前校验文件格式与内容并要求确认，文件不包含登录凭证；云端同步仍需单独开启。
- **“我的”快捷操作**：可将“我的”页面分离式导航的独立操作按钮设为个人主页、账号管理、设置或帮助，也可隐藏，选择会在重启后保留。
- **开屏推荐**：符合展示条件时使用已缓存的应用介绍图组成推荐开屏，提供明确的推广标识、倒计时和随时可用的跳过按钮，只有点击行动按钮才跳转。后台停留超过 10 分钟后返回可再次展示，结束后保留原页面；支持者免推广，引导、登录与分享入口跳过，素材或权益状态不可用时直接进入内容。

### 改进与修复

- **视频下载提示**：增加应用内紧凑进度提示，按实际下载字节更新，可取消当前传输并接续队列。下载结束后继续显示保存状态，文件真正保存成功才显示完成标记与前台触感；取消或失败不会误报成功，重试历史任务不会留下常驻保存提示。
- **画中画返回**：从画中画恢复时返回所属页面并复用原播放器，保留进度和播放状态，尊重用户主动暂停。隐藏页面不会抢走画中画画面或误暂停播放；离开原页面后关闭画中画会释放保留的播放器。
- **横屏视频切换**：视频流旋转入口调用当前视频的全屏播放器，横屏与内嵌画面复用同一解码器，避免切换重置进度；退出后恢复应用方向策略，忽略过期方向请求。
- **系统媒体封面**：视频媒体会话改用应用图片加载器提供封面，缺失时尝试已有帧缓存。切换视频后丢弃旧封面响应，封面不可用时仍可建立播放会话。
- **个人主页滚动**：修复帖子区域点停后后续拖动失灵的问题，改善外层资料区与内层信息流的手势交接。
- **账号资料页面**：“关于此账号”改为独立原生导航页面，展示账号身份、加入时间及接口提供的地区和来源信息，支持失败重试与正常返回。
- **登录提示**：引导及后续登录网页上方新增提示：请勿使用 Google 登录，请直接输入邮箱；网络正常时若出现白屏，请耐心等待。
- **版本信息**：统一应用、中英文文档与 21 份本地化版本文案为 3.4.0（`versionCode` 26），最低兼容 API 22、目标 API 26。

### 说明

- 本次发布通过 345 项相关专项测试，并执行 Release 编译及 App Pack / HAP 包内版本、包名和 API 元数据核验；不宣称全量回归全部通过。
- 本轮发布未重新执行真机交互验收；跨设备设置迁移、系统画中画与媒体卡片、折叠和旋转、真实下载目录授权及 API 22 设备仍需分别验收。
- 本版提供未签名 App Pack 与 HAP，安装前需使用自己的 HarmonyOS 证书与 Profile 重新签名。

## English changelog

This release adds icon-specific launch animations, navigation and home-tab ordering, customizable post actions, horizontal mixed-media browsing, and settings file import and export. It also improves download feedback, picture-in-picture restoration, system media artwork, and profile scrolling. The build number is 26.

### New features

- **Icon-specific launch animations**: Cold launches play a local animation matching the current launcher icon and light or dark appearance, then fade its final frame into the home page. Existing alternate icons are covered. Reduced motion or playback failure opens the home page promptly, without waiting for network content.
- **Navigation and home-tab ordering**: Reorder bottom navigation separately from For You, Following, list, community, and topic tabs, with immediate updates and a reset option. Hidden tabs, taps, swipes, and the liquid indicator follow the selected order, while each feed retains its content and reading position.
- **Customizable post actions**: Independently show or hide reply, repost, like, views, bookmark, share, and translation actions, and toggle their counts. Feeds and details share the action bar; absent bookmark counts are not presented as a fabricated zero.
- **Horizontal mixed media**: Multiple videos and mixed photo, video, and GIF attachments scroll horizontally in their original order, sharing a bounded row height while preserving individual aspect ratios. Feeds and details share the layout; photo-only posts retain their existing presentation.
- **Settings file import and export**: The Huawei account panel can export and import a local JSON settings file for sharing or migrating supported preferences. Import validates the file and asks for confirmation. Files exclude sign-in credentials, and cloud synchronization remains a separate opt-in.
- **Me shortcut**: Choose Profile, Account management, Settings, Help, or Hidden for the independent split-navigation action on the Me page. The choice survives restarts.
- **Launch recommendations**: Eligible openings can show a recommendation made from cached app introduction images, with an advertising label, countdown, and immediately available Skip button. Only the action button opens the destination. Returning after more than ten minutes in the background can show another recommendation and then restore the current page. Supporters, onboarding, sign-in, and share entry paths bypass it; unavailable artwork or entitlement state opens content directly.

### Improvements and fixes

- **Video download feedback**: A compact in-app notice tracks actual transferred bytes, can cancel the current transfer, and advances through queued tasks. It continues through saving and shows completion and foreground haptic feedback only after a successful save. Cancellation and failure never report success, and retried historical tasks cannot leave a permanent saving notice.
- **Picture-in-picture restoration**: Restoring PiP returns to its owning page and reuses the player, preserving position and playback state while respecting an explicit pause. Hidden pages cannot take its surface or pause it accidentally. Closing PiP after leaving the owning page releases the retained player.
- **Landscape video transitions**: The video-feed rotation action opens the current video's fullscreen player. Landscape and inline surfaces reuse the decoder without resetting position. Exiting restores the application orientation policy and ignores obsolete requests.
- **System media artwork**: Video sessions obtain artwork through the app image loader, falling back to an existing frame cache when available. Late artwork from a previous video is discarded, and unavailable artwork does not prevent a playback session from starting.
- **Profile scrolling**: Fixed dragging becoming unresponsive after stopping the post feed, improving gesture handoff between the profile header and nested feed.
- **About this account**: Account information now opens in a native navigation page with identity, join date, and service-provided region and source details, plus retry and normal back navigation.
- **Sign-in guidance**: A notice above onboarding and subsequent sign-in asks users to enter their email directly instead of using Google sign-in, and to wait if a working connection still produces a blank page.
- **Version information**: App metadata, bilingual documentation, and all 21 localized version strings use 3.4.0 (`versionCode` 26), with compatible API 22 and target API 26.

### Notes

- All 345 related focused tests passed. This release also runs Release compilation and checks embedded App Pack / HAP version, bundle, and API metadata; it does not claim a fully green complete regression suite.
- Device interactions were not repeated for this release. Cross-device settings migration, system PiP and media cards, folding and rotation, real download-directory grants, and API 22 devices still need separate acceptance.
- This release provides unsigned App Pack and HAP files. Re-sign them with your own HarmonyOS certificate and Profile before installation.

## 下载与安装 / Downloads and installation

- `HarmonyX-v3.4.0-unsigned.app.zip`：未签名 App Pack，与原始 `.app` 文件内容一致。Unsigned App Pack, identical to the original `.app` file.
- `HarmonyX-v3.4.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。Unsigned module package extracted from that App Pack.

安装前需使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。
Re-sign with your own HarmonyOS certificate and Profile before installing, using DevEco Studio or `hap-sign-tool`.

## 构建核验 / Build verification

- 构建来源：本地 `X-new` 分支，HEAD `3cca5537`，包含本次 3.4.0 版本与日志修改。
- Release 模式，版本 3.4.0（26），包名 `com.haohaoai0.harmonx`。
- 兼容 API 22，目标 API 26；phone / tablet / 2in1；最多 5 个应用分身。
- 本轮 345 项专项测试全部通过；App Pack 与 HAP 均已核验包内元数据。
- 本次发布仅上传安装包，源码修改保留在本地。

- Built from the local `X-new` branch at HEAD `3cca5537`, including this release's version and changelog edits.
- Release build, version 3.4.0 (26), bundle `com.haohaoai0.harmonx`.
- Compatible API 22, target API 26; phone / tablet / 2in1; up to five app clones.
- All 345 focused tests passed; embedded App Pack and HAP metadata was verified.
- This release publishes binaries only; source changes remain local.

## SHA-256

```text
0784bcb559ec54de3ab1e0fee11854e0d6a1fd51cf8b43c1b0abb18f25b49d8d  HarmonyX-v3.4.0-unsigned.app.zip
ea595e932d217ac6159c4f65bc1a0deab8919a65570f82dc853e4dde158b7a4a  HarmonyX-v3.4.0-unsigned.hap
```


## Harmony X 3.3.0 · 2026-10-20

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.3.0)

# Harmony X 3.3.0

## 中文更新日志

本版新增分离式底部导航、分离式回复胶囊、首页列表与社区标签管理、横屏视频控制和 8 款图标取色主题，并改善下载保存、滚动点停、账号操作及标题栏图标显示。构建版本为 25。

### 新增功能

- **分离式底部导航**：新增分离式胶囊与原生 HDS 材质样式，将主导航和独立操作按钮分开展示，可调整原生材质档位。支持握持手适配，液态指示器按实际标签位置对齐，拖动与点按切换保持一致。
- **分离式回复胶囊**：帖子底部可将回复输入与操作区分开展示，保留回复、点赞等操作及展开编辑器的衔接动画；窄窗口允许横向滚动操作区，避免按钮被挤压或遮挡。
- **首页内容源管理**：可将列表、已加入的社区和主题放入首页标签，调整混合顺序，并为不同社区分别保存排序方式。配置按账号保留，重启后恢复；移除社区首页标签不会退出社区。
- **横屏视频控制**：全屏横屏增加材质控制区，提供播放、静音、进度、倍速、锁定及相关帖子操作。轻点画面唤出控制，锁定后通过解锁按钮恢复，拖动进度中断时也会正确提交位置并恢复播放控制。
- **GIF 视频导出**：视频形式的 GIF 可选择直接保存原始 MP4，优先使用接口提供的较高质量版本；保留原有 GIF 保存方式，避免为了保存视频再次转码。
- **8 款图标取色主题**：新增图标蓝、红、橙、黄、绿、粉、青和深蓝配色，控件分别适配浅色与深色外观。
- **个人简介翻译**：个人主页可翻译简介，沿用当前翻译服务配置，并可收起译文；切换用户或修改翻译设置后清除旧结果。
- **推荐内容筛选**：内容设置新增“仅查看敏感内容”，默认关闭并在启用前要求成年确认，仅作用于首页推荐流，不改变关注、列表和社区内容源。

### 改进与修复

- **下载与保存**：支持选择并记住文件保存目录，授权失效时重新选择；并发保存自动避免重名覆盖。取消选择不再误报成功，已下载任务可重新“另存为”，多图导出中断后保留已完成文件与可重试任务。
- **滚动点停**：信息流惯性滚动时，首次按下立即停住列表并阻止误触帖子；停稳后可正常点开内容。改善个人主页内外层滚动协同，抬手后不再续滑，后续拖动保持正常速度。
- **首页标签与封面**：列表置顶、改名和取消置顶可在重启后正确恢复；列表与社区目录分别分页去重，切换账号后丢弃旧响应。标签封面复用本地缓存，代理暂时失败可重试，避免旧封面覆盖新选择。
- **视频旋转与返回**：全屏旋转期间保留底层导航和信息流，退出后按当前窗口恢复布局；新的全屏视频不会被前一次退出的延迟回调打断。
- **悬浮发帖按钮**：可拖到窗口四角，窗口尺寸变化时只将手动位置限制在可见范围内；原生导航握持适配同时遵循总开关和单项开关。
- **账号与关注操作**：退出登录增加确认并防止重复触发，确认期间切换账号不会退出新账号；推荐关注立即反馈状态、阻止重复请求，失败后恢复。
- **标题栏图标**：逐个提取备用图标的透明前景，去除背景底板。黑白 X 可按深浅外观自动反色，奶蛙、青蛙、鸟、花语、笔刷等特殊图标保留原始彩色前景。
- **动画预览**：连续或快速点击可重新播放完整预览，旧动画的延迟回调不再干扰新一轮播放；低动态模式和离开页面时及时停止。
- **支持者状态**：加强多账号激活、凭证迁移和安全存储恢复，避免迟到响应串号；临时断网或服务故障保留尚未过期资格，云端明确停用只影响对应账号。
- **版本显示**：统一应用版本、中英文说明和 21 份本地化版本文案为 3.3.0（`versionCode` 25），最低兼容 API 22、目标 API 26。

### 说明

- 本次发布执行 Release 编译、App Pack / HAP 元数据核验，241 项相关专项测试全部通过；构建结果不代表所有设备场景均已验收。
- 跨设备支持者恢复、实际文件目录授权、横屏锁定与折叠切换、真实外设及 API 22 设备仍需分别验收；本版不宣称全量回归全部通过。
- 本版提供未签名 App Pack 与 HAP，安装前需使用自己的 HarmonyOS 证书与 Profile 重新签名。

## English changelog

This release adds split bottom navigation, a split reply capsule, home tabs for lists and communities, landscape video controls, and eight icon-inspired colour themes. It also improves saving downloads, stopping scrolling, account actions, and title-bar icons. The build number is 25.

### New features

- **Split bottom navigation**: Choose a split capsule or native HDS material style, with the main navigation and independent action in separate surfaces. Native material levels are adjustable. Handedness adaptation and the liquid indicator follow the actual visible tab positions for taps and dragging.
- **Split reply capsule**: Post details can separate the reply entry from its action area while retaining reply and post actions and the transition into the expanded editor. Narrow windows scroll the action area horizontally to keep buttons usable.
- **Home source management**: Add lists, joined communities, and topics to home tabs, reorder them together, and save a separate ranking for each community. Settings are retained per account across restarts. Removing a community tab leaves its membership intact.
- **Landscape video controls**: Fullscreen landscape playback gains material controls for playback, mute, seeking, speed, locking, and related post actions. Tapping reveals controls; a dedicated unlock button releases the lock. Interrupted seeking still commits the selected position and restores playback control.
- **GIF video export**: Video-based GIFs can be saved directly as the original MP4, preferring a higher-quality variant advertised by the service. Existing GIF export remains available, without another transcode when saving video.
- **Eight icon-inspired themes**: New blue, red, orange, yellow, green, pink, cyan, and navy palettes provide separate control colours for light and dark appearance.
- **Biography translation**: Translate profile biographies through the configured translation service and hide the result when finished. Changing profiles or translation preferences clears stale results.
- **Recommendation filtering**: An optional sensitive-content-only setting starts disabled, requires adult confirmation, and applies only to the For You feed. Following, list, and community sources retain their existing content.

### Improvements and fixes

- **Downloads and saving**: Choose and remember a save directory, with a new selection when authorization expires. Concurrent saves avoid overwriting duplicate names. Cancelled selections no longer report success; downloaded tasks can retry Save As, and interrupted multi-image exports retain completed files and retryable tasks.
- **Stopping scrolling**: The first press during inertial feed scrolling stops the list immediately and suppresses an accidental post action. Once stopped, posts open normally. Nested profile feeds stop together, queued inertia stays cancelled after release, and later drags retain normal speed.
- **Home tabs and covers**: List pins, renames, and removals restore correctly after restart. List and community directories paginate and deduplicate separately, and old-account responses are discarded. Tab covers reuse local files, retry transient proxy failures, and reject outdated cover requests.
- **Video rotation and return**: Fullscreen rotation retains the underlying navigation and feed, then restores the current window layout on exit. A previous exit callback cannot interrupt a newer fullscreen video.
- **Floating compose button**: Drag the button to any window corner. Resizing only clamps its manual position to the visible area. Native navigation handedness follows both the master and individual switches.
- **Account and follow actions**: Signing out requires confirmation and ignores duplicate taps or an account change during the dialog. Follow suggestions respond immediately, suppress duplicate requests, and roll back on failure.
- **Title-bar icons**: Alternate icons now use individually prepared transparent foregrounds without background plates. Black and white X marks can adapt to light or dark appearance; milk frogs, frogs, birds, blossoms, brushes, and other special icons retain their original colours.
- **Motion preview**: Repeated or rapid taps start a complete new preview without interference from older callbacks. Reduced motion and leaving the page stop active playback promptly.
- **Supporter state**: Improved account-bound activation, credential migration, and secure-storage recovery prevent stale responses from crossing accounts. Transient network or service failures retain unexpired access; explicit cloud revocation affects only the corresponding account.
- **Version information**: App metadata, bilingual documentation, and all 21 localized version strings now use 3.3.0 (`versionCode` 25), with compatible API 22 and target API 26.

### Notes

- This release runs Release compilation and App Pack / HAP metadata verification, with all 241 related focused tests passing. A successful build does not establish acceptance on every device.
- Cross-device supporter recovery, real folder grants, landscape locking and fold transitions, physical input devices, and API 22 devices need separate acceptance. This release does not claim a completely green full regression suite.
- This release provides unsigned App Pack and HAP files. Re-sign them with your own HarmonyOS certificate and Profile before installation.

## 下载与安装 / Downloads and installation

- `HarmonyX-v3.3.0-unsigned.app.zip`：未签名 App Pack，与原始 `.app` 文件内容一致。Unsigned App Pack, identical to the original `.app` file.
- `HarmonyX-v3.3.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。Unsigned module package extracted from that App Pack.

安装前需使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。
Re-sign with your own HarmonyOS certificate and Profile before installing, using DevEco Studio or `hap-sign-tool`.

## 构建核验 / Build verification

- 构建来源：本地 `X-new` 分支，HEAD `3cca5537`，包含本次 3.3.0 版本与日志修改。
- Release 模式，版本 3.3.0（25），包名 `com.haohaoai0.harmonx`。
- 兼容 API 22，目标 API 26；phone / tablet / 2in1；最多 5 个应用分身。
- 本轮 241 项专项测试全部通过；App Pack 与 HAP 均已核验包内元数据。
- 本次发布仅上传安装包，源码修改保留在本地。

- Built from the local `X-new` branch at HEAD `3cca5537`, including this release's version and changelog edits.
- Release build, version 3.3.0 (25), bundle `com.haohaoai0.harmonx`.
- Compatible API 22, target API 26; phone / tablet / 2in1; up to five app clones.
- All 241 focused tests passed; embedded App Pack and HAP metadata was verified.
- This release publishes binaries only; source changes remain local.

## SHA-256

```text
8460835c8b381d4470fe9fe059b0c25f381abddbe015258274008a3563fcc5e2  HarmonyX-v3.3.0-unsigned.app.zip
25393a35712d6e5d9471bc3ee952a666179854c99efedc4317f53707fa107d54  HarmonyX-v3.3.0-unsigned.hap
```


## Harmony X 3.2.0 · 2026-10-19

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.2.0)

Harmony X 3.2.0 · versionCode 24 · 2026-10-20

## 中文更新日志

本版加入离线收藏与长线程阅读、场景模式、眼动翻页和鼠标、键盘、触控板操作，新增聊天装扮、评论质量折叠与帖子语言屏蔽，并完善阔屏、小折叠外屏和旧系统兼容。构建版本为 24。

### 新增功能

- **离线收藏与稍后读**：书签新增“离线与稍后读”视图。收藏时保存正文和可获取的长文，可选下载配图；本地副本按账号隔离，支持全文搜索、标签、备注、未读筛选和删除，普通缓存清理不会移除。
- **长线程阅读**：帖子详情新增连续阅读视图，可在“只看作者”和完整讨论之间切换，调节字号、整段翻译并继续加载回复。阅读位置会保留，读到末尾自动标为已读，离线副本也可使用。
- **场景模式**：提供清爽阅读、节能省流和媒体浏览三套配置，一次调整自动播放、图片与视频画质、动效和背景。首次启用前会保存原配置，“恢复原配置”可找回个人设置，连续切换场景不会覆盖备份。
- **眼动翻页**：在支持 AR Engine 人脸跟踪的设备上，可在长线程、文章和离线副本中通过向上或向下注视翻页，并调整注视停留时间与触发幅度。功能默认关闭，只在主动开始后使用前置摄像头；方向参数在本机处理，不保存或上传画面。
- **鼠标、键盘与触控板**：支持 Ctrl+1～5 切换主页面，Ctrl+K、Ctrl+N、Ctrl+R、Ctrl+, 与 F1 快捷操作，以及 Tab 走焦、Enter/Space 激活、Ctrl+Enter 提交和 Esc/Alt+← 返回。图片支持左右键翻页，视频支持上下键切换、空格播放和左右键快进快退。帮助中心新增快捷键说明页；右键及触控板双指轻点可复用媒体、聊天和会话列表菜单。
- **聊天装扮**：新增免费头像挂件与聊天气泡目录，可下载预览、应用、替换和恢复默认。应用只保留已校验的本地素材，并可限制包体大小与摘要；对方看到的样式仍取决于其客户端。
- **评论质量折叠**：内容设置可选择折叠重复推广、批量引流、重复外链和联系方式等疑似低质量评论。折叠项可查看判断原因，也可将作者加入当前账号的白名单；默认关闭，判断仅在本机完成，自己、帖主和已关注作者始终显示。
- **帖子语言屏蔽**：内容过滤支持多选屏蔽语言，并依据帖子自身检测到的语言生效。未识别语言和纯媒体帖子继续显示，引用中的其他语言不会被误当作主帖语言。
- **外屏视频布局**：Pura X 等小方屏可选择侧边操作栏或底部横排，设置独立于原视频流布局保存。展开设备后恢复原布局，极短窗口会收起可选文案，避免操作区与标题栏重叠。
- **阔屏与分栏**：桌面布局从 600vp 起覆盖平板和阔屏手机竖屏；中等宽度使用紧凑导航，聊天与设置分类按整页打开，减少分栏挤压。宽屏设置返回会先回到分类菜单。
- **帖子信息**：详情补充收藏数、引用数和“已编辑”标记，可进入编辑记录；收藏状态变化会同步更新数量，请求失败时恢复原值。
- **应用分身**：应用包配置启用系统应用分身，最多可创建 5 个分身。

### 改进与修复

- **API 22 兼容**：最低安装版本降至 6.0.2(22)。API 26 沉浸材质、API 24 HDR、API 23 悬浮底栏和眼动能力按运行时能力降级，旧系统保留普通背景、播放、导航和阅读路径。
- **Pura X 旋转**：折叠设备启动和退出全屏视频后恢复受系统旋转锁定控制的横竖屏策略；延迟完成的全屏请求不会覆盖较新的退出方向。
- **评论加载**：帖子详情和视频评论会跟随仅含游标的分页继续读取，保留嵌套及模块回复，不把推荐内容当作评论。仍有后续页或请求失败时保留重试入口，不再误报“暂无评论”；媒体查看器内的评论不再插入推广。
- **底部导航与标题栏**：液态胶囊改为叠加在原生 HDS 导航上，拖动、隐藏标签和大屏缩放保持对齐；新增底部 Tab 渐变遮罩开关。顶部品牌标识会跟随当前备用图标和明暗外观更新。
- **外观与操作反馈**：材质、配色、标题栏、弹窗和回复胶囊设置增加即时预览；新增悬浮发帖按钮材质着色开关；修复开关切回初始值时不生效的问题。
- **列表目录**：默认列表页只保留已关注和自己创建的列表，过滤推荐与未关注置顶项；搜索、他人主页和成员关系仍按原范围展示公开列表。
- **账号与媒体状态**：改善回复胶囊和侧栏头像在离线、切换账号或网络迟到时的显示，避免回写上一账号的头像或草稿。
- **版本信息统一**：应用、中英文 README 与更新日志更新为 3.2.0（`versionCode` 24）。

### 说明

- 本轮已完成 entry 模块的 Release 编译与 App Pack、HAP 打包，并覆盖阅读、场景、眼动、输入、评论、媒体、布局和兼容性相关测试。
- 全量测试仍有历史夹具失配及新增文案的英文回退用例未通过，不能视为“全部回归通过”。眼动精度与舒适度、真实外设、聊天装扮服务端目录、断网离线阅读、Pura X 外屏和 API 22 设备仍需真机验收。
- 本版提供未签名 App Pack 与 HAP，安装前需使用自己的 HarmonyOS 证书与 Profile 重新签名。

## English changelog

This release adds offline bookmarks and continuous thread reading, scene modes, eye-controlled page turning, and mouse, keyboard, and touchpad support. It also introduces chat decorations, reply-quality folding, post-language filtering, and improvements for wide screens, compact foldables, and older systems. The build number is 24.

### New features

- **Offline bookmarks and read later**: Bookmarks now includes an Offline and read later library. Saving a bookmark captures its text and any available long-form content, optionally with images. Local copies are isolated by account and support full-text search, tags, notes, unread filtering, and deletion. Ordinary cache cleanup leaves them intact.
- **Continuous thread reading**: Post details include a focused reader that switches between the author's posts and the full discussion, adjusts font size, translates the complete text, and loads more replies. Reading position is retained, reaching the end marks the thread as read, and offline copies use the same reader.
- **Scene modes**: Reading, data saver, and media presets adjust autoplay, image and video quality, motion, and backgrounds together. The original preferences are saved before the first scene is applied, so Restore original preferences returns the personal setup even after switching scenes.
- **Eye-controlled page turning**: Devices with AR Engine face tracking can scroll long threads, articles, and offline copies by looking up or down and dwelling. Dwell time and movement threshold are adjustable. The feature starts disabled and opens the front camera only after an explicit start; direction data stays on the device, with no image or facial parameters saved or uploaded.
- **Mouse, keyboard, and touchpad**: Use Ctrl+1–5 for the main tabs, Ctrl+K, Ctrl+N, Ctrl+R, Ctrl+,, and F1 for common actions, plus Tab focus, Enter/Space activation, Ctrl+Enter submission, and Esc/Alt+← for back. Photos page with the arrow keys; videos switch with Up/Down, play with Space, and seek with Left/Right. The Help Center documents every shortcut. Right-click and touchpad two-finger taps reuse the media, chat, and conversation menus.
- **Chat decorations**: A free catalog provides avatar frames and chat bubbles that can be previewed, downloaded, applied, replaced, or reset. Only validated local packages are retained, with size and digest limits. What another person sees still depends on their client and selected decoration.
- **Reply-quality folding**: Content settings can fold suspected low-quality replies such as repeated promotions, bulk solicitation, duplicate external links, and contact details. Each folded reply can show its reasons, and an author can be allowlisted for the active account. The feature is off by default, runs locally, and never hides the viewer, the post author, or followed authors.
- **Post-language filtering**: Content filters can mute multiple post languages using language metadata on each post. Unrecognized languages and media-only posts remain visible, and a quoted post's language is not mistaken for the outer post.
- **Compact-cover video layout**: Pura X-style cover screens can place video actions in a side rail or a bottom row, independently of the main video-feed layout. Unfolding restores the main layout, while very short windows hide optional captions to keep the controls clear.
- **Wide layout**: Desktop layout now starts at 600vp for portrait tablets and wide phones. Medium windows use compact navigation and open chats and settings categories as full pages to avoid cramped split panes. Back inside wide settings returns to the category menu first.
- **Post details**: Bookmark and quote counts and an Edited marker are shown in post details, with access to edit history. Bookmark changes update the count immediately and restore it if the request fails.
- **App clones**: The package enables system app clones with a maximum of five copies.

### Improvements and fixes

- **API 22 compatibility**: The minimum supported runtime is now 6.0.2(22). API 26 immersive materials, API 24 HDR, API 23 floating navigation, and eye tracking fall back according to runtime capability, retaining ordinary backgrounds, playback, navigation, and reading paths.
- **Pura X rotation**: Foldables restore portrait and landscape rotation governed by the system rotation lock after launch and after leaving fullscreen video. A late fullscreen request cannot overwrite a newer exit orientation.
- **Comment loading**: Post details and video comments follow cursor-only pages, retain nested and module replies, and never treat recommendations as comments. A thread with more pages or a failed request keeps a retry path instead of reporting no comments, and embedded media comments no longer receive promotional posts.
- **Bottom navigation and title bar**: The liquid capsule is now layered over native HDS navigation so dragging, hidden labels, and large-screen scaling stay aligned. A bottom-tab gradient-mask switch is available, and the title-bar brand mark follows the active alternate icon and light or dark appearance.
- **Appearance feedback**: Material, palette, title-bar, sheet, and reply-capsule settings include live previews. A material-tint switch is available for the floating compose button, and switches no longer ignore a change back to their initial value.
- **List directory**: The default Lists page keeps followed and owned lists while filtering recommendations and unfollowed pinned entries. Search, other profiles, and memberships still show public lists in their existing scopes.
- **Account and media state**: Reply-capsule and drawer avatars now avoid showing or restoring an old account's avatar when offline, switching accounts, or receiving a late network response.
- **Consistent version information**: The app, bilingual READMEs, and changelogs now use version 3.2.0 (`versionCode` 24).

### Notes

- The entry module passed Release compilation and App Pack and HAP packaging. Reading, scene, eye-tracking, input, comments, media, layout, and compatibility coverage was exercised.
- The complete test suite still has failures in legacy harness fixtures and English fallback copy for some newly added strings, so this release does not claim a fully green regression run. Eye-tracking accuracy and comfort, physical input devices, the decoration service catalog, offline reading without a network, Pura X cover screens, and API 22 devices still need device acceptance.
- This release provides unsigned App Pack and HAP files. Re-sign them with your own HarmonyOS certificate and Profile before installation.

## 下载与安装 / Downloads and installation

- `HarmonyX-v3.2.0-unsigned.app.zip`：未签名 App Pack，与原始 `.app` 文件内容一致。Unsigned App Pack, identical to the original `.app` file.
- `HarmonyX-v3.2.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。Unsigned module package extracted from that App Pack.

安装前需使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。
Re-sign with your own HarmonyOS certificate and Profile before installing, using DevEco Studio or `hap-sign-tool`.

## 构建核验 / Build verification

- Release 模式，版本 3.2.0（24），包名 `com.haohaoai0.harmonx`。
- 兼容 API 22，目标 API 26；phone / tablet / 2in1。
- App Pack 与 HAP 已完成 Release 编译与打包；构建、安装、真机功能仍需分别验证。
- 本次发布仅上传安装包，源码修改保留在本地。

- Release build, version 3.2.0 (24), bundle `com.haohaoai0.harmonx`.
- Compatible API 22, target API 26; phone / tablet / 2in1.
- The App Pack and HAP completed Release compilation and packaging; build, installation, and device behaviour remain separate verification steps.
- This release publishes binaries only; source changes remain local.

## SHA-256

```text
e0766cfb5fdaff33663e14bece45954636502a6a441cd50062dc2ad9a41bd959  HarmonyX-v3.2.0-unsigned.app.zip
4e65e3af3374738c707b80a0cbec682548e4a4459af2e85eef7b8d67cbc2ca45  HarmonyX-v3.2.0-unsigned.hap
```


## Harmony X 3.1.0 · 2026-10-18

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.1.0)

Harmony X 3.1.0 · versionCode 23 · 2026-10-18

## 中文更新日志

本版新增桌面服务卡片、原生资料编辑、页面背景搭配、混搭配色、动画与触感设置及 HDR 效果，完善手机双列与大屏自适应阅读，并改善 GIF 查看、图片保存、视频交互和设置导航。构建版本为 23。

### 新增功能

- **应用分身**：支持系统应用分身，最多可创建 5 个分身，便于分别使用不同账号。
- **桌面服务卡片**：提供 2×2、2×4 和 4×4 三种尺寸，可选择推荐、关注、趋势或通知作为内容来源。卡片跟随当前账号，使用已缓存的内容展示；点击帖子进入对应详情，齿轮按钮可更换来源并刷新卡片。
- **原生资料编辑**：支持修改姓名、简介、位置、网站、头像和横幅。保存后重新读取账号资料并更新应用内显示；部分步骤失败时保留未完成的编辑，方便重试。
- **12 款传统色主题**：新增朱砂、丹缳、琥珀、秋香、竹青、石青、景泰蓝、花青、紫棠、胭脂、檀色和苍山黛配色，分别适配浅色与深色外观，保留原有主题色选项。
- **页面转场选择**：设置新增“原有动画”和“官方风格”，选择后立即生效并在重启后保留，默认继续使用原有动画。图片与视频查看器保留各自的媒体展开和收起动画。
- **视频双击快进/快退**：双击画面右半边快进、左半边快退，默认每次 10 秒，可独立开关并在 1～60 秒之间调整；不改变长按倍速偏好。
- **图片作者栏**：图片查看器增加作者信息、主页入口和关注操作，关注状态与其他页面共享。
- **备用图标**：增加僵尸 X 图标选项。
- **手机双列与自适应信息流**：沿用现有信息流列数设置，手机首页可选择双列阅读；个人主页、书签、浏览记录、列表、社区、通知帖子、搜索及互动记录等页面按实际内容区域宽度切换单列、双列或三列，窄分栏自动收回单列，标题和加载提示保持整行显示。
- **GIF 图片查看器**：帖子、私信、待发送附件和 GIF 搜索中的动图接入统一图片查看器，支持放大查看和左右切换，图片与 GIF 混排时保留原顺序。GIF 搜索可先预览再选择当前动图；保存时保留原生 GIF，视频形式的动图沿用 GIF 转换流程。
- **页面背景搭配**：普通页面支持底色、照片、整套图案、跨套系图标混搭和纸张质感，可调整图标密度、纹理强度及帖子、私信列表和其他内容底板的不透明度；支持导入与分享包含背景图片的搭配方案，并可用总开关暂时关闭背景、保留原搭配。
- **共用背景图库**：帖子图片可保存到按账号区分的本地背景图库，在页面背景或聊天背景中选用。图片持久保存在应用文件中，清理缓存后仍可使用；重复保存同一来源会复用已有图片。
- **10 款混搭配色**：新增缤纷、海盐珊瑚、落日鸢尾、森林琥珀、莓果薄荷、莫兰迪、糖果缤纷、晴空柠檬、蜜桃薄荷和香芋奶黄，为开关、导航和发布按钮搭配不同颜色，并适配浅色与深色外观。
- **动画与触感**：提供轻快、标准、柔弹和低动态预置，可独立调整动画时长、运动幅度、弹性阻尼、Symbol 图标动效和触感强度；降低动画效果后跳过页面转场及装饰动效，保留原有参数，触感反馈遵循系统设置。
- **液态导航指示器**：悬浮底栏增加可拖动的胶囊指示器，点击或拖动切换标签时弹性回位，隐藏部分标签及关闭标签文字后仍按实际位置和尺寸对齐。
- **组件 HDR 与触摸高光**：增加独立的组件 HDR 开关及提亮倍数设置，默认关闭，默认倍数为 1.25；显示系统报告的当前屏幕最大提亮倍数。按钮、图标和选中态可使用高光效果，按压或拖动结束后及时收起触摸光效。
- **HDR 视频增强**：在系统报告支持的屏幕上，为普通视频启用系统 HDR 增强；屏幕变化时重新检测能力，不支持或调用失败时继续普通播放。
- **菜单操作显隐**：设置中按帖子、图片和视频分类管理菜单操作，可逐项隐藏并恢复默认，选择在重启后保留，并与各页面的实际菜单共用。
- **退出前确认**：主页面返回时可显示系统退出确认框，只有明确选择退出才关闭应用；手机侧栏展开时先收起侧栏。设置可关闭确认，二级页面继续正常返回。
- **华为账号与云同步入口**：接入华为账号登录、头像展示及可选的偏好同步，按外观与导航、阅读与播放、本地内容规则分组选择；默认不启用云同步，X 登录凭据、私信、草稿和缓存保留在本机。实际使用仍需完成账号服务和签名配置。
- **防窥保护入口**：提供系统防窥配置、授权状态提示和重新检测；授权完成后返回应用可再次检查并激活。仅在设备支持、已设置人脸识别且取得应用防窥授权时，按系统窥视状态触发保护蒙层。

### 改进与修复

- **“我的”账号总览**：优化头像、横幅和账号信息的展示，进入完整个人主页时先显示已有资料；刷新账号总览不再额外请求两条帖子时间线。
- **紧凑信息流卡片**：多列窄卡片调整封面、正文摘要和间距，多图查看仍保留完整图片序列，视频与 GIF 继续遵循原有自动播放设置。
- **图片保存与长按菜单**：保存当前图片改用系统安全保存按钮，点击授权后先准备相册位置，再等待下载；长按图片打开更多菜单，保留识图等操作。开启“保存到文件”后，每个文件通过系统另存为确认保存位置。
- **文件访问权限精简**：移除持久化文件访问权限及长期目录授权入口。原有保存到文件的偏好继续保留，取消或保存失败时下载任务可重试。
- **独立静音与播放交接**：首页预览和打开后的视频分别记住静音选择，临时静音、预加载和播放器交接不再覆盖用户偏好；视频控件隐藏时同步处理相关覆盖层。
- **首页首屏与推荐内容**：先呈现真实帖子，再插入推荐内容或展示启动弹窗；空白及尚未请求的时间线不以推荐内容占位。同步更新多列信息流的项目计数，处理加载后列表仍空白的问题。
- **材质默认值**：首次使用时侧栏材质默认关闭、半模态材质默认开启；已有的独立选择继续保留。
- **存储清理**：清理入口在确认前重新统计可清理缓存，并保留清理结果和失败反馈。
- **视频点击与预览声音**：扩大手动播放的整块画面响应区域；多卡片预览可继续播放画面，仅最近主动开启声音的卡片发声，打开视频后的独立静音选择继续保留。
- **旋转、折叠与小屏阅读**：切换列数或横竖屏时尽量保留当前帖子及卡片内阅读位置；优化 Pura X 方形外屏和短屏的标题栏、视频操作栏、评论弹窗及回复附件预览，避免控件挤压和遮挡。
- **图片查看操作**：全屏查看的控制入口沿用现有设置，去掉更多菜单中重复的保存项；大屏图片覆盖层打开和关闭时保留底层详情页及阅读位置。
- **背景显示与流畅度**：文字、互动图标和播放控件随背景及底板透明度调整对比度；普通页面复用已合成的背景纹理，减少打开页面时重复绘制，并处理切换外观或页面离开后的过期结果。
- **设置首帧与返回路径**：分类参数在页面首次绘制前传入，修复打开子页时短暂闪出上一个分类的问题；手机复用已打开的同类设置页，桌面切换分类时收起旧详情分支，减少重复入栈。
- **公告与推荐弹窗**：完善展示时间、间隔和每日次数控制，按实际展示记录次数；未取得有效配置时暂停推荐，避免异常重试或重复弹出。
- **版本信息统一**：X-new 与 Harmony-X 均更新为 3.1.0（`versionCode` 23），同步全部 21 种语言的版本说明和项目文档，各自保留应用名称、包名和图标。

### 说明

- 本轮完成 Release 构建及 217 项相关自动化回归；发布前核验 App Pack 与 HAP 内的版本、设备支持和 5 个应用分身配置。
- 自动化测试和构建检查不代表全部实机场景通过；桌面卡片冷启动、资料实际提交、视频手势以及平板和折叠屏转场仍需完整实机验收。上一版本注明的评论发送、连播和账号服务端验证边界继续适用。
- 华为账号授权与跨设备云同步仍需匹配的账号服务、证书和 Profile 完成实机验证；防窥保护依赖系统支持及应用专用授权，未授权时显示等待状态。HDR 实际亮度和增强效果以当前屏幕及系统能力为准。
- 本版提供未签名包，安装前需使用自己的 HarmonyOS 证书和 Profile 重新签名。

## English changelog

This update adds Home-screen cards, native profile editing, page backgrounds, mixed colour palettes, animation and haptic settings, and HDR effects. It also expands two-column phone and adaptive large-screen reading, with improvements to GIF viewing, photo saving, video interaction, and settings navigation. The build number is 23.

### New features

- **App clones**: Support up to five system app clones, making it easier to use separate accounts.
- **Home-screen cards**: Choose 2×2, 2×4, or 4×4 cards showing For You, Following, Trends, or Notifications. Cards follow the active account and display cached content. Tap a post to open its details, or use the gear to change the source and refresh the card.
- **Native profile editing**: Update your name, bio, location, website, avatar, and banner. Saving reloads the account profile and updates its display throughout the app. If part of a save fails, unfinished edits remain available for retry.
- **Twelve traditional colour themes**: Add cinnabar, vermilion, amber, autumn bamboo, bamboo green, azurite, cloisonne, indigo, begonia, rouge, sandalwood, and mountain palettes, with separate light and dark colours. Existing accent choices remain available.
- **Page-transition choice**: Choose the existing animation or the official style in settings. Changes apply immediately and survive restart; the existing animation remains the default. Photo and video viewers retain their own media-opening and closing transitions.
- **Double-tap video seeking**: Double-tap the right half to seek forward or the left half to seek backward. The default interval is 10 seconds, adjustable from 1 to 60 seconds, with an independent switch that leaves hold-to-speed preferences unchanged.
- **Photo author bar**: The photo viewer now shows author information, a profile shortcut, and follow controls, sharing relationship state with other pages.
- **Alternate icon**: Add a Zombie X icon option.
- **Two-column phone and adaptive feeds**: Use the existing timeline column setting to read Home in two columns on a phone. Profiles, bookmarks, browsing history, lists, communities, notification posts, search, and interaction histories adapt to the actual content-pane width with one, two, or three columns. Narrow panes return to one column, while headings and loading indicators span the full width.
- **GIF photo viewer**: Open animations from posts, chats, pending attachments, and GIF search in the shared photo viewer, with enlarged viewing and horizontal browsing. Mixed photo and GIF galleries retain their original order. Preview search results before selecting the current GIF; saving preserves native GIF files and uses the existing GIF conversion flow for video-backed animations.
- **Page backgrounds**: Combine colours, photos, complete patterns, individual motifs from different sets, and paper textures on ordinary pages. Adjust motif density, texture strength, and separate opacity levels for posts, the inbox, and other content panels. Import or share schemes with their background photo, or temporarily disable the background while retaining the saved design.
- **Shared background library**: Save post photos to a durable, account-specific library for page or chat backgrounds. Saved images survive cache cleanup, and saving the same source again reuses its existing image.
- **Ten mixed colour palettes**: Add Confetti, Sea Salt Coral, Sunset Iris, Forest Amber, Berry Mint, Morandi, Candy, Sky Lemon, Peach Mint, and Lilac Cream. Switches, navigation, and compose buttons use coordinated colours in both light and dark appearances.
- **Animation and haptics**: Choose Quick, Standard, Spring, or Reduced Motion presets, or independently adjust duration, movement, spring damping, Symbol animations, and haptic intensity. Reduced Motion skips page transitions and decorative effects while retaining previous parameters. Haptics respect system settings.
- **Liquid navigation indicator**: Add a draggable capsule to the floating bottom bar, with spring settling when tapping or dragging between tabs. Its position and size follow the actual visible tabs and label setting.
- **Component HDR and touch highlights**: Add an independent component HDR switch and brightness multiplier. The effect starts disabled, with a default multiplier of 1.25, and settings show the current screen's system-reported maximum multiplier. Buttons, icons, and selected states can use highlights; touch glows clear when a press or drag ends.
- **HDR video enhancement**: Use system HDR enhancement for ordinary videos on screens that report support. Recheck capabilities after screen changes and retain normal playback when enhancement is unavailable or fails.
- **Menu action visibility**: Manage post, photo, and video actions in their settings categories. Hide individual actions or restore defaults; preferences survive restart and are shared with the actual menus across pages.
- **Exit confirmation**: Optionally show a system confirmation when navigating back from a root page. Only an explicit Exit closes the app; an open phone sidebar closes first. Confirmation can be disabled in settings, and nested pages retain their normal back navigation.
- **Huawei account and cloud sync entry**: Add Huawei account sign-in, avatar display, and optional preference sync, grouped into appearance and navigation, reading and playback, and local content rules. Cloud sync starts disabled; X credentials, private messages, drafts, and caches remain local. Account-service and signing configuration are still required for actual use.
- **Anti-peep protection entry**: Add system setup, authorization status, and a recheck action. Returning to the app after authorization triggers another check. The system privacy mask is used only on supported devices with facial recognition configured and the app's required authorization granted.

### Improvements and fixes

- **Me account overview**: Improve the avatar, banner, and account summary, and show known profile details immediately when opening the full profile. Refreshing the overview no longer fetches both post timelines.
- **Compact timeline cards**: Refine covers, text excerpts, and spacing in narrow columns. Galleries retain the full photo sequence, while videos and GIFs continue to follow the existing autoplay preference.
- **Photo saving and long-press menu**: Saving the current photo uses the system secure Save button, preparing its gallery destination after authorization and before the download finishes. Holding a photo opens the more menu, including recognition actions. With Save to files enabled, the system Save As picker confirms a destination for each file.
- **Reduced file-access permissions**: Remove persistent file-access permission and the long-term folder-authorization entry. Existing file-save preferences are retained; canceled or failed saves leave download tasks available for retry.
- **Independent mute choices and playback handoff**: Home previews and opened videos remember separate mute choices. Temporary silence, preloading, and player handoff no longer overwrite those preferences. Related overlays follow video-control visibility.
- **Initial Home rendering and recommendations**: Show real posts before injecting promotional content or opening the startup sheet. Empty and unrequested timelines no longer use promotions as placeholders. Keep multi-column item counts synchronized to address feeds remaining blank after loading.
- **Material defaults**: Sidebar material starts disabled and sheet material starts enabled on first use. Existing independent choices are retained.
- **Storage cleanup**: Recalculate clearable cache before confirmation, retaining completion and failure feedback.
- **Video taps and preview audio**: Expand manual-play hit targets to the whole video area. Multiple preview cards can keep their pictures playing, with sound belonging only to the most recently activated card. Opened videos retain their separate mute preference.
- **Rotation, folding, and compact screens**: Preserve the visible post and within-card reading position where possible when changing columns or orientation. Refine title bars, video action rails, comment sheets, and reply attachment previews on Pura X square cover screens and short windows to reduce crowding and overlap.
- **Photo viewer controls**: Reuse the existing fullscreen setting for viewer controls and remove the duplicate Save action from the more menu. Opening and closing the large-screen photo overlay preserves the underlying detail page and reading position.
- **Background contrast and performance**: Adapt text, action icons, and playback controls to the background and panel opacity. Ordinary pages reuse composed background textures, reducing repeated work when opening pages and discarding stale results after appearance changes or page dismissal.
- **Settings first frame and back navigation**: Pass category parameters before the first frame to prevent briefly showing the previous category. Phones reuse an already open settings category; desktop category changes close the old detail branch to reduce duplicate navigation entries.
- **Announcements and recommendation sheets**: Refine display windows, intervals, and daily budgets, counting only actual presentations. Pause recommendations without valid configuration and avoid repeated sheets or excessive retries.
- **Consistent version information**: Both X-new and Harmony-X now use version 3.1.0 (`versionCode` 23), with matching version descriptions in all 21 languages and project documentation. Each keeps its own app name, bundle name, and icons.

### Notes

- This release passed its Release build and 217 relevant automated regression tests. App Pack and HAP versions, supported devices, and the five-app-clone configuration are checked before publication.
- Automated tests and builds do not establish complete device acceptance. Card cold starts, actual profile submissions, video gestures, and tablet and foldable transitions still need full device verification. The previous release's limits for comment submission, playback advance, and server-confirmed account operations still apply.
- Huawei authorization and cross-device cloud sync still require device validation with matching account-service configuration, certificates, and Profile. Anti-peep protection depends on system support and app-specific authorization, showing a pending state until granted. Actual HDR brightness and enhancement depend on the current screen and system capabilities.
- Packages are unsigned and require re-signing with your own HarmonyOS certificate and Profile before installation.

## 下载与安装 / Downloads and installation

- `HarmonyX-v3.1.0-unsigned.app.zip`：未签名 App Pack，与原始 `.app` 文件内容一致。Unsigned App Pack, identical to the original `.app` file.
- `HarmonyX-v3.1.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。Unsigned module package extracted from that App Pack.

安装前需使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。
Re-sign with your own HarmonyOS certificate and Profile before installing, using DevEco Studio or `hap-sign-tool`.

## 构建核验 / Build verification

- Release 模式，版本 3.1.0（23），包名 `com.haohaoai0.harmonx`。
- 兼容 API 23，目标 API 26；phone / tablet / 2in1。
- HAP 内已核对 `multiAppModeType: appClone`、`maxCount: 5`。
- 217 项相关回归测试全部通过；此结果不代表全部实机场景通过。
- 本次发布安装包，源码修改保留在本地。

- Release build, version 3.1.0 (23), bundle `com.haohaoai0.harmonx`.
- Compatible API 23, target API 26; phone / tablet / 2in1.
- Packaged HAP verified to contain `multiAppModeType: appClone` and `maxCount: 5`.
- All 217 relevant regression tests passed; this does not establish full device acceptance.
- This release publishes binaries; source changes remain local.

## SHA-256

```text
297765f4e968db87a82e8fb0c95e4fe43a8bb8ce49f727648af73a7c0854d94d  HarmonyX-v3.1.0-unsigned.app.zip
83ef6bbfdc3d7132afd5ec9e2c8ba9df73ea75dfba58284ccb9ce399a443b652  HarmonyX-v3.1.0-unsigned.hap
```

## Harmony X 3.0.0 · 2026-10-15

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v3.0.0)

Harmony X 3.0.0（versionCode 22），发布于 2026-10-16。

本版新增哔站式视频布局与评论弹幕、私信帖子预览卡片和可互动的 Logo 页面，重新整理设置分类，并改善页面返回、下拉刷新与悬浮按钮的使用体验。

### 新增功能

- **哔站式视频布局**：视频流的“信息流布局”新增哔站模式，提供作者与正文、互动栏、全屏播放胶囊及同帖多视频选集；保留原有视频比例、填充和背景偏好。开启自动连播时，先播放同帖下一集，再进入下一条推荐。
- **评论弹幕**：把当前帖子的真实回复作为弹幕展示，普通播放和全屏均可使用，暂停后弹幕同步暂停。弹幕遵循现有自动翻译、目标语言与排除语言设置，翻译失败显示原文；也可输入弹幕，确认服务端发布成功后加入画面。发送弹幕会公开回复原帖，评论没有视频时间戳，按播放过程轮流展示。
- **视频单击操作**：视频更多菜单及媒体设置可选择单击画面“显示/隐藏播控栏”或“暂停/播放”，默认保持原有播控栏行为，经典、抖音与哔站布局共用并记住选择。
- **私信帖子卡片**：聊天中的 X/Twitter 帖子链接及帖子分享附件可加载真实帖子预览，显示媒体、作者、时间与正文；多图按数量拼排，正文与附件中的重复链接合并，同一条消息不再重复显示纯链接。点击打开帖子，长按进入消息操作菜单；普通链接支持点击打开。
- **Logo 互动与纪念图**：从关于页的应用标志进入粒子 Logo 页面，支持长按聚合、触碰扰动、暂停动画，并可把当前账号头像加入标志。参与状态按账号保存在本机，可随时退出；支持生成纪念图，保存到图库或通过系统分享。

### 改进

- **设置重新分类**：设置首页按“账号与安全、外观与使用体验、内容与语言、数据与网络、帮助与关于”组织，具体开关进入对应子页；搜索直接定位包含选项的页面并显示分类路径，手机与桌面共用分类。
- **视频操作反馈**：哔站布局的点赞、转发、收藏与评论按钮同步真实选中状态、计数和请求中状态，胶囊补充按压反馈；全屏入口显示后自动淡出，展开评论时覆盖层同步收起。
- **关于页面**：集中展示软件介绍、版本与构建号、作者账号及项目和更新入口，品牌图标随包提供。
- **备用图标失败提示**：区分系统不支持、第三方主题冲突和分身限制，保留系统返回的失败原因，方便定位无法切换图标的问题。
- **版本信息统一**：应用版本更新为 3.0.0（`versionCode` 22），同步全部 21 种语言的界面版本标识及中英文项目文档。

### 修复

- **页面重复入栈与返回过深**：重复打开同一内容时复用已有页面；大屏从侧栏或列表切换内容时替换之前的详情分支，减少多次返回才能回到首页的问题，保留普通手机页面的正常返回路径。
- **持握手与按钮位置**：把手动选择的左右手偏好与设备检测结果分开保存；关闭自动持握手后恢复手动偏好，重启与其他页面读取设置不再覆盖刚作出的选择。
- **下拉刷新指示器**：修正手机根页面的刷新动画被标题栏材质遮住的问题，让加载指示跟随下拉和刷新状态显示。
- **设置留白与返回错页**：统一分类卡片两侧留白并让短页面顶端对齐；子页读取自身的路由参数，避免多层设置返回后显示其他分类。
- **弹幕输入避让**：调整沉浸键盘与半模态高度，保留键盘上方的输入区和发送入口。
- **喵推送入口**：暂时隐藏未完成配置的设置入口和搜索结果，保留已有配置与服务代码。

### 说明

- 本轮发布完成 Release 编译、包内版本与元数据核验，以及相关自动化回归；这些检查不代表所有设备场景均已实测。
- 哔站布局此前已在 Mate 80 Pro Max 上确认真实评论弹幕、全屏进入与返回；公开发送弹幕、多视频选集连播、各翻译服务的在线结果及平板分栏仍需对应实机验证。设置分类留白已在手机验证，桌面分栏仍待验证。
- 私信帖子预览、Logo 互动与纪念图已有逻辑回归覆盖，完整真机操作仍需补充验证。群聊添加成员的服务端确认与密钥轮换限制沿用上一版说明。
- 本版为未签名包，需用自己的 HarmonyOS 证书与 Profile 重新签名后安装。

### 下载与安装

- `HarmonyX-v3.0.0-unsigned.app.zip`：未签名 App Pack，内容与原始 `.app` 文件完全一致，以 `.app.zip` 后缀提供。
- `HarmonyX-v3.0.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。

安装前请使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。

### 版本与构建

- 版本：3.0.0（versionCode 22）
- 包名：`com.haohaoai0.harmonx`
- 兼容 API 23，目标 API 26
- 支持设备：phone / tablet / 2in1
- release 模式构建成功，App Pack 与 HAP 内的版本信息已核验。
- 本次仅上传构建产物，工作区源码改动保留在本地。

### SHA-256

```text
01d63906c5a3d11bb02317ae51c3815dc20f72ba5c6e3ffbde8fa23f9981db40  HarmonyX-v3.0.0-unsigned.app.zip
2d56932c53345eb21cfe7bbdf69a8d23cecbfb7ba91aa582578bd537179f5c34  HarmonyX-v3.0.0-unsigned.hap
```


## Harmony X 2.9.0 · 2026-10-14

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v2.9.0)

Harmony X 2.9.0（versionCode 21），发布于 2026-10-15。

本版为图片和视频的打开与返回接入一镜到底转场，新增视频长按倍速、媒体评论弹窗背景开关和群聊管理页，并修正 GIF 下载、下载目录、多视频全屏与列表接口的问题。

### 新增功能

- **视频长按倍速**：显示设置新增“长按倍速播放”，默认开启。播放中按住画面即临时升到 2 倍速，返回与更多按钮一行下方以玻璃材质胶囊显示当前倍速和“快进中”，松手恢复原速；按住时手指上下滑动可按 0.5 倍增减，范围 0.5–4 倍，低于 1 倍时胶囊显示“慢放中”，底部播控条的倍速标识同步变化。首页与个人主页的帖内视频、以及视频流都支持；关闭开关后长按恢复为左半区快退、右半区快进。
- **媒体评论弹窗背景开关**：显示设置新增“媒体评论弹窗背景”，默认开启。开启时图片、视频查看器的评论弹窗内，帖子和评论区带背景；关闭后这两块区域透明，直接透出后方的媒体画面。
- **群聊管理**：私信群聊新增群资料与管理页。可更换群头像、修改群名称与简介，切换邀请链接和“仅管理员可发言”等权限，管理管理员，添加或移除成员，为成员设置仅本机生效的昵称或直接发起私信，也可退出群聊；成员搜索与添加沿用统一的账号行卡片。

### 改进

- **版本信息统一**：应用版本更新为 2.9.0（`versionCode` 21），同步所有支持语言的界面版本标识及中英文项目文档。
- **图片与视频一镜到底**：图片和视频从时间线、帖子和聊天中打开时，从点击位置连续放大进入查看器，返回时沿原路径收回，不再有白条或黑屏过渡。视频返回直接交回原播放器，不再用截图遮挡画面，并隔离旧页面的清理动作；图片横滑列表返回后保留已有的滑动位置，不再被强制居中。
- **下载目录改用应用包名**：默认下载文件夹的目录名由应用名改为应用包名 `com.haohaoai0.harmonx`，文件管理器的“来源”区域会据此显示应用入口。
- **GIF 保存为动图**：下载 GIF 时从视频流重新编码为动图保存，不再直接存成视频；转码失败时回退保存为视频并提示“GIF 转换失败，已按视频保存”。
- **全屏图片查看**：图片查看器的黑色遮罩层延伸到系统状态栏与导航栏区域，边缘不再透出背景；系统状态栏本身不再被隐藏或顶起。

### 修复

- **多视频全屏播放**：一条帖子带多个视频时，点每个视频的全屏按钮都会播放对应的那一个，此前始终只播放第一个。
- **列表加载失败**：列表接口返回 200 且带数据时，即使同时附带非致命提示也保留数据，不再把整条响应判为失败并回退到已下线的旧接口；限流、未授权、封禁这类致命错误仍照常报错。
- **登录状态提示**：修正会话保存失败仍提示登录成功的问题。

### 说明

- 长按倍速、媒体评论弹窗背景、下载目录与 GIF 保存在 Mate 80 Pro Max 上验证；长按后上下滑动调整倍速的最终手感以真机实测为准，若仍有细节问题会在下一版继续调整。
- 群聊管理页对照 X 网页实现，添加成员仍依赖服务端确认与新的密钥轮换签名，本轮真机上尚未确认被添加的成员能成功入群。
- 列表相关改动已在设备上验证时间线渲染正常。
- 本版为未签名包，需用自己的 HarmonyOS 证书与 Profile 重新签名后安装。

### 下载与安装

- `HarmonyX-v2.9.0-unsigned.app.zip`：未签名 App Pack，内容与原始 `.app` 文件完全一致，以 `.app.zip` 后缀提供。
- `HarmonyX-v2.9.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。

安装前请使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。

### 版本与构建

- 版本：2.9.0（versionCode 21）
- 包名：`com.haohaoai0.harmonx`
- 兼容 API 23，目标 API 26
- 支持设备：phone / tablet / 2in1
- release 模式构建成功，App Pack 与 HAP 内的版本信息已核验。
- 本次仅上传构建产物，工作区源码改动保留在本地。

### SHA-256

```text
2bb55819a6de8079a70c7ccd5e2857fb3fe119bc7ee34dc699c3ac59d414c3fb  HarmonyX-v2.9.0-unsigned.app.zip
1736f781a5fdab57e58eeb1c4874d2b142026d7f45f14bf0addb85886627535c  HarmonyX-v2.9.0-unsigned.hap
```


## Harmony X 2.8.0 · 2026-10-12

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v2.8.0)

Harmony X 2.8.0（versionCode 20），发布于 2026-10-13。

本版集中完善通知与提及、视频推荐与视频流布局、发帖选项，并重做桌面与侧栏体验，同时修复聊天、图片查看器和页面转场的问题。

### 新增功能

- **本地浏览记录**：侧边菜单新增“浏览记录”子页面，仅在本机保存帖子链接表。浏览时间线时点开推文、视频流每刷到一个视频都会写入记录；列表按日期分组，显示作者、内容摘要和图片或视频缩略图，支持本地搜索、单条删除和清空，进入页面时会自动补全旧记录的摘要与缩略图。
- **发帖选项补全**：发帖工具栏补齐投票、表情、定时发布、位置、回复权限和内容披露。投票支持 2–4 个选项、每项 25 个字符、5 分钟到 7 天的时长，并可为每个选项单独配图；表情面板可搜索并插入当前光标位置；定时发布使用系统日期和时间选择器，并可查看服务端已排期的帖子；位置在打开时请求设备定位权限、获取一次真实坐标后查询附近地点，也可按关键词搜索；回复权限提供每个人、认证账号、关注的账号、仅提及的账号、关注账号及其关注账号五种；内容披露包含 AI 生成和付费合作两个独立开关。新增选项连同正文和媒体一起保存到本地草稿。
- **视频流布局切换**：视频流右上角更多弹窗新增“视频流布局”，可在原有 X 布局和抖音布局之间切换，选择保存在本机并在启动时恢复。抖音布局把头像、点赞、评论、转发、收藏和分享改为右侧竖排材质按钮，作者与正文移到左下角，底部播放控件保持不变；宽屏横屏与大屏分栏下不提供该分组。
- **桌面侧栏材质与展开样式**：桌面模式左侧栏支持玻璃、渐变模糊和关闭三种材质，强度可调五档；API 26 及以上使用系统材质，低版本使用对应的背景模糊，手机侧栏共用同一套设置。侧栏把手放大加粗，并新增展开样式子页面，提供多款预置图案，也可导入 128×128 或 256×256 像素的图片或 GIF。展开样式仅在桌面模式生效。
- **桌面侧栏自动收起**：桌面左侧栏默认不伸出，从设备左侧边缘向右滑展开、向左滑收起，点击面板外区域也会收起；滑动展开可单独关闭，关闭后仍可用把手和点击面板外区域操作。
- **回复胶囊材质开关**：显示设置新增回复胶囊材质开关，默认开启；关闭后回复的小按钮和输入框使用透明背景，正文和删除图标改用主题色与红色，胶囊外层材质保持不变。
- **通知内容排版**：普通通知按类型图标、头像、通知说明、时间和帖子摘要分层显示，提及直接显示完整的帖子卡片，可直接点赞、回复和转发。
- **备用图标**：7.0 的备用图标新增黑底、白底两款青蛙图标，并同步 21 种语言的图标名称。

### 改进

- **版本信息统一**：应用版本更新为 2.8.0（`versionCode` 20），同步所有支持语言的界面版本标识及中英文项目文档。
- **视频推荐跨次去重**：接入 X 网页的 ImmersiveMedia 视频时间线和观看会话事件，按账号与种子帖保存时间线状态；实际观看过的视频会在下次打开时排除，预加载但未观看的候选仍然保留，接口不适用时回退到原有视频接口。同一种子帖重开视频流后，首批推荐不再重复。
- **个人资料页标题栏过渡**：私信与关注按钮随资料墙一起滚动，接近标题栏时连续移入标题栏；已关注时把 Grok 和搜索收进更多菜单，并为此前的按钮补齐与“更多”一致的材质。
- **视频流画面贴合**：接近满屏的竖视频最多放大 6% 铺满播放区域，消除顶部缝隙；其他宽高比按实际可用区域取最大完整画面，不再把竖向视频统一顶端对齐。
- **视频进度条触控**：进度条加粗到 6vp，触控区域扩大到 44vp，并与倍速、静音等功能按钮留出间距。
- **大屏媒体页**：横屏视频页恢复帖子详情、互动栏、评论与回复入口，并去掉媒体画面外侧的留白。
- **帖子详情按钮**：缩小帖子详情页帖子下方的操作按钮。

### 修复

- **聊天闪退**：修正点击聊天页悬浮发起按钮时的空值闪退，无参数入口不再读取未定义的分享数据。
- **提醒页空白**：帖子通知组的请求此前被客户端的路径检查拦住，没有发到 X，进入后列表为空；现已放行该请求并接入专用通知时间线。提及页此前只筛选“全部”页已加载的通知，现改为独立的提及请求，并解析其中直接返回的帖子，被提及时可以正常显示。
- **视频放大后上滑**：无论从关注、推荐还是他人的主页放大播放，上滑都进入视频流并继续刷推荐视频，不再落到调节亮度的手势上。
- **悬浮按钮功能**：在他人主页中，首页悬浮按钮仍会发帖；现按当前页面切换为返回顶部。
- **图片查看器点赞**：修正图片查看器内点赞图标不随状态刷新的问题；“查看原图”移入更多菜单，返回、下载、更多、底部计数和回复文字接入系统材质的反色机制。
- **页面转场白条**：裁剪导航动画范围并让大屏全屏图片使用系统渐变转场，消除打开、返回和帖子详情滑入时的空白残留。
- **横屏二级页面**：横屏分栏中点击左侧帖子会替换右侧详情页，不再逐个堆叠；点开同一条帖子会复用已有详情，不再重复加载。
- **竖屏图片漏光**：处理 Pura X Max 竖屏图片详情左侧出现的光条。
- **移动端侧栏材质**：修正手机侧栏“渐变模糊”看起来和关闭材质相同的问题，旧模糊预设自带的蒙版叠加容器背景会压淡底图；关闭材质改为直接设置容器背景，避免收起动画与容器速度不一致造成的闪烁。
- **发帖工具弹层**：修正点击表情、日期、位置等工具按钮后弹层不出现的问题。

### 说明

- 新增发帖选项按 X 网页的请求契约实现，并已在真机上逐个打开弹层核对；位置已取得设备真实坐标，但当时 X 地点接口在附近没有返回可用地点，本轮也没有实际发布带投票、定时或位置的帖子，服务端是否接受仍需自行验证。
- 定位只用于查询附近地点，草稿保存选中的地点而不保存设备坐标；投票不能与普通图片、GIF 或视频同时使用，社区发帖不支持定时发布。
- 视频流布局切换和视频推荐去重已在 Mate 80 Pro Max 上验证；Pura X Max 及其他折叠设备形态、横屏与大屏分栏下的抖音布局分支、以及桌面侧栏展开样式在平板上的表现仍需对应场景的实机验证。

### 下载与安装

- `HarmonyX-v2.8.0-unsigned.app.zip`：未签名 App Pack，内容与原始 `.app` 文件完全一致，以 `.app.zip` 后缀提供。
- `HarmonyX-v2.8.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。

安装前请使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。

### 版本与构建

- 版本：2.8.0（versionCode 20）
- 包名：`com.haohaoai0.harmonx`
- 兼容 API 23，目标 API 26
- 支持设备：phone / tablet / 2in1
- release 模式构建成功，App Pack 与 HAP 内的版本信息已核验。
- 本次仅上传构建产物，工作区源码改动保留在本地。

### SHA-256

```text
8a3945036f0db6f6a80bdf85b26f71fd08a7e7a953f4a0d101bb57ca8cdc3fde  HarmonyX-v2.8.0-unsigned.app.zip
1cf43b14917934132e409b3fdcc07ecd8165de0526a2ac51489b44d6f5d619a5  HarmonyX-v2.8.0-unsigned.hap
```


## Harmony X 2.7.0 · 2026-10-11

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v2.7.0)

Harmony X 2.7.0（versionCode 19），发布于 2026-10-12。

本版重点完善视频推荐、首页刷新、通知浏览和帖子管理，并补充自定义字体、广告过滤及大屏布局选项。

### 新增功能

- **自定义应用字体**：可在显示设置中导入 TTF、OTF 或 TTC 字体，预览并应用到应用界面；选择会保存在本机，重新启动后恢复，也可随时恢复系统字体。
- **关闭广告开关**：内容过滤设置新增“关闭广告”，默认开启，隐藏 X 明确标记为广告的帖子及探索推广卡片；可关闭开关恢复显示，普通付费合作声明不作为广告过滤。
- **帖子更多菜单**：帖子卡片右上角新增原生菜单按钮，可选择“不感兴趣”、关注或取消关注、静音、屏蔽，以及将作者加入或移出自己的列表；另提供帖子互动、举报、请求社群附注和查看隐藏回复入口。
- **多帖通知列表**：铃铛及包含多条帖子的通知可打开独立的原生列表，展示对应帖子、作者与媒体，再进入具体帖子查看详情。
- **首页刷新行为设置**：双击首页和下拉刷新分别提供独立开关，默认刷新后直接显示新帖子并回顶；关闭后保留阅读位置，通过顶部新帖子胶囊查看更新。
- **桌面右侧栏开关**：桌面布局中的搜索、趋势和推荐侧栏可直接关闭，也可在显示设置中重新开启；选择持久保存，关闭后正文自动使用释放的空间。

### 改进

- **版本信息统一**：应用版本更新为 2.7.0（`versionCode` 19），同步所有支持语言的界面版本标识及中英文项目文档。
- **独立视频推荐**：从点开的帖子进入视频流，上滑使用独立的视频推荐请求与分页，排除来源列表和本次已展示的视频；加载失败时保留错误与重试入口。
- **首页推荐刷新**：按账号记录实际浏览过的帖子，刷新时提交最近的已读记录并过滤重复项；区分向前刷新与继续分页，刷新失败保留当前内容和阅读位置。
- **桌面首页列数**：支持自动及手动 1／2／3 列，自动列数按正文实际可用宽度计算，随侧栏开关和窗口尺寸变化调整。
- **标题栏与页签布局**：优化共用头像、Logo 和标题栏节点的复用；胶囊页签按内容实际宽度排列，并改善放大字体时的显示与横向滚动定位。
- **大屏媒体评论弹窗**：评论弹窗在大屏居中呈现，打开或调整高度时保持图片缩放和视频画面位置；窄窗口继续使用底部弹窗与媒体避让。
- **启动图标**：启动窗口使用独立的 144×144 图标资源。
- **图片查看器边缘**：完善黑色底面、安全区覆盖和模糊背景裁剪，处理竖屏图片详情边缘露底的问题。

### 修复

- **视频点击与连续播放**：修正开启自动播放时点击视频无法进入视频流，以及关闭首页自动播放后视频流自动切到下一条却暂停的问题；进入视频流时保留已有播放位置。
- **原有大屏布局**：恢复关闭桌面模式后的标题栏、常驻侧栏和通知页面；隐藏底栏通知入口后，仍可通过侧栏或系统通知打开对应页面。
- **分栏切换打断浏览**：大屏打开或关闭详情分栏时保留首页列表与已显示帖子的节点，减少视频重启及阅读位置丢失。
- **探索标题栏重叠**：按账号行、搜索栏和页签的实际位置计算避让，修正切换页面及放大字体后的重叠、裁切和多余留白。
- **大屏设置闪退**：修正设置分栏中的导航作用域冲突，关闭最后一个设置详情后恢复完整列表宽度。

### 说明

- “不感兴趣”在 X 提供有效反馈信息时提交服务端反馈；缺少反馈信息时仅在本机隐藏，并显示提示。举报、请求社群附注和查看隐藏回复通过 X 官方页面继续操作。
- 推荐内容由 X 返回，改进已读记录与去重不代表推荐流按发布时间排序，也不能保证每次刷新都有新内容。

### 下载与安装

- `HarmonyX-v2.7.0-unsigned.app.zip`：未签名 App Pack，内容与原始 `.app` 文件完全一致，以 `.app.zip` 后缀提供。
- `HarmonyX-v2.7.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。

安装前请使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。

### 版本与构建

- 版本：2.7.0（versionCode 19）
- 包名：`com.haohaoai0.harmonx`
- 兼容 API 23，目标 API 26
- 支持设备：phone / tablet / 2in1
- release 模式构建成功，App Pack 与 HAP 内的版本信息已核验。
- 本次仅上传构建产物，工作区源码改动保留在本地。

### SHA-256

```text
037aa008af91e60d42ca35bc8a630558c45d9e8a4cc4ac7534e3e50b3b05195e  HarmonyX-v2.7.0-unsigned.app.zip
77368d346728f0d1710dcd66f29565b1847f095c04828fd3c916e000d8437160  HarmonyX-v2.7.0-unsigned.hap
```


## Harmony X v2.6.0 · 2026-10-11

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v2.6.0)

Harmony X 2.6.0（versionCode 18），发布于 2026-10-11。

### 版本更新

- 应用版本更新为 2.6.0（versionCode 18）。
- 同步各语言界面版本标识，以及项目 README 与更新日志。
- 发布当前工程的 release 构建。

### 下载与安装

- `HarmonyX-v2.6.0-unsigned.app.zip`：未签名 App Pack，内容与原始 `.app` 文件完全一致，以 `.app.zip` 后缀提供。
- `HarmonyX-v2.6.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。

安装前请使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。

### 版本与构建

- 版本：2.6.0（versionCode 18）
- 包名：`com.haohaoai0.harmonx`
- 兼容 API 23，目标 API 26
- 支持设备：phone / tablet / 2in1
- release 模式构建成功，App Pack 与 HAP 内的版本信息已核验。
- 本次仅上传构建产物，工作区源码改动保留在本地。

### SHA-256

```text
76ed79bf6f84296a717a5a7a208a676d0d441ccc62d5071b2a32b8b13c8edefd  HarmonyX-v2.6.0-unsigned.app.zip
7b3df26f7cecc8345dc04af6a1ef05f6147dca43e059447abe8d200c5df35fc2  HarmonyX-v2.6.0-unsigned.hap
```


## Harmony X v2.5.0 · 2026-10-09

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v2.5.0)

Harmony X 2.5.0（versionCode 17），发布于 2026-10-10。

### 版本更新

- 应用版本更新为 2.5.0（versionCode 17）。
- 同步中文、英文和意大利文界面版本标识，以及项目 README 与更新日志。
- 发布当前工程的 release 构建。

### 下载与安装

- `HarmonyX-v2.5.0-unsigned.app.zip`：未签名 App Pack，内容与原始 `.app` 文件完全一致，以 `.app.zip` 后缀提供。
- `HarmonyX-v2.5.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。

安装前请使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。

### 版本与构建

- 版本：2.5.0（versionCode 17）
- 包名：`com.haohaoai0.harmonx`
- 兼容 API 23，目标 API 26
- 支持设备：phone / tablet / 2in1
- release 模式构建成功，App Pack 与 HAP 内的版本信息已核验。
- 本次仅上传构建产物，未提交或推送工作区源码改动。

### SHA-256

```text
580ef7186aca741a189272ec11d80070d57c1c5cc07fce929d820c46fb97e904  HarmonyX-v2.5.0-unsigned.app.zip
3aa03bc94c055f433c84c0e82d27d9732e2a586893bb4dc1829bbb226e27552a  HarmonyX-v2.5.0-unsigned.hap
```


## Harmony X v2.4.2 · 2026-10-07

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v2.4.2)

Harmony X 2.4.2（versionCode 16）。本版主要修复媒体查看器背景、图片重复打开与评论弹窗布局。

### 下载与安装

- `HarmonyX-v2.4.2-unsigned.app.zip`：未签名 App Pack，内容与原始 `.app` 文件完全一致，以 `.app.zip` 后缀提供。
- `HarmonyX-v2.4.2-unsigned.hap`：从该 App Pack 提取的未签名模块包。

安装前请使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。

### 本版更新

- 视频查看器使用视频封面模糊打底，图片查看器背景跟随当前图片。
- 补齐封面加载失败重试、并发请求合并与过期回调保护，封面提取复用视频播放的范围缓存。
- 每个视频页面独立管理背景，修复向回滑动时封面背景不恢复的问题。
- 图片查看器与背景独立持有解码图片，保留下载缓存；重新进入时重置关闭状态，修复之前打开过的图片再次打开不显示的问题。
- 调整视频和图片帖子评论弹窗的键盘避让，统一帖子、评论与“发现更多”区域圆角，并增加帖子底部留白。
- 同步中文、英文和意大利文界面版本标识与项目文档。

### 版本与构建

- 版本：2.4.2（versionCode 16）
- 包名：`com.haohaoai0.harmonx`
- 兼容 API 23，目标 API 26
- 支持设备：phone / tablet / 2in1
- release 模式构建成功，App Pack 与 HAP 内的版本信息已核验。
- 38 项媒体相关回归测试通过，包含图片重复打开和视频回滑背景场景。
- 本次发布仅上传构建产物，不提交或推送工作区源码改动。

### SHA-256

```text
c41370b0dd2ab3bfbf975de49cc26994cbb89567c4c01b7b997009d3b16b0acc  HarmonyX-v2.4.2-unsigned.app.zip
b2250d3c7b21579898f1772b5bee73d350f9fd8b73ebcf78736b80d85134e533  HarmonyX-v2.4.2-unsigned.hap
```


## Harmony X v2.4.0 · 2026-10-07

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v2.4.0)

Harmony X 2.4.0（versionCode 15）。本版新增原生空间界面与社区，并加入帖内投票与私信 Twemoji 表情。

### 下载与安装

- `HarmonyX-v2.4.0-unsigned.app.zip`：未签名 App Pack，内容与原始 `.app` 文件完全一致，以 `.app.zip` 后缀提供。
- `HarmonyX-v2.4.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。

安装前请使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。

### 本版更新

**空间**

- 原生空间界面：直播、预告与回放分区，支持搜索，卡片展示主持人简介与参与人数。
- 后台收听：复用现有 AVPlayer 与系统音频会话，离开房间后首页收听栏可继续收听、重新打开房间或停止播放。
- 收听页与成员列表：预览主持人与发言人，收听后展示公开成员网格；成员页支持全部、共同主持人、发言人、听众筛选。
- 准备空间：名称、录音偏好、最多三个话题与未来 14 天内的排期，草稿按账号保存在本机。
- 预告提醒：通过系统日历事件添加，默认提前 10 分钟。
- 空间悬浮按钮与更多菜单：与发帖共用悬浮按钮，保留拖动、握姿、材质与按压效果；更多菜单提供分享与按账号保存的“不感兴趣”。

**社区**

- 新增社区入口、社区列表、社区时间线与社区搜索。
- 时间线与帖子详情显示帖子所属社区，可点按跳转。

**帖子与私信**

- 帖内投票展示选项与得票情况，并可直接参与投票。
- 私信表情面板与消息气泡改用 Twemoji 素材渲染。

**改进**

- 视频信息流静音等播放设置与播放页保持一致，减少重复起播。
- 引用帖卡片与个人主页相关页面同步更新。

### 版本与构建

- 版本：2.4.0（versionCode 15）
- 包名：`com.haohaoai0.harmonx`
- 兼容 API 23，目标 API 26
- 支持设备：phone / tablet / 2in1
- release 模式构建成功，已核对 App Pack 与 HAP 内的版本信息。
- 本次发布仅上传构建产物。

### SHA-256

```text
80c7d515168f325c0fcfcdb97e15a0f1ee0fe6a6036d997da72a5205fef880c8  HarmonyX-v2.4.0-unsigned.app.zip
d309f9e3fdee96a2ddbe9ae66e0947d20315fb6c50c106e145aedf22394a67b5  HarmonyX-v2.4.0-unsigned.hap
```


## Harmony X v2.3.0 · 2026-10-06

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v2.3.0)

Harmony X 2.3.0（versionCode 14）。应用与中文、英文、意大利文界面及项目文档的版本信息已同步更新。

### 下载与安装

- `HarmonyX-v2.3.0-unsigned.app.zip`：未签名 App Pack，内容与原始 `.app` 文件完全一致，以 `.app.zip` 后缀提供。
- `HarmonyX-v2.3.0-unsigned.hap`：从该 App Pack 提取的未签名模块包。

安装前请使用自己的 HarmonyOS 证书和 Profile 重新签名，可使用 DevEco Studio 或 `hap-sign-tool`。

### 版本与构建

- 版本：2.3.0（versionCode 14）
- 包名：`com.haohaoai0.harmonx`
- 兼容 API 23，目标 API 26
- 支持设备：phone / tablet / 2in1
- release 模式构建成功，已核对 App Pack 和 HAP 内的版本信息。
- 本次发布仅上传构建产物。

### SHA-256

```text
9cdb46822b2786b4fd7de1152d2cce0e0fa4bf0d18ba3c61a1e7cd1d62160518  HarmonyX-v2.3.0-unsigned.app.zip
12a38d05b1a0487b04c373d4c862b9ea0eb8cb5694d0e53ec932f2bb127248bb  HarmonyX-v2.3.0-unsigned.hap
```

## Harmony X v2.2.0 · 2026-10-04

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v2.2.0)

### 发布产物

两个附件都是未签名包，GitHub 不允许 `.app` 扩展名的发布附件，因此同一份 App Pack 以 `.app.zip` 的扩展名提供；`.hap` 就是该 App Pack 内部打包的同一份模块包，方便直接签名安装。

- `HarmonyX-v2.2.0-unsigned.app.zip` — 未签名 App Pack（原始文件为 `HarmonyX-2.2.0.app`，解压后得到 `entry-default.hap` 等文件）。
- `HarmonyX-v2.2.0-unsigned.hap` — 从上一步 App Pack 中取出的未签名模块包。

安装前请使用自己的 HarmonyOS 证书与 Profile 重新签名，DevEco Studio 或 `hap-sign-tool` 均可。

### 版本信息

- 版本：`2.2.0`（versionCode 13）
- 包名：`com.haohaoai0.harmonx`
- 平台：HarmonyOS 6.1，兼容 API 23 / 目标 API 26
- 设备类型：phone / tablet / 2in1
- 文件大小：16,691,215 字节
- SHA-256：`70d454ff62b5fc52cdb30a6367e1548eafaaec89d6278920e14bff54565f49`

### 本版更新

2.1.0 与 2.2.0 的改动集中在私信：

- 私信支持动态照片（MovingPhoto）：图片与视频按版本化标识成对加密发送，接收端还原为可播放的动态照片卡片；不支持该协议的客户端仍按普通图片处理。
- 私信媒体附件数量对齐 X Chat 契约：图片 / GIF / 视频合计最多 10 个媒体附件，动态照片占用两个槽位。
- 私信页输入框与消息列表底部对齐，收起或展开键盘时保留最新消息的位置。
- 删除最后一个附件时不再因空附件数组导致界面异常。

更早版本的用户可见变化见仓库 `CHANGELOG.md`，其中 2.0.0 记录了首页时间线、网络 GIF 搜索、图片编辑与识别、列表管理、语音空间以及视频播放等方面的改动。


## Harmony X v1.0.0 · 2026-09-13

[下载安装包](https://github.com/haohaoai0/HarmonyX/releases/tag/v1.0.0)

# 更新日志

本文档记录 Harmony X 面向用户的版本变化。版本号与 `AppScope/app.json5` 保持一致。

## 1.0.0 — 2026-09-13

首个正式发布版本，在昨日的基础工程与身份改造上，加入以下能力：

### 新增

- 动态详情页：查看单条动态、媒体、统计信息及回复，并可从详情页发起回复。
- 可扩展的回复编辑器，支持文字、图片与 GIF 附件，并在无法发布时保留本地内容。
- 个人主页与用户详情页，支持从动态作者入口浏览资料和动态列表。
- 设置中心：可在设备本地配置 X OAuth 2.0 Client ID、切换中文/英文、跟随系统/浅色/深色主题、调整字体与主题色。
- 侧边栏和帮助中心，提供个人资料、书签等入口，以及反馈、QQ群和作者支持页面。
- 媒体动态卡片及更完整的本地示例数据。
- 首页“为你推荐 / 正在关注”切换、时间线/搜索的继续加载提示，以及动态、提及和私信的实时状态反馈。
- 面向手机、平板和二合一设备的响应式内容区；支持全屏、分屏与悬浮窗。

### 改进

- OAuth 配置改为在应用设置中保存，不再要求修改源代码或重新构建；仍使用 PKCE，绝不要求 Client Secret。
- 完善 X API v2 调用、错误状态与离线降级体验。
- 更新应用图标/品牌资源、浅色和深色主题颜色，以及中英文界面文案。
- 智感握姿状态会在窗口与页面之间保持，并持续避让系统安全区域。

### 发布产物

- GitHub Release 附带 `HarmonyX-v1.0.0-unsigned.hap`，这是未签名 HAP，仅供审阅、重签名或自行安装测试；安装前请使用自己的 HarmonyOS 证书和 Profile 签名。
