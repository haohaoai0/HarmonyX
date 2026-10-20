# AR Engine 眼动翻页

入口：设置 → 眼动翻页；长线程阅读（包括离线副本）和文章阅读页 → 开始眼动。默认关闭，不自动开启相机。点击开始后会记住启用状态，但每次进入页面仍需主动开始。设置中关闭后会停止当前会话。

授权相机后，保持头部稳定，正视屏幕中心约 1.4 秒。校准进度完成后继续正视约 0.3 秒，再向上／向下看并停留，分别向上／向下滚动可见阅读区域的 60%。每次触发后必须先回正；一直看向同一方向不会重复翻页。默认停留 0.9 秒，可在设置调整为 0.6–2 秒。方向幅度阈值可调整为 0.12–0.5，数值越大越不容易触发。

触摸、键盘和滚动输入打断注视计时，并暂缓眼动。眨眼、侧视、两眼方向不一致、无有效跟踪或丢帧也会取消待触发操作。长时间失去人脸后需要重新校准。可随时点停止或重新校准。

离开阅读页、页面被另一页覆盖、应用进入后台、输入模态层打开或组件卸载都会停用相机。返回后手动开始，不自动重新申请权限或恢复拍摄。多个阅读窗格共用一个原生会话所有者，初始化、取消和销毁按顺序执行。

使用官方 `@kit.AREngine` 的 FACE 模式、前置相机和 `ARFace.getBlendShapes()`；按 `ARBlendShapes.getTypes()` 匹配 `LEFT/RIGHT_EYEBALL_UP/DOWN/LEFT/RIGHT` 与闭眼权重，不能假定数组顺序。每次采样释放微表情、人脸和帧对象，结束时销毁会话和场景。采样不超过约 12 次/秒。仅在内存中处理方向参数，不保存、上传画面或人脸参数。预览用于确认相机已启动与面部位置。

设备必须支持 AR Engine 的 FACE 特性（API 23 起，运行时检查）。不支持的设备显示说明并保留触摸与键盘阅读。声明 CAMERA、GYROSCOPE、ACCELEROMETER，其中相机在主动开始时请求。

参考官方 [人脸跟踪 ArkTS 指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arengine-face) 和 [AR Engine API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arengine-api-arengine)。用户提供的[阅读器文章](https://developer.huawei.com/consumer/cn/blog/topic/03213294649993106)用于交互参考；其 `getPupilPosition()`、`getGazeDirection()` 不属于当前 SDK 的公开 ARFace 接口。此实现只做方向操作，不宣称获得精确屏幕注视点，也不包含该文章的疲劳评估、手势批注和模拟阅读状态。

验证：`node --test tests/eye-reading.test.cjs tests/settings-catalog.test.cjs tests/reading-modes.test.cjs`，并分别执行两个分支的 `devecocli build --modules entry`。测试覆盖校准、停留、回正重置、左右眼异常、眨眼、丢帧、手动输入、原生资源释放、会话所有权和异步取消。真实眼动精度与舒适度需由使用者在支持的真机上验证；编译、安装与界面截图不能代替眼动验收。
