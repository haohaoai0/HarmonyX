<p align="center">
  <img src="AppScope/resources/base/media/app_icon.png" width="132" alt="Harmony X 应用图标">
</p>

<h1 align="center">Harmony X</h1>

<p align="center">
  面向 HarmonyOS 的原生 X 客户端。<br>
  基于 ArkTS 与 Stage 模型，专注于沉浸、简洁且贴合设备的深色体验。
</p>

<p align="center"><a href="README.en.md">English</a></p>

<p align="center">
  <img src="https://img.shields.io/badge/HarmonyOS-API%2026-1677FF?style=flat-square" alt="HarmonyOS API 26">
  <img src="https://img.shields.io/badge/ArkTS-Stage%20%E6%A8%A1%E5%9E%8B-0B0B0D?style=flat-square" alt="ArkTS Stage 模型">
  <img src="https://img.shields.io/badge/%E5%BC%80%E6%BA%90%E8%AE%B8%E5%8F%AF-Apache--2.0-2EA44F?style=flat-square" alt="Apache-2.0 许可证">
</p>

<p align="center">
  <a href="#功能概览">功能概览</a> ·
  <a href="#界面预览">界面预览</a> ·
  <a href="#相对-opentwit-的改造">相对 OpenTwit 的改造</a> ·
  <a href="#工程配置">工程配置</a> ·
  <a href="#构建">构建</a> ·
  <a href="#上游与许可证">上游与许可证</a>
</p>

---

## 功能概览

| | |
|:--|:--|
| **完整的社交功能框架** | 首页双时间线、探索、提醒、私信、动态详情、回复编辑、个人主页、设置和悬浮发帖按钮；未登录时也可直接浏览示例内容。 |
| **原生 HarmonyOS 设计** | ArkUI 界面、HarmonyOS 系统符号、明暗主题适配，以及手机 / 平板 / 二合一设备支持。 |
| **配置后接入 X 实时能力** | 在应用设置中配置 Client ID，通过系统浏览器执行 OAuth 2.0 PKCE 授权；登录后可使用实时时间线、搜索、发帖、点赞、转发和回复。 |
| **诚实的离线降级** | X 不可访问或 API 权限受限时，应用会保留可用界面、可见的实时状态和本地回复草稿。 |

## 界面预览

<p align="center">
  <img src="docs/screenshots/home-dark.jpg" width="22.5%" alt="首页时间线">
  <img src="docs/screenshots/explore-dark.jpg" width="22.5%" alt="探索搜索">
  <img src="docs/screenshots/alerts-dark.jpg" width="22.5%" alt="提醒">
  <img src="docs/screenshots/messages-dark.jpg" width="22.5%" alt="私信">
</p>

<p align="center"><sub>首页 · 探索 · 提醒 · 私信</sub></p>

<p align="center">
  <img src="docs/screenshots/sign-in-dark.jpg" width="23%" alt="Harmony X 登录页">
  <img src="docs/screenshots/oauth-authorization-dark.jpg" width="23%" alt="系统浏览器中的 X.com 授权页">
</p>

<p align="center"><sub>Harmony X 登录页 · 系统浏览器中的 X.com 授权页</sub></p>

## 设计说明

- **实际应用图标**：页首直接使用 `AppScope/resources/base/media/app_icon.png`；已安装应用使用配套的分层资源——不透明黑色背景和透明的蓝白前景标识，均为 1024 × 1024。
- **遵循系统设计语言**：使用 HarmonyOS Sans 和系统 `SymbolGlyph` 图标；颜色通过资源文件统一管理，不在页面中硬编码。
- **多设备自适应**：面向手机、平板和二合一设备，通过 Stage 模型组织界面与状态。

## 相对 OpenTwit 的改造

Harmony X 并非仅替换外观，而是面向 HarmonyOS API 26 的 OpenTwit 改造版本，包含以下工程级变化：

- **HDS 沉浸式底栏**：以 `HdsTabs` 替代常规底部导航，使用自适应沉浸材质，并为五个主页面绑定滚动容器。
- **HDS 沉浸式标题栏**：采用 `HdsNavigation` 与沉浸式渐变模糊标题效果；头像和品牌标识作为导航内容的一部分显示。
- **智感握姿发帖按钮**：全页面可拖动的 HDS 发帖按钮会在设备支持时监听握持手变化；不支持时保留上一次可用侧别，并始终避让安全区和底栏。
- **拖动点光源交互**：按压或拖动时开启 HDS 点光源，照亮组件边框与内容；发帖按钮在拖动期间同步缩放，强化触感反馈。
- **全屏窗口与安全区处理**：`EntryAbility` 启用布局全屏，并监听系统避让区和导航指示条避让区，确保沉浸内容在刘海、圆角和手势区域仍可正常使用。
- **中文本地化**：产品名称、界面文案和状态提示均已完成 `zh_CN` 本地化，同时保留对应英文资源及中文基础资源。
- **Harmony X 身份与登录流程**：使用新的包名、分层图标、系统浏览器 OAuth 回调流程、深色视觉体系和配套说明文档。

## 工程配置

| 项目 | 当前配置 |
|:--|:--|
| 应用 | `Harmony X` · `com.haohaoai0.harmonyx` · 版本 `1.0.0`（`versionCode` 1） |
| 模块 | `entry` · Stage 模型 · `modelVersion` 5.0.0 |
| SDK 配置 | 未显式设置编译 SDK（使用本机 DevEco SDK）· 兼容 SDK `6.1.0 (API 23)` · 目标 SDK `26.0.0` |
| 设备 | `phone`、`tablet`、`2in1` · 全屏 `EntryAbility` |
| 权限 | `ohos.permission.INTERNET`、`ohos.permission.DETECT_GESTURE` |
| 构建工具 | Hvigor `6.26.4` · `@ohos/hvigor-ohos-plugin` `6.26.4` · `@ohos/hypium` `1.0.19`（开发依赖） |

## 构建

需要安装 HarmonyOS Command Line Tools（或 DevEco Studio）、JDK 17，并在 npm 配置中加入：

```ini
@ohos:registry=https://repo.harmonyos.com/npm/
```

```bash
devecocli build
```

产物路径：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

`build-profile.json5` 为本地 DevEco 签名配置，不随仓库提交。请在本机 DevEco Studio 中创建并配置证书、Profile 和口令，切勿提交到仓库。

## 启用 X 登录

1. 在 [developer.x.com](https://developer.x.com/) 创建应用。
2. 启用 **OAuth 2.0**，应用类型选择 **Native App**，并将回调地址设置为 `harmonyx://callback`。
3. 打开 Harmony X 的 **设置 > 开发者 API**，粘贴 Client ID 并保存，无需重新构建。

Harmony X 使用 PKCE，不需要 Client Secret。点击“使用 X 继续”后，应用通过 `ohos.want.action.viewData` 唤起系统浏览器；上方展示的 x.com 权限页面由 X 渲染和管理，并非由应用仿制。部分 X 接口需要付费 API 权限，应用会说明该状态并继续显示示例内容。

## 上游与许可证

Harmony X 基于 [Abhi-Flex1/OpenTwit](https://github.com/Abhi-Flex1/OpenTwit) 二次开发。仓库保留 Apache-2.0 许可证及适用的上游署名；本项目的新增内容包括应用身份、视觉系统、本地化界面、OAuth 流程、响应式 UI 优化和文档。

本项目采用 [Apache-2.0](LICENSE) 许可证。
