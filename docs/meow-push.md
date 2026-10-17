# Harmony X 的 MeoW 离线私信推送

入口：**设置 → 通知 → MeoW 离线私信推送**。

采用与 Petrelgram 相同的中转思路：

```text
Harmony X（手机）──注册 Web Push 地址──▶ X
                                         │
                                   Web Push 加密载荷
                                         ▼
                               自建 HTTPS 中转（常驻）
                                         │
                                   MeoW 官方接口
                                         ▼
                                  手机上的 MeoW
```

本机无需常驻接收进程。中转必须常驻，并能接收 X 发来的公网 HTTPS 请求、访问 MeoW。
MeoW 的通知属于 MeoW 应用；不会变成 Harmony X 自身的原生推送。
这不是让手机轮询后调用 MeoW 的转发开关。

## 目前验证到哪一步

- HarmonyOS ArkTS 编译、HAP 打包和签名通过。
- 客户端绑定流程、账号隔离、注销失败恢复有本地测试。
- 中转的 `aes128gcm` / `aesgcm` 解密、持久化、去重、限流重试和删除有 HTTP 集成测试。
- **尚未部署公网中转，尚未验证真实 X 私信 → MeoW → 鸿蒙设备的完整链路。**
  本地测试使用生成的加密 Web Push 载荷与模拟 MeoW 接口，不会向真实昵称发送消息。
- X 接口不是稳定的开发者公开推送 API。当前注册请求参考可核查的客户端实现；
  X 是否接受自建地址、是否为当前账号/XChat 会话实际发出推送，仍需在线验证。
  注册成功和测试通知成功均不等于离线私信已经验证。

## 部署中转

运行环境：Node.js 20 或以上、一个公网域名和有效 HTTPS 证书。
服务与原有 X 网关分开启动；无需启动网关或向服务器导入 X Cookie。

在 `server` 目录执行：

```powershell
npm ci
# 用安全随机数生成独立令牌；将输出保存在你的部署配置与 App 设置中。
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
$env:PUSH_PUBLIC_BASE = 'https://push.example.com'
$env:PUSH_RELAY_TOKEN = '<上一步生成的令牌>'
$env:PUSH_HOST = '127.0.0.1'
$env:PUSH_PORT = '8788'
npm run start:push
```

将域名替换为实际域名。`PUSH_PUBLIC_BASE` 只填 origin，不包含路径或查询参数。
通过系统服务或进程管理器保持运行。中转默认只监听回环地址，由 HTTPS 反向代理对外服务。

例如 Caddy：

```caddyfile
push.example.com {
    reverse_proxy 127.0.0.1:8788
}
```

反向代理必须保留二进制请求体和 `Content-Encoding`、`Encryption`、`Crypto-Key` 请求头。
不要在 `/push/*` 前添加登录页或网关 Bearer 验证；推送地址本身是随机能力地址，载荷还需要通过解密认证。
不要记录 `/push/*` 完整路径、请求体或管理接口 Authorization。管理接口自身校验令牌。
`GET /health` 返回服务状态，但不能证明 X 或 MeoW 链路正常。

也可以使用 `server/push.Dockerfile` 构建镜像；将 `/data` 挂载为持久卷，设置
`PUSH_STORE_FILE=/data/subscriptions.local.json`、`PUSH_HOST=0.0.0.0`，并通过 HTTPS 代理暴露。
管理令牌针对自己掌控的中转配置，不是放进公开 HAP 的公共服务凭据。

## 手机端绑定和验收

1. 安装并打开 MeoW，完成其账号和系统通知设置，确认昵称。
2. 在 Harmony X 中通过 X 网页登录目标账号，进入通知设置。
3. 填写中转 HTTPS 地址、访问令牌、MeoW 昵称。消息预览默认关闭。
4. 点击“发送 MeoW 验证码”，在 5 分钟内填入收到的 6 位验证码并确认。
5. App 从中转取得 Web Push 公钥材料，在手机上向 X 注册并保存“仅私信”偏好，
   两步成功后启用中转。失败时保留配置，允许继续注册或解除绑定。
6. “发送测试通知”只验证中转 → MeoW；请在手机上确认收到。
7. 让另一账号发送真实私信，分别验证前台、锁屏、关闭 Harmony X 后的接收。
   “检查真实投递状态”显示真实 Web Push 转交 MeoW 的时间，不会被测试通知更新。

若注册后始终没有真实投递，核对 X 的私信推送设置、会话静音、账号状态、域名可达性、
反向代理请求头和中转持久卷。若 X 当前不向该地址发送，不应将测试成功视为已修复。
若 Web Push 内容本身没有明文预览（如加密聊天），展示通用新消息提示。

## 账号、隐私和停用

- 绑定与密钥按本地账号独立保存。切换账号不会把之前账号的异步响应写入新账号。
- X Cookie、登录凭据、聊天 PIN 和恢复密钥不会上传到中转。
- 中转持有 Web Push 解密私钥，能够读取 X 的推送摘要。关闭预览后，转交 MeoW 和
  持久化队列的正文只包含通用提示；开启预览会把 X 提供的摘要交给 MeoW。
- 默认存储文件 `server/data/push-subscriptions.local.json` 包含订阅私钥和昵称，已被 Git 忽略。
  保护好文件和备份；不要公开部署目录。服务仅保存用于发送的通知文本和有限数量的去重哈希。
- “停用并解除绑定”先删除中转订阅和待发队列，再向 X 注销。删除失败不会假报停用，
  也不会清掉重试所需配置；X 注销失败但中转删除成功时，明确提示“已停止转发，待清理”。
- 从账号管理删除账号或退出账号时，也先停用其 MeoW 转发。中转不可达时会提示先解除绑定。
- 原有通知开关控制本机定时检查和本机通知。MeoW 是独立离线通道；其横幅、声音和免打扰
  在 MeoW/系统通知管理中设置。
- MeoW 业务失败可能仍返回 HTTP 200，因此代码同时检查 JSON `status`。
  遇到 429 暂存并延迟重试；这时无法承诺即时送达。中转为每份订阅最多保留 100 条待发提醒，
  队列满时向上游返回 429；上游是否重试由 X 决定。
- 中转提供至少一次发送语义，进程若在 MeoW 接收后、写盘前崩溃，恢复后可能重复提醒。
  停用时已经交给 MeoW 的通知不能远程撤回。

## 协议和维护

这是 Harmony X 自己的 `/v1/meow/*` 协议，不能直接填写 Petrelgram 的私有中转地址。
借鉴的是注册、验证和中转架构，没有使用其作者的服务凭据。

| 方法与路径 | 用途 |
| --- | --- |
| `POST /v1/meow/register` | `{subKey, nickname, previews}`，发验证码并返回 `pendingId` |
| `POST /v1/meow/confirm` | `{subKey, pendingId, code}`，返回 `endpoint/p256dh/auth` |
| `POST /v1/meow/activate` | `{subKey}`，启用已在 X 注册的订阅 |
| `POST /v1/meow/status` | `{subKey}`，查询真实接收、转交时间、测试时间及队列 |
| `POST /v1/meow/test` | `{subKey}`，发送测试通知 |
| `POST /v1/meow/delete` | `{subKey}`，幂等删除订阅和队列 |
| `POST /push/<random>` | 接收加密 Web Push |

管理接口带 `Authorization: Bearer <PUSH_RELAY_TOKEN>`；`subKey` 是手机生成的管理能力，
与交给 X 的推送地址分开。验证码不落盘，服务重启后尚未完成验证的绑定需解除后重发。

测试：在项目根目录运行 `node --test tests/meow-push.test.cjs`；
在 `server` 中运行 `npm run test:push`。

参考：

- [Petrelgram WebPushRegistration](https://github.com/miramira8295/Petrelgram/blob/main/entry/src/main/ets/services/WebPushRegistration.ets)
- [Petrelgram MeowPushRegistration](https://github.com/miramira8295/Petrelgram/blob/main/entry/src/main/ets/services/MeowPushRegistration.ets)
- [MeoW 官方接口](https://www.chuckfang.com/MeoW/api_doc.html)
- [X 请求格式的客户端实现](https://github.com/mautrix/twitter/blob/main/pkg/twittermeow/account.go)
- [X 推送偏好字段](https://github.com/mautrix/twitter/blob/main/pkg/twittermeow/data/payload/json.go)
- [HTTP 加密内容编码实现 http_ece](https://github.com/martinthomson/encrypted-content-encoding)

客户端请求按公开可核查的协议字段独立实现，未复制 mautrix 的 Go 实现代码。
