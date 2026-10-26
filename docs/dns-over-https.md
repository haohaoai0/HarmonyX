# DNS over HTTPS

设置的「数据与网络」分组新增 DNS over HTTPS（DoH）入口，可选择阿里云公共 DNS、Cloudflare、Google Public DNS，或填写完整的 RFC 8484 HTTPS 地址。默认关闭，点击保存后生效。

- 使用 `http.HttpRequestOptions.dnsOverHttps` 配置原生 HTTP 请求，使用 ArkWeb `setHttpDns(SECURE_ONLY, endpoint)` 配置内置网页。
- 在代理统一配置入口应用 DoH，覆盖 X API、Web API、翻译、媒体下载、HLS 清单和视频分段请求；系统 VPN 分支和视频 CDN 专用代理分支也保留 DoH 参数。
- 开启 DoH 后，帖子图片、头像和 GIF 使用现有 HTTP 下载及缓存路径，避免 ArkUI Image 自行解析。视频原生 URL 的下载回退也使用此通道。
- 已有缓存及进行中的请求不会重新解析。已打开的网页需要重新加载。代理服务器代解析目标域名时，以代理的 DNS 为准。系统播放器、独立原生聊天传输及外部应用不保证使用此配置。DoH 服务自身域名仍需要系统解析以建立 HTTPS 连接。
- 不自动回退到普通系统 DNS；关闭并保存可恢复系统解析。没有修改证书校验或系统 DNS 设置，也没有新增权限和依赖。
- 测试按钮直接向当前端点发送无账号信息的 `application/dns-message` POST，解析 x.com 的 A 记录，校验 DNS 状态、问题和完整回答；HTTP 200、HTML 页面、NXDOMAIN 和截断报文不会被当作成功。测试绕过应用代理，仍受系统 VPN 影响，不保存配置。

API 依据：[HarmonyOS HTTP](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http#httprequestoptions)、本地 SDK 的 `@ohos.web.webview.d.ts`，以及 [RFC 8484](https://www.rfc-editor.org/rfc/rfc8484)。

## 验证（2026-10-26）

- 98 项 DNS、媒体生命周期、GIF、头像、视频分段及网络测试通过，另外 1 项本地图片绕过 HTTP 的测试通过。21 套语言资源均包含全部新增键。
- `devecocli build` 成功；产品绑定 signingConfig；签名、摘要及 profile 包名校验通过。最终 HAP SHA-256：`629F07EAD6789C7AAA25C8BE4CCA6712373D72F30ADB26D93040EE9D568C038E`。
- Mate 80 Pro Max 安装、启动及启动后进程存活通过；设置页实际显示；默认关闭状态下直接测试阿里云 DoH，x.com 解析成功，165 ms。没有在设备上验证开启后的所有媒体和网页请求；持久化、关闭和失效配置行为由自动测试覆盖。
- 扩大检查时，`chat-local-viewer-services.test.cjs` 的本地视频保存测试因 mock 缺少 `beginLocalVideoSave` 失败；该代码路径未被本次改动修改。完整测试记录保留于 `.codex/doh/`。
