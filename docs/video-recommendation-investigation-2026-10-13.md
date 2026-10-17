# 视频流重复内容调查

日期：2026-10-13。检查 HarmonyX 当前源码、当日 X 官网前端文件，以及已有的 Chuckle 1.1.1 / build 154 APK 反编译产物。本次调查未修改应用业务代码。

## 已确认的问题

HarmonyX 视频流只在单次打开期间去重，未实现跨次打开的已观看视频去重。

- `VideoFeedViewer.ets:233` 每次读取路由都新建 `VideoRecommendationStream`，该服务的游标从空字符串开始。
- `VideoRecommendationStream.ets:18` 的 `excludedIds` 只存在于这一实例；构造时加入源列表和种子帖，收到一页后加入这一页的帖子，`noteViewed()` 也只写入这个集合。
- 视频切页会调用 `browsingHistoryStore.record()`，但推荐服务没有读取这份历史。关闭后再打开，之前观看过的推荐视频不再处于排除集合中。
- `Index.ets:4633` 的入口每次提供点击的种子帖，以及当前首页、探索、个人主页、喜欢列表中的帖子 ID。当种子和这些列表没有变化时，请求起点和初始排除条件也没有变化。
- `XPrivateClient.ets:1049` 会使用 `fresh=true` 请求推荐接口；该接口也不在响应缓存名单中。因此源码没有证据支持“总是读到同一份本地响应缓存”这个解释。

确定性复现使用实际 `VideoRecommendationStream` 服务和受控返回值：第一轮返回 202、203，标记 202 已观看，再以同一种子 101 新建服务；第二轮仍返回 202、203，两轮都请求空游标、count=20、seed=101。记录见 `.codex/video-recommendation/reopen-reproduction.json`。这是客户端逻辑复现，不是 X 实时服务端响应。

## 当日 X 网页

从 [X 视频入口](https://x.com/i/immersive_video) 获取当前前端资源后，检查了官方的 [ImmersiveMediaViewer 模块](https://abs.twimg.com/responsive-web/client-web/bundle.ImmersiveMediaViewer.bdd7cf6bdbe8fc35a.js) 和 [主模块](https://abs.twimg.com/responsive-web/client-web/main.6a9f1a030355136ba.js)。文件名中的哈希来自当日页面的 Webpack 映射。

- 当前媒体 Viewer 使用 `ImmersiveMedia`，queryId 为 `VylcAECK1LWwr_7O5Np4eg`，与 HarmonyX 使用的 APK 登记接口不同。
- `fetchImmersiveMedia` 明确构造 `pinned_tweet_id`、`page_name`、`includePromotedContent`，读取 `immersiveMedia.timeline`。没有看到该方法发送首页的 `seen_tweet_ids`。
- 时间线模块按 `immersiveMedia-${seedId}` 保存到共享 URT 状态中，而不是仅把一个空游标保存到页面实例。通用时间线模块的 `fetchBottom` 从已有条目中找 Bottom 游标，`fetchInitialOrTop` 则根据现有状态判断初次加载或刷新。
- Viewer 创建观看会话 ID，记录进入时的 `impression` 和离开时的 `navigate`，并向子组件提供 `sessionId` / `immersive_session_card_index`。这些是实际前端事件机制；本次没有证明其中某个事件一定会使服务端换一批推荐。
- 不能由网页源码推导“每次点同一条种子视频，服务端必须返回完全不同的候选”。首批候选仍受服务端排序影响。

## 之前的 APK

参考文件是 `D:/apk-re/chuckle/chuckle-1.1.1-154.apk`，包名 `app.jjyy.chuckle`，属于第三方 Chuckle 客户端，不是官方 X Android APK。

- `jadx_out/sources/defpackage/u6q.java:562-570` 登记 `ImmersiveViewerExploreMixerTimeline`，queryId `UsztxIRwP6dxXKuVoQTIRw`，参数类型登记包含 `count`、`isMemberTargetUserId`、`pinned_tweet_id`。HarmonyX 目前选择的就是这个接口。
- 同一登记表还包含 `CarouselImmersiveVideoExploreMixerTimeline`。仅有接口登记不等于已确认某个 UI 入口一定使用它。
- `ilq.java:81-115` 的通用分页逻辑区分刷新/向前加载的 Top 和向后加载的 Bottom；向后加载 count=40。`ar4.java:826-837` 把非空游标传入请求。
- 首页 `seen_tweet_ids` 和视频接口是不同的参数机制，不能把首页已读参数直接补到视频接口并声称与 APK 一致。
- 本次没有取得 APK 同账号的实时视频请求，未将登记表当成完整的视频观看反馈证明。

## 处理方向和验证边界

直接缺口是跨次打开时的观看状态：需要按账号保留实际看过的视频 ID，在再次推荐时使用；预加载但未观看的候选不能直接当作已看，用户明确点击的首条种子也应继续展示。随后应核对当前接口的真实分页返回和观看反馈，保留服务端排序、真实错误与重试行为。不能靠随机打乱同一批视频掩盖问题。

六项推荐服务检查通过，覆盖独立游标、服务端排序、来源/当前会话排除、接口失败保留、重复游标停止和账号切换。

完整 `interaction-feedback.test.cjs` 为 23/25：另两项 Viewer 加载测试的旧 fixture 未初始化 `items`，在目前 `loadMoreVideos` 的尾部访问 `items.length` 时抛错；与本次受控跨次打开复现相互独立。本次未更改 fixture 或产品代码。

已连接设备列表和当前页面树可读取，但未完成同账号、同种子的 X 网页/APK/HarmonyX 实时响应对照；本报告不声称已验证服务端推荐质量，也不声称问题已修复。

本次原始证据保存在 `.codex/video-recommendation/`，包括官方网页、前端模块、下载路径清单、逻辑复现和测试输出。
