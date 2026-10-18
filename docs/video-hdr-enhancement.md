# 视频 HDR 增强

设置位置：设置 → 视频播放 → HDR 视频增强。默认开启，保存至媒体偏好；关闭后即时恢复默认渲染。X-new 与 Harmony-X 使用相同实现。

## 播放与回退

- 使用官方 XComponent `hdrBrightness(1, HdrType.AIHDR)`，由系统对普通视频进行动态范围扩展。保留原有 AVPlayer、Surface、声音、进度、播放器交接和画中画逻辑。
- 播放器的内嵌与全屏两个 `SURFACE` 均接入，聊天视频也复用同一播放器。GIF 不申请增强。
- 仅在 API 24 及以上且当前窗口所在显示屏的 `hdrFormats` 明确包含 `VIDEO_AIHDR` 时申请增强。只有 HLG、HDR10 或 HDR Vivid 能力不代表支持 AI HDR。
- 老系统跳过新接口；关闭开关、显示屏不支持、显示屏查询失败均使用默认渲染。增强属性调用抛错时尝试恢复 `HdrType.DEFAULT`，不改变播放器的播放状态。
- 亮度参数保持 `1`，关闭增强不会压制原生 HDR 片源的显示亮度。
- 能力只存于 AppStorage，不持久化。窗口跨屏、显示屏变化和前台恢复时重新检查；窗口销毁移除本功能注册的监听。
- 设置文案已覆盖现有全部 21 个语言资源目录，并加入设置搜索目录。

该播放增强采用 API 24 的 AI HDR 渲染能力，而非 C/C++ VideoProcessing SDR→HLG 转换，后者的 300～3000 像素限制不作为此功能的筛选条件。无需额外权限、Native 库或网络服务。

## 官方依据

- [XComponent hdrBrightness 与 HdrType](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-xcomponent)：AIHDR 使用 AI 算法对非 HDR 内容进行动态范围扩展；设置前须查询显示屏 HDR 格式。
- [HDR 能力枚举](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-hdrcapability)：`VIDEO_AIHDR` 起始版本为 API 24。
- [Display](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-display)：按窗口的 displayId 查询屏幕与 hdrFormats。

接口也已与本机 API 26 SDK 声明核对。API 26 VideoProcessor 状态通知不是开启此增强的前提，因此不引入该模块的运行时依赖。

## 验证

`tests/video-hdr-enhancement.test.cjs` 执行真实服务与 modifier 代码，覆盖 API 23/24/26、支持与不支持屏幕、跨屏变化、查询异常、关闭与调用失败回退、清理监听、偏好持久化，以及两个视频 Surface 和全部语言资源接线。

本次构建、回归与设备检查记录保存在 `outputs/video-hdr-20261018/`。屏幕能力与属性接线的验证不等于 HDR 视觉画质验收；普通截图无法完整呈现 HDR 亮度。

2026-10-18 验证结果：

- Harmony-X 与 X-new 均 `BUILD SUCCESSFUL`。
- Harmony-X 播放器相关回归 63/63 通过；X-new HDR、设置目录、信息流布局、媒体设置回归 30/30 通过。
- 本次涉及的 6 个 ETS 文件、新增测试、本文档在两份工作区文本一致；新增 HDR 文案在全部 21 个语言资源目录一致。原有修改保留。
- Harmony-X 已通过 `devecocli run --skip-build` 覆盖安装并启动。Mate 80 Pro Max（API 26）显示屏上报 `hdrFormats=1,2,3`，`supported=false`，因此保持普通播放。真机可播放视频，布局树可见新开关及默认开启状态。
- X-new 安装尝试被 CLI 拒绝：产物未签名，未进行卸载或清除数据。
- 支持 AI HDR 的正向判断、切换与异常恢复已通过行为测试；没有可验证增强画质的 AI HDR 显示设备，因此没有声称真机 HDR 效果已验收。
