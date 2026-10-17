# 半模态弹层材质

入口：设置 → 显示 → 半模态弹层材质。

默认关闭，关闭后保留每个弹层原来的背景、模糊或材质。开启后，HarmonyOS 7 / API 26 使用 `SheetOptions.systemMaterial` 原生沉浸材质；低于 API 26 使用 `SheetOptions.blurStyle` 系统弹窗模糊材质。两种模式均可选极薄、薄、常规、厚、极厚五档。初始厚度为常规，开关与厚度独立持久化，关闭后再次开启会保留上次选择。低版本也能开启材质和选择厚度；关闭后恢复各弹层原样式。

材质直接挂在原生半模态容器上。每处绑定显式读取全局设置，保留高度、拖动档位、圆角、蒙层、键盘行为和关闭回调。搜索筛选与内嵌评论内容的整面背景随开关切换；引导页开启时去掉内层固定材质和模糊，避免叠加。图片菜单文字随材质开启切换到主题文字颜色。

| 页面或组件 | 已接入的弹层 | 绑定数 |
| --- | --- | ---: |
| Index | 桌面高级搜索、空间预览、登录、私信解锁、中秋祝福、引导、暂停话题、关注排序、链接预览、搜索筛选 | 10 |
| DmConversation / DmSettings | 表情、转发、联系人号码、PIN | 5 |
| UserDetail | 列表选择、通知设置 | 2 |
| PhotoViewer | 帖子评论、更多菜单 | 2 |
| VideoFeedViewer | 弹幕、帖子评论、更多菜单 | 3 |
| PostDetail | 普通与内嵌布局中的回复排序 | 2 |
| Communities / CommunityTimeline | 发帖、操作菜单 | 2 |
| ComposerTools / PostOverflowButton / PostPresentationCard | 编辑工具、帖子菜单、社区笔记 | 3 |
| LogoUniverse | 图标预览 | 1 |
| 合计 | 全部 `bindSheet` | 30 |

验证：`devecocli build --modules entry --build-mode debug` 编译和签名打包通过；绑定覆盖 30/30；21 个语言目录的低版本说明已更新。默认值、存储恢复、关闭保留厚度、非法值恢复和 API 兼容分支通过本地逻辑验证。

PaperTalk 与 HarmonyX 使用相同的五档组件背板模糊枚举。实际材质效果需在对应项目的设备构建上验证。设备验证需覆盖开关关闭/开启、五档切换、浅色/深色主题、图片和视频评论、搜索筛选、PIN 键盘以及弹层拖动与关闭。
