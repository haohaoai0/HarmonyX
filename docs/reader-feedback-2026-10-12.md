# 帖子、视频与通知反馈处理记录

日期：2026-10-12。保留工程原有改动，未提交或推送源码，未发布 GitHub Release。

## APK 推荐时间线请求

检查对象是本地 `D:/apk-re/chuckle/chuckle-1.1.1-154.apk` 的 JADX 输出。这是 Chuckle 客户端，不能将下面的证据称为原版 X Android APK 抓包。

| 机制 | APK 证据 | 鸿蒙实现 |
| --- | --- | --- |
| 推荐与关注分开请求 | `u6q.java:548` HomeTimeline，`:555` HomeTimelineLatest | 保留两种 GraphQL 操作 |
| 已读快照随推荐请求提交 | `ar4.java:767-783`、`joo.java:787-800` 添加非空 `seen_tweet_ids`、非空 `request_context` | 从实际可见卡片记录已读，不再把列表末尾 100 条当作已读；关注流不发送已读 ID |
| 最近 200 条观察记录 | `vg4.java:250-253` 按 observation_order 倒序，LIMIT 200；`opb.java:97-114` 使用 90 天时间界限 | 分账号持久化；请求发送最近 200 条；本地最多保留 4096 条、90 天的记录用于刷新去重 |
| 向前刷新与向后分页 | `ilq.java:81-115`：REFRESH/PREPEND 取 Top，APPEND 取 Bottom，APPEND count=40 | 解析、分别保存 Top/Bottom；刷新取 Top，继续下滑取 Bottom/count=40；刷新保留旧列表的 Bottom 分页链 |
| 请求上下文 | `ijo.java:356-358`：launch/foreground；`cjo.java:63`：cache_refresh；`xjo.java:93,811`：APPEND/手动 REFRESH 上下文为空 | 冷启动 launch，回前台自动刷新 foreground；手动刷新与分页使用空上下文；没有编造 pull_to_refresh |

原实现每次刷新清空游标，并将首屏请求写为 launch，已读 ID 又来自当前列表末尾，没有持久化实际阅读历史。这些差异足以解释重复推荐的可能来源，但没有完成两端同账号的实时请求对比，不能据此保证服务端推荐质量。

现有通用 GraphQL 变量构造器会把未提供的 nullable String 补为 null、数组补为空数组。因此手动刷新最终变量中的 request_context 为 null，关注流中的 seen_tweet_ids 为空数组，而不是含有推荐流的已读 ID。

显式刷新绕过请求缓存回退；失败保留当前帖子和分页状态，也不会将失败当成新帖子回顶。成功刷新会去除本地已读记录中的重复项，再合并当前列表。推荐属于服务端排序，并非按时间排列的最新关注流。

## 原始反馈覆盖

| 反馈 | 改动 | 验证与边界 |
| --- | --- | --- |
| 视频上滑重复首页后续内容 | Viewer 从点击的视频开始，调用独立 ImmersiveViewerExploreMixerTimeline；传 pinned_tweet_id，排除源列表和已投递视频 ID；请求失败不退回首页 | 已测游标独立、种子、来源排除、顺序和错误保留；未做真实服务端返回视频与首页的完整对比 |
| 铃铛通知进入账号 | 解析全部 target_tweets_results，保留作者、媒体，新增原生 NotificationPosts 子页；铃铛和多帖通知路由到此页 | 已测多帖解析、路由、去重和账号切换隔离；真实多帖铃铛页面仍需设备确认 |
| 双击首页与下拉刷新仍需胶囊 | 设置中新增两个独立开关，默认直接加载并回顶；关闭时保留位置，通过胶囊回顶 | 已测保存、失败不发布设置、双击分支；沿用已有刷新并发保护 |
| 关闭自动播放后下个视频暂停 | Viewer 当前页带明确播放意图，自动播放设置仍控制首页内嵌视频 | 已测自动前进后的播放参数及播放器生命周期；完整播完再自动前进还需真机长视频检查 |
| 开启自动播放时点击无法进入 Viewer | 非 GIF 内嵌视频画面点击统一进入 Viewer，并携带播放位置 | 已测画面、控制区、GIF、链接卡片和评论遮罩分支 |
| 帖子更多菜单 | 按用户接受横杠样式的补充要求，使用原生 sys.symbol.line_3_horizontal；新增截图中的菜单操作 | 真机确认菜单能展开。关注/隐藏/屏蔽与列表成员操作调用真实接口，并重新查询确认状态 |
| 不感兴趣 | 匹配帖子 feedbackKeys 与服务端 feedback_actions，使用服务端原始 feedback_url 提交 | 仅允许 X API 来源；没有反馈 token 时只能本地隐藏，并明确提示。未对用户账号提交随机反馈验证 |
| 举报、社群附注、隐藏回复 | 跳转官方帖子/隐藏回复页面，举报与附注明确提示需要在官方页面继续 | 没有伪造已举报或已请求附注状态；帖子互动使用原生已有页面 |
| Pura X Max 竖屏图片左侧光条 | Viewer 黑色底面、左右安全区覆盖，模糊背景及容器裁剪 | 编译通过，现有图片回归通过；Pura X Max 内外屏、横竖屏未实机验证 |

## 构建和验证

- `node --test`：125/125 通过，覆盖已读记录与请求、游标、视频流与播放器、通知、菜单数据、设置和本地化。
- 最新 `devecocli build`：成功；更多图标使用原生 Symbol 横线菜单。
- `devecocli run --device 5MT0225B19003950 --skip-build`：安装、启动成功。连接设备是 HUAWEI Mate 80 Pro Max，手机形态。
- 输出 HAP：`entry/build/default/outputs/default/entry-default-signed.hap`。保留工程已有版本 2.6.0 / 18。
- 记录：`outputs/feedback-20261012-tests.log`、`outputs/feedback-20261012-build.log`、`outputs/feedback-20261012-install.log`。
- 真机菜单截图：`outputs/feedback-20261012-menu01.png`。该截图证明菜单展开与动作排列，拍摄时按钮仍是随后替换的 Symbol。
- 最终按钮树：`outputs/feedback-20261012-native-bars-ui.json` 中帖子更多按钮的子节点是 SymbolGlyph。最终使用 SDK 确认存在的 line_3_horizontal。

构建、安装和脚本测试不等于折叠设备上的光条消失，也不等于 X 已接受某个账号的内容屏蔽反馈。上述未完成的实机证据均明确保留。
