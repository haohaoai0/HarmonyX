# 华为账号与偏好云同步

设置首页右侧使用 HDS 原生标题栏菜单按钮。未登录显示用户 Symbol；登录后使用华为头像的本地圆形缓存。手机设置页和大屏设置宿主共用账号服务及同一弹窗，弹窗通过既有 `sheetMaterialOptions` 继承窗口呈现和五档材质设置。

## 应用配置

Harmony X：`com.haohaoai0.harmonx`，用户确认的应用 Client ID 为 `6917619309138960961`，配置在 entry 模块的 `metadata.client_id`。`AppScope/app.json5` 开启 `cloudFileSyncEnabled`。

HarmonyX 的功能代码相同，Client ID 必须按其自身应用身份配置；不得套用 Harmony X 或 PaperTalk 的应用配置。客户端不需要也不能写入 Client Secret。AGC 中还需确认当前安装包的签名证书 SHA-256 指纹、账号服务与昵称头像权限。

登录使用 Account Kit 的 `profile` 授权、随机 state 和 PS256。账号状态缓存启动时须经 `getHuaweiIDState` 复核。应用退出、系统账号退出和换号会清理账号展示并取消旧同步任务；不会退出 X 账号。

## 同步行为

- 初次安装默认关闭云同步。登录与开启同步分别操作。
- 三项独立范围：外观与导航、阅读与播放、本地内容规则。至少保留一项。
- 字段清单以 `CloudSettingsRepository.CLOUD_SETTING_FIELDS` 为准，采用有类型的字段白名单。不会导出整个 Preferences、Cookie、Token、私信、草稿、缓存、API Key、代理配置或本地文件路径。
- 每台设备使用独立快照文件，字段带逻辑修订号和来源设备；合并按修订号、设备 ID 稳定决胜，保持幂等。关键词和用户过滤文本目前按整个字段合并。
- 首先等待云传输并验证已有快照，再合并与写入。占位文件需完成下载，损坏、账号不符或新版本数据会阻止覆盖。
- 本地保存、等待上传、下载/合并中、上传中和成功状态分开。只在传输完成并确认文件上传状态后记录成功时间。
- 本地偏好修改防抖 5 秒；主动传输限频 15 秒，失败后延迟重试，前台定期检查。系统网络、电量、温度和存储策略仍可能暂停传输。
- 关闭开关后停止新云目录写入及应用自动导入；历史已交给系统的传输不宣称可撤回。已有云文件和本地偏好保留。
- 退出或系统换号使用会话版本拦截旧异步结果。换为不同华为账号时默认暂停，并在弹窗说明再次开启会将所选本地配置合并到新账号。
- 各范围与总开关保存在设备本地，按华为账号隔离。部分主题/字体设置按既有应用行为在重启后完整生效。

## 关键文件

- `HuaweiAccountService.ets`：独立华为会话，精确监听、清理、前台复核。
- `HuaweiAccountAvatar.ets`：不记录个人信息的头像请求、本地圆形缓存。
- `CloudSettingsRepository.ets`：白名单、值校验、字段版本和偏好应用。
- `HuaweiCloudSyncService.ets`：FileSync/CloudFileCache、生命周期、传输确认和隔离。
- `HuaweiAccountSheet.ets`：登录、退出、同步范围、状态与立即同步。

## 验证

专项运行：`node --test tests/huawei-account-cloud.test.cjs`。覆盖合并、白名单、首次默认值、错误载荷、上传确认、关闭状态、退出中的旧异步结果和授权 state 校验。

构建使用 `devecocli build`，部署使用 `devecocli run --module entry --device <serial> --skip-build`。真机授权、头像显示及同华为账号双设备同步需分别验证；单元测试、编译或安装成功不等于账号和云服务验收完成。

当前新增字符串覆盖所有已有语言目录；简体、繁体和英语提供对应文本，其余语言先使用英语回退。

### 2026-10-18 本机接入检查

Harmony X 已成功构建、安装、启动，真机已检查标题栏用户 Symbol、点击打开原生弹窗和授权失败反馈。X-new 也已构建成功，但其工作树当前没有签名配置，产物未签名。

真实登录返回 `1001502003`。已确认 Client ID 进入最终打包的 `module.json`；现用签名 Profile 的 bundle-name 为 Harmony X，但 app-identifier 是 `6918745197290122431`，与用户确认的 Harmony X AppID 不同。本机 Downloads/CXdDebug.p7b 的 app-identifier 为正确的 `6917619309138960961`，但其开发证书公钥与当前工程签名密钥不匹配，不能直接替换。需使用与该 Profile 配套的密钥库和证书后重签，再继续真实授权与双设备同步验收。

## 官方依据

- [Account Kit API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/account-api-authentication)
- [Client ID 配置](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/account-client-id)
- [端云文件协同适配指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-cloud-sync-filesync)
