# XXAuth 软件信息与远程弹窗

> **当前推荐配置入口（2026-10-17）：** 请按 [每应用一套推荐配置](xxauth-recommendations.md) 操作。当前仅启用「记得订阅」，其余四款关闭。下文保留旧版分散公告与兼容协议的说明，其中旧的「印记」选择和关闭总开关的历史状态不代表当前云端状态。

HarmonyX 使用软件 ID `2778143c-260a-4e04-83ad-2889f6aaad0d`。
客户端只携带公开的 `app_id`，不会向 XXAuth 发送 X 的账号、Cookie 或令牌，也不内置开发者令牌。

## 推荐弹窗：按已有公告约定配置

在 XXAuth 当前软件中发布一条公告：

- 标题：`链接`
- 优先级：`-2`
- 内容（链接换成实际体验地址）：

```text
//提醒
https://example.com/app
```

隐藏时将内容改成 `//关闭`，或取消发布/删除该公告。多条控制记录同时存在时，取 `created_at` 最新的一条；最新记录关闭时，不回退到旧链接。推荐记录不会混入普通公告列表。

没有控制记录、没有有效 HTTPS 链接、公告请求失败，均不显示推荐弹窗。用户选择“3 天内不提醒”后，免提醒会跨重启、跨推荐内容生效。普通关闭只影响本次运行。

无远程文案时的默认内容沿用提供的《应用推荐弹窗实现.md》中的“拾刻水印”。当前后台已经用下面的程序变量覆盖为“印记”，体验链接为用户提供的华为应用市场地址。

## 云端开关（一个开关一个变量）

后台「变量配置」里每个开关单独一行，客户端读取 `GET /variables` 后叠加到 JSON 配置之上；某个变量不存在就沿用 JSON 里的值。值写 `on`/`off` 即可（`true`/`false`/`1`/`0`/`开`/`关` 也认）。

| 变量名 | 作用 | 当前值 |
| --- | --- | --- |
| `harmonyx_enabled` | 推广总开关，`off` 时下面所有推广内容都不显示 | `off` |
| `harmonyx_recommend` | 应用推荐开关：弹窗 + 信息流推荐帖 + 评论区一起 | `on` |
| `harmonyx_announcements` | 应用公告开关 | `on` |
| `harmonyx_guide` | 使用指南（文章）开关 | `off` |
| `harmonyx_banner` | 启动 Banner 开关 | `off` |
| `harmonyx_post_count` | 每条时间线放几条推荐帖（0 或 1） | `1` |
| `harmonyx_post_comment_count` | 每个帖子评论区混入几条推荐帖（0-2） | `1` |
| `harmonyx_post_revision` | 改这个数字，让所有用户已经点过的「7 天内不再显示」立即失效 | `2` |

「检查更新」不在这套里：它由软件管理的「版本管理」与更新配置（`force_min_version`、`update_strategy` 等）决定，和推广开关互不影响。

平时只需要动 `harmonyx_enabled`：现在保持 `off`，上线推荐时改成 `on` 即可，弹窗与信息流帖子按 `harmonyx_recommend` 一起出现。需要单独控制渠道时，可以在 `harmonyx_popup` 的 JSON 里补 `recommendation_enabled`（只管弹窗）或 `post_enabled`（只管推荐帖，`true` = 只发帖子不发弹窗）。

## harmonyx_popup：只放文案

开关拆出去之后，这个变量只保留文案与图标（可全部省略）：

```json
{
  "enabled": true,
  "recommendation_enabled": true,
  "announcements_enabled": true,
  "banners_enabled": true,
  "articles_enabled": false,
  "recommendation_title": "拾刻水印",
  "recommendation_description": "填写推荐应用的介绍",
  "recommendation_icon": "https://example.com/icon.png"
}
```

`enabled: false` 关闭自动内容弹窗。各类开关分别控制应用推荐、普通公告、启动 Banner 和文章。文章默认只供用户主动阅读；`articles_enabled: true` 后才进入启动弹窗队列。强制版本更新遵循服务端策略，不受推广内容开关影响。

客户端读取 `GET /variables` 的 `[{key,value}]` 数组，并通过 `POST /variable/harmonyx_popup` 的 `{key,value}` 对象读取单个配置；单个结果优先于批量结果。不设置该变量时，推荐的显隐仍可完全通过公告的 `//提醒`、`//关闭` 控制。

2026-10-16 经用户明确确认，已在后台保存关闭“获取程序变量需身份校验”，两个变量接口实测均返回 HTTP 200。此软件现有程序变量只有公开的弹窗配置；关闭鉴权会使该软件全部程序变量可被未登录调用方读取，后续不要放入凭据或私有数据。客户端不会拿 X 登录信息冒充 XXAuth 身份。变量接口的鉴权拒绝不会影响公告控制；网络、解析或服务异常不会重新打开推广弹窗。

当前实际配置：

```json
{"enabled":true,"recommendation_enabled":true,"announcements_enabled":true,"banners_enabled":false,"articles_enabled":false,"recommendation_title":"印记","recommendation_description":"前往华为应用市场了解并体验印记。"}
```

推荐公告 ID：`fd99210f-2ae7-5f21-b6dd-cdc53d71a8c6`，标题 `链接`，优先级 `-2`，发布状态 `1`，内容：

```text
//提醒
https://appgallery.huawei.com/app/detail?id=com.my.mark&channelId=SHARE&source=appshare
```

## 普通公告、文章和 Banner

- 普通公告按 `priority` 降序排队；包含 `//关闭` 的记录隐藏。普通内容关闭后保存已读指纹，标题或内容变化会再次提示。
- `//提醒` 表示每次启动都可提示，但同一记录在一次运行中最多提示一次；控制标记不会显示给用户。
- Banner 使用 `image_url` 和 `link_url`，图像和跳转目标只接受 HTTPS。图片不合规时不弹出，跳转链接为空时只展示图片。
- 文章使用 `title` 和 `content`。HTML 转为纯文本显示，不执行脚本。
- “关于”内有应用公告、使用指南、版本历史和检查更新入口，均通过原生半模态弹窗呈现。远程关闭的公告、文章在主动阅读列表中也会隐藏。

## 刷新与更新

首页加载后异步获取，不阻塞启动；等待首次引导、登录等界面结束后逐个显示。应用在前台时每 60 秒刷新，返回前台且距离上次刷新超过 60 秒也会刷新。刷新读到关闭/取消发布后会收起正在显示的对应内容。若关闭后重新开启，推荐可再次显示，仍遵守用户的 3 天免提醒。

更新使用 `platform: harmonyos`、`channel: stable` 和本安装随机生成并持久保存的 `device_id`，由服务端决定灰度命中。

- `is_latest: true`：自动检查不提示，主动检查显示结果。
- `none` / `silent`：不显示普通更新提示；客户端未实现静默下载安装。
- `force_update: true` / `update_strategy: force`：显示不可手动关闭的更新弹窗，禁止通过返回、遮罩或拖动跳过。
- 下载按钮打开 HTTPS 分发地址；应用内下载、安装与包校验未实现。应使用签名匹配、可安装的 HarmonyOS 分发包。

## 支持者免推荐（按 X 账号）

用户自愿打赏后由开发者核对收款，再为该软件生成一枚兑换码单独发给用户；软件不接入支付，只做本地校验。

- 兑换码绑定的是**已登录 X 账号的 user id（GraphQL 里的 `rest_id`）**，不是设备。`rest_id` 改名也不变，所以同一账号换设备、重装都能用原码恢复；换成另一个账号需要另一枚码。`@用户名` 会被人修改甚至被他人重新抢注，不能当标识。
- 客户端调用 `POST /open/v1/card/login`，把该 user id 作为 `machine_code` 传入，因此后台「卡密记录」的 `绑定设备` 列显示的是一串数字 ID（例如 `1552130489544085504`），可按它把码和账号对上。后台「验证配置」需保持开启「绑定机器码」。
- 客户端只发送 `app_id`、`card_no` 和这个 user id，不发送 X 的 Cookie、`auth_token` 或 OAuth 令牌。兑换码与本机校验结果一起存放于系统加密的关键资产（`@kit.AssetStoreKit`），不写入普通 preferences，也不进入 AppStorage。
- 生效后隐藏启动推荐弹窗和推广 Banner，并隐藏「关于」里的「查看应用推荐」入口；普通公告、文章和版本更新照常显示。远程「强制提醒」不会绕过支持者状态。
- 后台把卡密改为 `已禁用` 或删除后，客户端下次校验（启动时或每 5 分钟）即回收资格并重新显示推荐；改回 `已使用` 后下一个校验周期自动恢复。
- 网络异常、限流（408/429）和 5xx 不会回收已生效且未过期的资格；只有卡密层面的明确拒绝（400/404，或带卡密字样的 401/403）才回收，误判会在下一次成功校验时自愈。
- 一台设备最多缓存 4 个账号的兑换记录，多个 X 账号各自独立判断，互不覆盖。

## 推荐帖（信息流投放）

除弹窗之外的第二种投放：把推荐做成一条信息流帖子。客户端用**正常帖子的卡片**渲染它，头像、蓝V、正文、媒体网格、分割线与真实帖子一致，只有数据来源换成了后台记录。

后台在「公告配置」里新建记录：

- 优先级 `15`：推荐帖本体，分段写 `帖子昵称`、`帖子账号`、`帖子认证`（`蓝V` 或 `无`）、`帖子头像`、`帖子正文`，可选 `帖子媒体`（一行一个 HTTPS 图片/视频地址，`帖子媒体：` 后可以跟多行）。
- 优先级 `16`：推荐帖媒体（可选）。没有在 15 里写 `帖子媒体` 时，所有推荐帖共用这里的地址。
- 优先级 `12`：没有写 `帖子头像` 时用它作为头像兜底；优先级 `13` 既是弹窗的体验链接，也是推荐帖的点击目标。

每条记录还可以单独控制：

- `帖子链接：<url>`：这条帖子自己的跳转地址。多个应用同时推广时必须每条都写，否则都会跳到优先级 13 那一个。
- `帖子开关：开/关`：单独暂停这一条（`关`、`关闭`、`停用`、`off`、`false`、`否`、`0` 都算关）。记录里任意位置写 `//关闭` 效果相同。
- 字段顺序：`帖子开关` 放最后一行，否则它后面的正文会被当成开关的值。

多媒体写法：一行一个地址，图片直接写 URL；视频写 `视频地址|封面地址`（封面可省），例如

```text
帖子媒体：https://mos-vod-drcn.dbankcdn.cn/.../MP4Mix_H.264_1920x1080_6000_HEAAC1_PVC_NoCut.mp4?accountinfo=...|https://appimg-drcn.dbankcdn.com/files/application/appVideo/introFrame/phone/xxx_card.png
https://appimg-drcn.dbankcdn.com/application/screenshut1/phone/xxx.jpg
```

客户端会用应用自己的播放器内联播放视频（点一下播放/暂停），并用下载到本地的封面帧做静帧；视频分辨率从地址里的 `1920x1080` 这类片段识别，避免按竖屏截图的比例排版。

### 视频源怎么取

应用市场的详情接口 `POST /harmony/page-detail`（`pageId=webAgPackage|<包名>`）里，`pages[0].data.cardlist.layoutData[1].data[0].list[0].multipleDeviceMaterials[]` 按设备分列，每列的 `videoInfos[]` 就是介绍视频：`videoUrl`（H.264 MP4）、`videoPoster`（首帧图）、`duration`（秒）。`screenShots[]` 是同一设备下的介绍图。手机/平板各有一份，取 `multipleDeviceMaterials[0]`（phone）即可。没有 `videoInfos` 或数组为空表示该应用没上传介绍视频。

投放规则：

- **每条时间线只放一条**（`post_count`，默认 1，上限 1），位置在时间线的前几条里随机，每次启动应用重新抽取；同一次运行内刷新不会改变位置。
- 可以建多条优先级 `15` 记录，客户端按时间线/启动轮换用哪一条，所以不同标签页、不同次启动看到的内容会交替。
- 出现在「为你推荐」「正在关注」、搜索结果时间线，以及帖子详情页的评论区（`post_comment_count`，默认 1，上限 2）。
- 点整条帖子或头像打开优先级 `13` 的链接；`×` 提供 `本次关闭`（本次运行不再出现）与 `7 天内不再显示`（记录内容指纹，后台换内容后自动恢复）。
- `post_enabled: false` 一次关掉全部推荐帖；优先级 `15` 记录里写 `//关闭` 只停用该条记录。
- 改 `post_revision`（任意数字，只需与上次不同）可让**所有用户**已经点过的「7 天内不再显示」立刻失效，用来做临时活动或排查。
- 支持者（免推荐）状态下推荐帖同样不显示；普通公告、文章、版本更新不受影响。

素材注意：图片走客户端自己的下载与本地缓存，不依赖 ArkUI 的远程图片请求——应用市场素材 CDN 返回 `application/octet-stream`，ArkUI 解码不了，只有下载后本地显示才正常。

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `post_enabled` | `true` | 推荐帖总开关 |
| `post_count` | `1` | 每条时间线的推荐帖条数（0 或 1） |
| `post_comment_count` | `1` | 每个评论区混入的推荐帖条数（0-2） |
| `post_revision` | `0` | 改这个数字让所有「不再显示」立即失效 |

当前后台同时推广 4 个应用（每条一个优先级 15 记录，各自带链接、开关与素材）：

| 记录标题 | 应用 | 包名 | 媒体 |
| --- | --- | --- | --- |
| 推荐帖 | 印记 | `com.my.mark` | 5 张介绍图 |
| 推荐帖 二 | 印记（第二篇文案） | `com.my.mark` | 2 张介绍图 |
| 推荐帖 便单 | 便单 | `cn.biandangroup.biandan` | 1 条介绍视频（57s）+ 3 张介绍图 |
| 推荐帖 迹得 | 迹得 | `cn.biandangroup.getrace` | 4 张介绍图 |
| 推荐帖 图造 | 图造 PicForge | `com.bogdan.tpcut` | 4 张介绍图 |

来源：<https://appgallery.huawei.com/app/detail?id=cn.biandangroup.biandan>、<https://appgallery.huawei.com/app/detail?id=cn.biandangroup.getrace>、<https://appgallery.huawei.com/app/detail?id=com.bogdan.tpcut>（迹得与图造没有上传介绍视频）。

## 八个接口的入口

| 接口 | 用途 |
| --- | --- |
| `GET /announcements` | 启动公告、推荐控制、点击体验前再次核对、主动阅读 |
| `GET /articles` | 文章弹窗和使用指南 |
| `GET /banners` | 启动图片弹窗 |
| `GET /version/latest?platform=harmonyos` | 版本历史弹窗的最新版本 |
| `POST /version/check` | 启动检查与主动检查 |
| `GET /version/list?platform=harmonyos` | 版本历史弹窗 |
| `GET /variables` | 公开 UI 配置批量读取 |
| `POST /variable/harmonyx_popup` | 按名读取弹窗控制配置 |

## 2026-10-16 实测边界

后台配置前，公告、文章、Banner、版本列表均为空，最新版本与版本检查返回 HTTP 404，变量接口返回 HTTP 401。配置后，公告接口已返回上面的已发布推荐记录，两个变量接口均返回 HTTP 200；批量与单变量实际返回结构已经同步到客户端及测试。文章、Banner 和版本资料尚未发布。

针对性验证：`node --test tests/xxauth-popup.test.cjs tests/settings-catalog.test.cjs`，18 项通过。`devecocli run --module entry --device 5MT0225B19003950` 构建、安装、启动成功。

真机已验证：从真实线上配置弹出“印记”推荐，显示介绍、“关闭”、免提醒按钮和“立即体验”；点击“立即体验”成功打开华为应用市场“印记”详情页。该轮设备验收时免提醒为 7 天；改为 3 天后逻辑与文案已更新，但尚未重新做跨三天真机验收，也未在真机上验收后台来回切换关闭/提醒。强制更新与灰度更新没有线上版本数据，未做业务验收。

证据：`outputs/xxauth-device-popup.png`、`outputs/xxauth-device-market.png`、`outputs/xxauth-backend-recommendation-enabled-20261016.png`。

资料：<https://www.xxauth.com/developer/api-docs>，本地 `D:/下载/weibotubiao/endpoints.md`、`features.md` 和 `D:/下载/应用推荐弹窗实现.md`。网页当前要求安全验证，接口契约以这几份已有说明和本次实际响应核对。

## 2026-10-17 支持者免推荐实测

真机（`5MT0225B19003950`，登录账号 `@haohaofan052`）用线上兑换码完成端到端验收：关于页显示「兑换码将绑定到 @haohaofan052」，激活后显示「感谢支持！免推荐已生效。」与到期日，且「查看应用推荐」入口消失；后台该卡密的 `绑定设备` 为 `1552130489544085504`，确认绑定的是 X 账号 ID 而非设备 UUID。

对照验收：把公告「提醒优先级」临时改为 `//强制提醒`（可越过 3 天免提醒）后重启，支持者状态下不弹推荐；后台把该卡密改为 `已禁用` 再重启，推荐恢复弹出；改回 `已使用` 后再次重启，推荐重新被抑制。验收结束后已把提醒模式还原为 `//不强制`。

这次对照暴露并修掉一个真实缺陷：后台停用卡密返回的是 `400 卡密已被禁用`，原先按文案白名单判断会漏判，导致停用后资格未被回收。现在卡密层面的 400/404 直接判定为回收，408/429/5xx 仍保留缓存资格。

针对性验证：`node --test tests/xxauth-supporter.test.cjs` 12 项通过；`node --test tests/xxauth-popup.test.cjs tests/xxauth-recommendation.test.cjs tests/settings-catalog.test.cjs` 26 项通过。版本与灰度更新、跨设备同账号恢复只做了逻辑覆盖，未做真机验收。

证据：`outputs/xxauth-supporter-account-device.png`（支持者已生效与会话入口变化）、`outputs/xxauth-supporter-revoked-popup.png`（停用后推荐恢复）、`outputs/xxauth-supporter-account-binding-backend-20261017.png`（后台绑定标识）。

## 2026-10-17 推荐帖实测

真机（`5MT0225B19003950`）验收：把优先级 15/16 记录和 `post_enabled` 打开后，重启应用不再弹出任何弹窗（`startup` 面板为空），启动推荐帖出现在「为你推荐」时间线的前几条、每次启动位置随机，卡片头像、蓝V、`AD` 标、正文、`显示更多`、媒体网格与真实帖子一致；「正在关注」与帖子详情评论区各出现一条，并会轮换使用两条 15 记录中的另一条。

对照与缺陷记录：

- 视觉上与真实帖子相同：客户端把后台记录组装成一条合成 Tweet，交给 `TweetCard` 渲染，只把「需要真实帖子才能生效」的互动（点赞/转发/回复/更多菜单/翻译入口）去掉，`×` 换成推荐帖自己的两个处置选项。
- 修掉：优先级 15/16 之前被当成**普通公告**排队，于是启动时以弹窗形式弹出推荐文案（`XXAuthPopupPolicy.startup` 只过滤了 10-14）。现在统一用同一个控制位判断，弹窗与公告列表都不再包含它们。
- 修掉：首页数据源只用了 `posts` 全量、没读 `timelineCount`，导致两条推荐帖同时插进同一条时间线并相邻显示；现在由远程预算决定条数，池子只决定用哪几条。
- 修掉：「不再显示」原先按时间写死 7 天，误点后只能等一周或改文案；现在记录内容指纹，且 `post_revision` 一改即全部失效。
- 图片显示：素材 CDN 返回 `application/octet-stream`，ArkUI 远程图片请求与面板态 `ProxyMediaImage` 都会静默失败；改为应用内下载并本地缓存后再显示，头像与介绍图均正常。

针对性验证：`node --test tests/xxauth-promotion-post.test.cjs tests/xxauth-popup.test.cjs tests/xxauth-supporter.test.cjs` 通过（推荐帖解析、多帖轮换、随机位置与间距、预算条数、数据源注入、控制位过滤、支持者免推荐）。`devecocli run --module entry --device 5MT0225B19003950` 构建、安装、启动成功。

证据：`outputs/xxauth-promo-single2.png`（时间线单条推荐帖）、`outputs/xxauth-promo-comment.png`（评论区推荐帖）、`outputs/xxauth-promo-tweet.png`（与真实帖子同款卡片）。

未验收：视频媒体只做了地址识别与播放角标，没有真实 mp4 端到端；冷启动随机位置在长列表分页时的稳定性只做了单元测试；「本次关闭」在杀掉进程后失效只做了代码与逻辑覆盖。

## 2026-10-17 多应用与视频补充实测

新增 4 条推广记录（便单、迹得、图造 PicForge，加原有的印记两条）后真机验收：同一条记录池在「为你推荐」「正在关注」「评论区」各取一条，**每次启动重新抽取**——连续 4 次冷启动看到 `@迹得`、`@迹得`、`@便单`、`@迹得`，同一次运行内位置和对象都不再变化。

视频链路：便单的介绍视频在信息流卡片里内联播放（点击播放/暂停，进度、倍速、静音、全屏控件齐全），静帧来自市场提供的 `videoPoster`，视频按 1920x1080 横屏排版而不是竖屏截图比例；同一条帖子里视频与 3 张介绍图混排正常。

每条记录可以单独暂停（`帖子开关：关` 或 `//关闭`），也可以各自带 `帖子链接`，因此四个应用互不影响；`post_revision` 一改可让所有用户已经点过的「7 天内不再显示」立即失效。

证据：`outputs/xxauth-promo-video.png`（便单视频内联播放）、`outputs/xxauth-promo-apps.png`（图造图片卡与图片查看器）、`outputs/appmarket-*.json`（三个应用的市场详情原始返回）。

## 2026-10-17 记得订阅云端配置验证

从用户提供的市场链接直连中国区详情接口，确认应用为「记得订阅」（`com.xxtstudio.accountDL`）。在现有软件下新增优先级 `15`、发布状态 `1` 的「推荐帖 记得订阅」，记录 ID 为 `c570e01f-b838-569b-8119-d1207cbed888`，带独立市场链接与 `帖子开关：开`。

手机、平板各配置市场提供的 66 秒 1920×1080 介绍视频、对应封面及 5 张介绍图。公开公告接口已返回唯一一条新记录，内容与预期一致；直接使用当前客户端解析器验证两套媒体、视频时长和跳转地址均正确，14 个素材请求均返回 HTTP 200。

推广总开关 `harmonyx_enabled` 保持 `off`，客户端实际配置下推荐列表为空。此次只验证云端保存、接口读取、客户端解析及素材可访问性，未开启全量推广，也未验收设备上的卡片显示与视频播放。

证据：`outputs/xxauth-accountDL-verification.json`、`outputs/xxauth-accountDL-assets-check.json`、`outputs/xxauth-accountDL-announcements-after.json`、`outputs/appmarket-com.xxtstudio.accountDL.json`。
