# 防窥保护接入与激活

设置入口：**设置 → 账号与安全分组 → 防窥保护**。默认关闭，用户选择保存在本地。

启用后，在应用窗口显示及每次返回前台时检查设备能力、应用受限权限和系统应用开关。检查成功后订阅系统窥视状态，并立即读取当前状态，避免进入应用时已经有人窥视却没有触发保护。

收到 `HIDE` 后，调用 `dlpAntiPeep.setAntiPeepMaskLayer(windowId)`，由系统蒙层遮盖当前主窗口，包括该窗口内的首页、私信、媒体和设置页面。每次连续窥视只请求一次蒙层，避免重复弹出；收到 `PASS` 后允许下一次窥视重新触发。系统蒙层的展示、交互和退出由系统管理，本功能不调用 `passDlpAntiPeepInfo` 放通后续检测。

退出前台、销毁或替换窗口、关闭功能时解除当前回调。异步检查、旧窗口回调和蒙层请求完成后均校验会话，避免旧操作重新激活已关闭的功能。不支持的设备、尚未授权、系统开关关闭、人脸未设置和其他接口错误分别展示状态，不会标成已激活。

## 权限获批后的配置

1. 为对应应用申请受限权限 **`ohos.permission.DLP_GET_HIDE_STATUS`**。工程的 `entry/src/main/module.json5` 已声明，运行时不能用普通用户权限弹框补授该权限。
2. 下载包含该 ACL 权限的新签名 profile，在本地 DevEco 签名配置中替换对应 profile，重新构建并签名安装。原来已经安装的包不会因为云端审批而自动获得新 profile。
3. 两个产品需要分别配置其自己的权限与签名：`X-new` 为 `com.haohaoai0.harmonx`，`Harmony-X` 为 `com.haohaoai0.harmonx`。不得混用 profile 或证书。本文不包含签名材料。
4. 在支持此能力的真机设置人脸识别，开启“系统设置 → 隐私与安全 → 防窥保护”，并允许对应应用。
5. 在应用内开启“启用防窥保护”，点击“配置系统防窥保护”可通过官方设置弹框配置应用开关。也可以在系统设置完成后返回应用，或点击“重新检测”。状态应变为“已激活，正在监测窥视状态”。之前已开启应用内开关的用户无需重新选择。

工程最低兼容 API 为 23；系统蒙层自 API 21 提供，设置弹框自 API 23 提供，调用前仍检查 `SystemCapability.Security.DlpAntiPeep`。设备本身还必须支持系统防窥能力。应用只接收系统的 `PASS/HIDE` 状态，不采集、保存或上传人脸图像。

若当前签名 profile 尚不包含该受限权限，运行时会显示等待授权；如果设备安装校验直接拒绝该权限，需先按上述步骤更换获批 profile。不能以修改权限检测、模拟成功或卸载用户数据绕过。

## 验证

- `node --test tests/anti-peep.test.cjs`：覆盖授权前后切换、持久化、前后台与窗口生命周期、过期异步操作、蒙层失败及去重。
- `devecocli build`：检查 ArkTS 编译、资源和打包。
- 真实防窥验收必须使用已获批 profile 和支持设备：分别确认单独使用为 `PASS`，机主与非机主同时注视为 `HIDE`，系统蒙层覆盖私信/媒体/弹层，以及退出后台、关闭功能、再次窥视与锁屏解锁的行为。单元测试不能替代这一项。

实现接口依据用户提供的 `AntiPeep-master.zip` 示例，并核对官方 [DlpAntiPeep API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/devicesecurity-dlpantipeep-api)、[防窥保护指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/devicesecurity-dlpantipeep)和[受限权限申请](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/declare-permissions-in-acl)。
