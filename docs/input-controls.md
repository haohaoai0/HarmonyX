# 鼠标、键盘和触控板

帮助中心新增「鼠标、键盘与触控板」子页。主页面快捷键和帮助说明共用 `InputShortcutCatalog.ets`，避免说明与实现不一致。

| 快捷键 | 功能 | 范围 |
| --- | --- | --- |
| Ctrl+1 / 2 / 3 / 4 / 5 | 首页 / 探索 / 通知 / 消息 / 我 | 主页面，遵循现有导航显示配置 |
| Ctrl+K | 打开搜索并聚焦搜索框 | 主页面 |
| Ctrl+N | 新建帖子；消息页新建会话 | 主页面 |
| Ctrl+R | 刷新当前页面 | 主页面 |
| Ctrl+, | 打开设置 | 主页面 |
| F1 | 打开快捷键帮助 | 主页面 |
| Tab / Shift+Tab | 向前 / 向后走焦 | 原生控件与新增可聚焦控件 |
| Enter / Space | 激活聚焦按钮 | 按钮、材质按钮、帖子卡片 |
| Ctrl+Enter | 提交 | 发帖正文、回复胶囊、聊天文字与附件说明输入框 |
| Esc / Alt+← | 返回，优先关闭面板 | 帮助、编辑、聊天、图片和视频查看器 |
| ← / → | 上一张 / 下一张 | 图片区域聚焦、未放大、未打开面板 |
| ↑ / ↓ / Page Up / Page Down | 上一个 / 下一个视频 | 视频区域聚焦、未打开面板 |
| Space / Enter；← / → | 播放或暂停；快退或快进 10 秒 | 视频画面聚焦 |

主页面快捷键在子页面、浮动侧栏、对话框和操作菜单打开时停用。菜单使用独立的输入作用域，关闭一个菜单不会提前解除另一个菜单的限制。持久侧栏不会禁用快捷键。提交与自定义按钮激活在按键抬起时执行，避免长按重复提交；普通输入与系统编辑快捷键沿用原有行为。

鼠标右键与触控板双指轻点复用图片、GIF、视频、聊天消息和会话列表的现有操作菜单。帖子卡片区域的右键复用帖子菜单，正文的右键保留原生文本菜单。材质按钮、桌面导航和帖子卡片可通过键盘聚焦并提供悬停反馈。列表沿用系统滚动，公共瀑布流显示自动滚动条，滑块保留系统拖动行为。

图片查看器保留系统横向切图和双指捏合，放大后可拖动图片；鼠标或触控板产生的滚动不会触发下拉关闭。触控板缩放没有触屏手指坐标时，以图片中心为锚点。鼠标悬停时显示上一张和下一张按钮。

验证命令：

```powershell
node --test tests/input-support.test.cjs tests/desktop-layout.test.cjs tests/media-viewer-settings.test.cjs tests/media-viewer-motion.test.cjs tests/photo-viewer-reopen.test.cjs tests/feed-media-interactions.test.cjs tests/interaction-feedback.test.cjs tests/desktop-sheet.test.cjs
devecocli build --modules entry
devecocli run --module entry --device <serial> --skip-build
```

测试覆盖输入修饰键、重复按键、菜单作用域、后台页面隔离、翻页边界、触控板缩放锚点、滚动与关闭的区分，以及全部 21 种资源目录中的帮助文案。真实外设的手感和不同触控板驱动仍需在对应设备上验收。
