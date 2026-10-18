# 动画与触感

入口：设置 → 显示 → 动画与触感。也可在设置搜索“动画”“阻尼”或“触感”。

预置方案支持一键应用并预览，修改任一参数后自动识别为“自定义”。方案不改变触感开关或强度。

| 方案 | 时长 | 幅度 | 阻尼 | 效果 |
| --- | --- | --- | --- | --- |
| 轻快 | 175 ms | 60% | 1.00 | 短促、平稳 |
| 标准 | 300 ms | 100% | 0.82 | 日常均衡 |
| 柔弹 | 450 ms | 120% | 0.60 | 更明显的回弹 |
| 低动态 | 保留 | 保留 | 保留 | 开启降低动画，暂停装饰动效 |

| 参数 | 范围 | 行为 |
| --- | --- | --- |
| 动画持续时间 | 100–700 ms，默认 300 ms | 应用动效基准时长；按按钮、页面等原有节奏成比例调整 |
| 动画运动幅度 | 0–150%，默认 100% | 装饰性缩放、旋转；0% 停止相关效果，不改变真实手势和图片缩放范围 |
| 动画弹性阻尼 | 0.50–1.00，默认 0.82 | 越低回弹越明显，越高越平稳 |
| 降低动画效果 | 默认关闭 | 禁止普通页面转场，关闭接入交互的装饰性缩放、位移及 Symbol 动效；保留原有参数 |
| Symbol 图标动效 | 默认开启 | 导航选择、通用 HDS 按钮、视频操作与详情操作触发一次原生弹跳，不循环播放 |
| 触感反馈 | 默认开启 | 底部导航、设置入口与开关、通用按钮及原有点赞、收藏、媒体操作 |
| 触感反馈强度 | 1–100%，默认 60% | 对支持调节的系统预置效果生效；其他设备使用短触摸振动 |

预览左侧展示原生 Symbol 动效，右侧展示可调参数的应用弹簧动画。拖动后松开滑块自动保存并播放预览。
系统 Symbol 没有开放时长、幅度、阻尼参数，保留系统动效节奏，以独立开关控制。
媒体开合动画遵循持续时间与弹性阻尼；几何边界保持精确，不将装饰性幅度乘到媒体目标尺寸上。
普通系统页面转场采用系统参数；“官方转场”自定义配对效果接入持续时间、幅度与阻尼。

## 实现依据

- [官方动画使用指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-animation-usage-guide)：状态驱动动画，变换和透明度优先，不在逐帧动画中改变布局尺寸。
- [曲线 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-curve)：`springMotion` 自行计算时长，`springCurve` 遵循 `duration`，因此可调应用动画使用 `springCurve(0, 1, 225, 30 × 阻尼比)`。
- [SymbolGlyph](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-symbolglyph)：数字触发器只在操作后递增，初始为 -1；降低动画时改用空 SymbolEffect。
- [振动 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-vibrator)：查询并缓存系统预置效果支持情况，采用 `usage: 'touch'` 遵循系统触感开关；失败不影响业务操作。
- [Navigation](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-navigation)：`NavPathStack.disableAnimation` 控制普通导航及桌面设置内层导航。

触感服务以 80 ms 窗口合并同一次点击在通用按钮和业务回调中的重复请求。能力查询完成后再次检查开关、请求序号和时效，避免迟到的反馈。
参数写入成功后才发布至 AppStorage，启动时恢复；所有字段进入现有外观云同步白名单。
