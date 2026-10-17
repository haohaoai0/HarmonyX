# harmonyx-gateway

新增的 **MeoW 离线私信推送**作为独立服务运行：`npm run start:push`。
它不需要 X 会话 Cookie，也不依赖下面的网关启动流程。配置与验证步骤见
[MeoW 推送部署说明](../docs/meow-push.md)。

Harmony X 的后端网关。ArkUI 前端只调用本服务，X 的会话 Cookie、queryId、
反爬请求头都留在服务端。

```
ArkUI (Harmony X)  --HTTP/JSON-->  harmonyx-gateway  --HTTPS-->  api.x.com / api.twitter.com
```

## 为什么要有这一层

参考实现（`app.jjyy.chuckle`，即 Chuckle 1.1.1）把整套 X 私有接口直接放在
Android 客户端里：Cookie 会话、GraphQL queryId 表、`X-Client-Transaction-Id`
反爬头、REST 1.1、媒体上传。这套东西放到鸿蒙客户端里有两个问题：

1. **Cookie 泄露面**：`auth_token` 等于账号全权凭据，放在移动端等于把密码放进 App。
2. **改接口就要发版**：queryId 和风控策略会变，客户端硬编码意味着每次都要重新发 HAP。

所以这里把它做成自建后端：客户端只拿一个网关 token，接口调整只改服务端。

## 目录

| 路径 | 作用 |
|---|---|
| `src/index.mjs` | 入口：加载会话、构建 transaction-id provider 链、启动 HTTP 服务 |
| `src/gateway.mjs` | 对 App 暴露的 REST 路由 + 网关鉴权 |
| `src/session-store.mjs` | X 会话（Cookie 罐）的创建、持久化、解析 |
| `src/x/headers.mjs` | 请求头构造，对齐参考实现的两条分支（已登录/访客） |
| `src/x/client.mjs` | GraphQL / REST 1.1 / 媒体上传调用 |
| `src/x/transaction-id.mjs` | `X-Client-Transaction-Id` 的 provider 链 |
| `src/x/operations.generated.mjs` | **207 个 GraphQL 操作**（由 `data/x-operations.json` 生成） |
| `data/x-operations.json` | 从参考实现里解析出的权威操作表（endpoint / 操作名 / queryId / GET-POST） |
| `data/x-operation-documents.json` | 另一族定义里的 115 个操作完整 GraphQL 文档，供排查 `features` 用 |
| `tools/gen-operations.mjs` | 由 JSON 生成 `operations.generated.mjs` |

## 运行

```powershell
cd D:\HarmonyX\server
npm run gen     # 仅在改了 data/x-operations.json 之后需要

$env:GATEWAY_TOKEN = "换成你自己的随机串"   # 不设置则只允许本机访问
npm start
```

国内网络访问 `api.x.com` 需要代理。Node 24 内置了环境变量代理支持：

```powershell
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
$env:NO_PROXY    = "127.0.0.1,localhost"
npm run start:proxy
```

健康检查：

```powershell
curl http://127.0.0.1:8787/health
# {"ok":true,"service":"harmonyx-gateway","sessions":0,"operations":207}
```

## 导入 X 会话

浏览器登录 x.com 后，开发者工具 → Application → Cookies → `https://x.com`，
把 `auth_token` 和 `ct0` 两个值拼成 Cookie 串发给网关：

```powershell
curl -X POST http://127.0.0.1:8787/v1/session `
  -H "content-type: application/json" `
  -H "x-gateway-token: <你的 GATEWAY_TOKEN>" `
  -d '{"cookies":"auth_token=...; ct0=...","label":"main"}'
```

返回体里的 `session.id` 就是后续请求的 `x-session-id`；只有一个账号时可以省略，
网关会用最近更新的那个会话。

> `auth_token` 是账号全权凭据，等价于密码。本服务把它存在
> `data/sessions.json`（已加入 `.gitignore`），**不要**把这个目录提交或部署到公网。

## 对 App 暴露的接口

除 `/health` 外全部需要 `x-gateway-token`。返回统一为
`{ ok, status, data, rateLimit }`，失败时 `status` 是上游 HTTP 码（0 = 网络失败）。

| 方法 | 路径 | 说明 |
|---|---|---|
| `GET` | `/health` | 存活与操作表数量 |
| `POST` | `/v1/session` | 导入 Cookie：`{ cookies, label? }` |
| `GET` | `/v1/session` | 会话列表（只返回 Cookie 名，不返回值） |
| `DELETE` | `/v1/session/:id` | 删除会话 |
| `GET` | `/v1/ops?filter=` | 查询 207 个操作表 |
| `POST` | `/v1/x/graphql` | 通用 GraphQL：`{ op, variables, features? }`，`op` 可用操作名或 endpoint key |
| `POST` | `/v1/x/rest` | REST 1.1 透传：`{ method, path, query?, form?, json? }`（仅允许 `/1.1/`） |
| `GET` | `/v1/timeline/home?mode=for-you\|following&cursor=&count=` | 首页双时间线 |
| `GET` | `/v1/tweet/:id` | 帖子详情 |
| `GET` | `/v1/search?q=&cursor=&count=` | 搜索 |
| `GET` | `/v1/user/by-screen-name/:name` | 用户资料 |
| `GET` | `/v1/user/:id/tweets?cursor=` | 用户时间线 |
| `POST` | `/v1/tweet` | 发帖：`{ text, replyToId? }` |
| `POST` | `/v1/action` | `{ type, tweetId?, userId? }`，type ∈ like/unlike/repost/unrepost/bookmark/unbookmark/follow/unfollow/block/unblock |

## 实现状态（重要）

### 已完成并本地验证

- 网关服务、路由、鉴权、会话持久化（`/health`、`/v1/ops`、`/v1/session` 已实测通过）。
- 207 个 GraphQL 操作的权威表，含 queryId 与 GET/POST 判定。
- 请求头构造：公开 Bearer、`x-csrf-token`（取自 Cookie 的 `ct0`）、
  `x-twitter-auth-type: OAuth2Session`、`X-Twitter-Active-User`、语言头、
  浏览器指纹头（`sec-ch-ua*` / `sec-fetch-*`），以及访客分支的 `X-Client-UUID`。
- GraphQL 调用：GET 走 query 参数，POST 走 `{variables, features}`，并对齐
  `Accept: application/graphql-response+json`。
- REST 1.1 与单请求媒体上传（`upload.twitter.com`）。

### 需要你补一步才能通

- **`X-Client-Transaction-Id` 的计算没有实现。** X 的风控要求这个头，
  参考实现是把官方 Web 的 `ondemand.s.*.js` 拉下来、配上一份密钥字典
  （社区项目 `fa0311/x-client-transaction-id-pair-dict`）在 Kotlin 里复刻算法算出来的。
  这里把**流程**做好了（`PairDictProvider` 会真实下载并缓存密钥字典、
  失败时按 provider 链回退、不抛异常），但那个逐请求的变换函数是一个
  混淆产物的移植，照着猜写等于交付一个假实现，所以留成了插槽：

  ```powershell
  $env:X_TID_MODULE = "file:///D:/your/transaction-id/impl.mjs"
  ```

  该模块导出 `compute({ material, method, path }) => string` 即可。
  在此之前 `X_TID_DISABLED=1` 可以让服务不带这个头照常跑，便于先联调其它接口。
- 中国大陆网络需要代理才能访问 `api.x.com`，本机实测为连接超时（不是代码问题）。
  请在能直连 X 的环境部署，或按上面的 `start:proxy` 使用代理。
- `unlike` / `unfollow` 之外的个别动作走的 REST 路径（如
  `/1.1/favorites/destroy.json`）是 X 长期存在的公开路径，但没有从参考实现里
  逐条验证过；首次联调时看返回码确认。
- DM 实时通道（`wss://chat-ws.x.com/ws?token=`）和视频分片上传
  （INIT/APPEND/FINALIZE）还没接，属于下一步。

### 不要做的事

这套东西绕过了 X 的客户端身份校验，属于明确违反 X 服务条款的行为，
账号有被限流或封禁的风险。请只用于自己的账号、控制请求频率，
不要用它做批量抓取或自动化刷量。
