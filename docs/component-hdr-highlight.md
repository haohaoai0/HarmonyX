# 组件级 HDR 高光

设置入口：设置 → 外观 → 组件 HDR 提亮倍数。默认 1.25，可输入不小于 1 的小数，输入有效值后自动保存并立即生效，重启后保留；设为 1 关闭提亮，可一键恢复默认 1.25。实际倍率由设备当前能力约束，不在应用内额外限制上限。

设置页同时显示“当前屏幕最大提亮倍数”，直接读取官方 `display.getBrightnessInfo(displayId).maxHeadroom`，按两位小数显示。查询使用设置窗口所在屏幕的 ID，不固定为默认屏幕；监听亮度、屏幕信息及窗口跨屏变化，离开组件后移除本功能自己的监听。查询失败或结果无效时显示“暂时无法获取”，不使用默认倍率充当设备能力，也不持久化屏幕能力。系统明确返回 `1` 时显示 `1.00×`。

局部 UI 默认倍率也保留于 `app.float.component_hdr_highlight_ratio`。覆盖：

- 悬浮发布、回复、回顶、刷新、朗读按钮的图标和刷新指示器。
- 底部导航当前选中项，包含图标、标签及该项的未读标记。
- `AnimatedIconTabs` 当前可见的选中标签内容，涵盖胶囊和展开图标两类布局。
- 桌面导航当前选中项，以及桌面发布按钮。
- 通用 `MaterialButton` 和 `HdsButton` 的前景内容，涵盖照片/视频操作、下载、空间胶囊、新帖子提示等现有入口；禁用的 `MaterialButton` 不申请提亮。
- 首页标题栏添加关注、通知设置、时间线管理按钮，以及发帖编辑器的工具图标和可用发布按钮。
- 视频流侧边操作按钮，以及信息流（含窄列、摘要）与帖子详情中已点赞、已转发、已收藏的图标。

图标通过 `foregroundFilter`，独立内容组通过 `compositingFilter` 应用效果。每条组件路径仅应用一层；页面背景、列表正文、照片和视频不套用本滤镜。现有系统材质、颜色、触摸区域、切页及按钮行为保持原有逻辑。

通用材质按钮在材质节点内单独承载前景滤镜，不把材质背景包进提亮组。悬浮发布按钮已有图标滤镜，因此显式关闭其 `HdsButton` 宿主的提亮，避免父子叠加。

## 触摸光 HDR

`TouchHdrLight` 为按压与拖动提供独立的渐变光晕和边缘光，使用同一组件 HDR 倍率设置。它与图标、材质处于并列层，不嵌套已有 HDR 前景；原生 HDS 点光源继续承担对周边组件的照明。原生点光源的 `BRIGHT` 枚举本身不作为 HDR 亮度保证。

接入开启触摸光的 `HdsButton`（包括悬浮发布/回复/刷新/回顶/朗读入口）、聊天 PIN 数字/退格/继续键、XXAuth 推荐弹窗按钮，以及液态底栏指示器。按下或拖动期间显示，松开、取消、禁用或组件离开时清理相应状态。装饰层不接收触摸，也不加入无障碍导航。

API 24 以下或倍率设为 1 时隐藏该 HDR 光层，沿用原有交互。新增光晕与边缘颜色均提供浅色、深色资源。验证记录见 `outputs/touch-hdr-20261018/`：两分支构建通过、相关测试各 45 项通过，Harmony-X 已在 API 26 真机覆盖安装并启动。按压、拖动及取消状态已由行为测试验证；真机普通截图不作为 HDR 实际亮度或全部触摸状态的验收证明。

## 系统要求与回退

采用官方 `uiEffect.createFilter().hdrBrightnessRatio(ratio)`，从 API 24 起支持。在模块声明普通系统授权权限 `ohos.permission.HDR_BRIGHTNESS`，安装时自动授予，无需用户授权弹窗。兼容 API 23 时不访问新方法。

取消选中或倍率设为 1 时返回空滤镜，恢复普通渲染；倍率变化会换用新的滤镜，缓存的提亮滤镜不再追加效果，避免多次渲染叠加。权限或资源服务异常时返回空滤镜，并停止本进程后续的提亮申请，控件仍可使用。

倍率保存于独立的 `harmonyx_component_hdr` 偏好，与视频 HDR 设置分别保存。所有高光组件通过 `AppStorage` 观察倍率变化。无效输入不会覆盖上一次有效值，保存失败会显示提示，输入中的小数点也不会被格式化移除。设置及校验文案覆盖全部 21 个现有语言目录，并加入显示设置分类和搜索。

此能力会尝试开启 HDR 渲染管线。官方没有固定数值上限，最大提亮倍数 = 设备当前最大亮度 ÷ SDR 参考白亮度；超过上限的输入由系统按设备当前上限处理。它与视频 `HdrType.AIHDR` 相互独立，不以 `VIDEO_AIHDR` 能力作为 UI 提亮的门槛。硬件不支持 HDR 时不保证有提亮效果；普通截图也不能证明实际 HDR 亮度。

## 官方依据

- [uiEffect.hdrBrightnessRatio](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-uieffect)：API 24、权限、倍率、渲染条件及避免嵌套的约束。
- [视效设置](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-filter-effect)：前景和合成滤镜。
- [开放权限（系统授权）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/permissions-for-all)：HDR_BRIGHTNESS 为 normal / system_grant。
- [display.getBrightnessInfo 与 BrightnessInfo](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-display)：API 22 起提供 `maxHeadroom` 和亮度变化事件，查询无需额外权限。

接口已与本地 SDK 声明核对。构建、测试及设备验证结果见 `outputs/component-hdr-20261018/`；有实机证据前不宣称 HDR 视觉效果已验收。

2026-10-18 后续验证：扩大高光覆盖范围后，X-new 与 Harmony-X 最终构建均通过，两边各 87 项相关测试通过。Harmony-X 已覆盖安装并启动于 Mate 80 Pro Max（API 26）；设置布局树实测显示系统上报最大倍率 `3.50×`，保留用户已保存的 `3.5` 倍率。屏幕能力查询和界面读数已验证，HDR 实际亮度仍未做仪器或专门视觉验收；X-new 当前构建配置未签名。
