# DNS over HTTPS

使用入口：设置 → 数据与网络 → DNS over HTTPS（DoH）。内置阿里 DNS、Cloudflare 和 Google，也可选择「自定义」填写受信任的 HTTPS 解析地址；测试成功后开启开关并保存。默认关闭，已有地址继续保留并识别为对应服务商或自定义。3.6.0 不再内置社区实例地址，但保留通用 ECH 支持。已打开的内置网页需要重新加载。

## DoH 与 ECH 的接入方式

支持的解析服务可同时提供 A/AAAA 地址和 HTTPS DNS 记录中的 ECH 配置。旧实现只给系统 HTTP 设置 `dnsOverHttps`，DNS 查询成功，但在验证网络环境下 TLS 被重置（平台 2300999 / curl 35 / osErr 104）。新实现读取 A/AAAA 与 HTTPS 记录，并使用 rustls 执行带 ECH 的 TLS 握手；是否可连接仍取决于服务返回的记录和当前网络。

- `DohHttpRequest.ets` 统一包装请求。启用 DoH 且显式直连（`usingProxy: false`）时，HTTPS 使用 `libharmonyx_doh.so`。X API、Web API、图片、头像、GIF、翻译、媒体下载、HLS 清单和视频分段共用此入口。
- 开启 DoH 后，图片使用应用 HTTP 下载和缓存，视频使用现有分段流或文件下载路径，再交给系统播放器解码。播放器本身没有新增 DNS/TLS 功能。
- 原生模块使用 RFC 8484 DNS 报文、HTTPS RR 的 ECH 配置、rustls 与 WebPKI 根证书验证；缓存遵守 TTL（最多 300 秒）。不关闭证书验证，不中转账号请求，不在目标域名解析失败时回退系统 DNS。DoH 服务自己的域名仍需系统解析以建立连接。
- 关闭 DoH、应用 HTTP/SOCKS 代理、自定义证书或 multipart 请求继续使用系统 HTTP。代理服务器的目标域名解析由代理决定；这类请求不承诺 ECH。独立原生聊天传输、系统 OAuth 页面、外部应用未通过此包装器验证。
- ArkWeb 仍使用官方 `setHttpDns(SECURE_ONLY, endpoint)`，依赖设备 Web 引擎能力；本轮未验收重新登录流程。
- 请求取消、流式分块和进度事件、响应体上限、超时、跨域重定向凭据剥离均由原生传输处理。不会自动重放已发送的写请求。原生计时只报告实际总耗时；无法取得的 DNS/TLS 子计时为 -1。

## 两个测试按钮

「测试 DNS 解析」向当前端点发送无账号信息的 `application/dns-message` POST，校验 DNS 状态、问题和完整 A 回答。HTTP 200、HTML、NXDOMAIN、截断报文不算解析成功。

「测试 X 原生连接」通过同一 DoH/ECH 原生模块请求公开的 `https://x.com/robots.txt`，要求 HTTP 200 且包含 robots 的 User-agent 字段。不携带账号信息、不使用应用代理、不保存或启用配置，仍受系统 VPN 影响。此按钮只证明公开连接可用；下面的时间线、图片和视频证据来自实际应用操作。

## 2026-10-27 设备验收（移除预设前的构建）

HUAWEI MatePad Pro（API 26）上，Harmony X 覆盖安装并启动成功：

- 当时手动选用的社区实例 X 连接测试成功，1498 ms；此结果不代表其他解析服务均可连接。
- 开启并保存后，离开设置再进入，开关、预设及 URL 保持正确；强制停止并重启后配置仍生效。
- 关注及推荐时间线加载当前帖子，头像与帖子图片正常显示。实际请求日志包含 `status=200 ech=true`。
- 新视频加载产生连续 `status=206 ech=true stream=true`，分段服务确认完整区间，播放器收到 `native video frame` / `video first frame`。视频查看器实际显示播放画面，进度推进。证据见 `tablet-video-all-follow.log` 与 `tablet-video-live.jpeg`。
- 最终 HAP 覆盖安装后再次验证：新进程 52847 收到视频首帧（1342 ms），分段流连续成功，见 `tablet-final-video-runtime.log`。Harmony X 的 493 项相关回归及 5 项 Rust 测试通过；Croak-X 的 483 项相关测试通过（含补齐既有测试加载器后的定向复测）。两个版本构建、签名、摘要及 profile 包名校验通过。

记录位于 `.codex/doh-linuxdo-20261027/`。Croak-X 同步功能实现并独立构建；该平板已有 Croak-X 的签名与本地配置不一致，覆盖安装返回 9568332。保留旧应用数据，没有卸载；Croak-X 的设备验收单独列为未完成。

最终 HAP SHA-256：Harmony X `7B6289B93519EE97717B64E2D9B0F15A8BD12D56D2310A163F89F3BBC2F868E9`；Croak-X `6E088A79C42354E04DBA7BAA35606D4030F513A538313794EAE455AC5C03E7C2`。

原生模块的构建及边界见 [`native/doh/README.md`](../native/doh/README.md)。关闭并保存 DoH 可恢复系统请求路径；已缓存的数据及进行中的请求不会立即重新解析。

参考：[服务作者](https://github.com/1molchuan/edge-smart-doh)、[RFC 8484](https://www.rfc-editor.org/rfc/rfc8484)、[HarmonyOS HTTP](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-http#httprequestoptions)、[rustls ECH](https://docs.rs/rustls/latest/rustls/client/struct.EchConfig.html)。
