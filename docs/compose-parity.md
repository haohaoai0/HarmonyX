# 发帖选项与网页 / APK 契约核对

## 功能覆盖

| 功能 | 原生实现 | 请求契约 |
| --- | --- | --- |
| 投票 | 2–4 个选项、每项 25 个 Unicode 字符、5 分钟到 7 天、增删选项、移除投票 | `caps.x.com/v2/cards/create.json` 创建卡片，`CreateTweet.card_uri` 发帖；同时要求 `status=OK` 和卡片 URI |
| 投票选项图片 | 每个选项独立选择、预览、替换、移除；草稿保留图片 URI | 原媒体上传后使用 `1906814671912599552:poll_choice_images`，每项 `twitter:image:choiceN_image:src:id=mis://MEDIA_ID` |
| 表情 | 原生搜索、分类、最近使用；插入当前光标或替换选区 | 原文 Unicode 插入正文，复用应用表情面板 |
| 定时发布 | 系统日期、时间选择器、本地时区、取消定时、查看服务端预排期帖子 | `CreateScheduledTweet`，`post_tweet_request` 与秒级 `execute_at`；列表解析 `tweet_create_request.status`、`scheduling_info.execute_at` |
| 位置 | 打开位置选择时请求设备权限、获取一次真实坐标、附近地点、搜索、选择、移除 | 网页 `/i/api/1.1/geo/places.json`，`query_type=tweet_compose_location`、`lat/long/hacc/search_term`；发帖提交 `place_id` 和 `geo_search_request_id` |
| 回复范围 | 每个人、认证账号、关注的账号、仅提及的账号、关注账号及其关注账号 | 默认省略控制字段；其他依次为 `Verified`、`Community`、`ByInvitation`、`MyNetwork` |
| 内容披露 | AI 生成、付费合作独立开关；可与定时发布组合 | 创建帖子的 `content_disclosure`；定时请求使用 `content_disclosure_options`；AI 的检测来源为 `UserDeclared` |
| 草稿 | 正文、媒体、投票、图片、时长、定时、回复范围、地点和披露一起持久化 | 本地 `ComposerDraftStore`；包含新选项时不以纯文本请求覆盖已有服务端草稿 |

## 证据来源

官方响应式网页资源保存在 `.codex/account-privacy/fresh-main.fb59cf3316c2d48ea.js` 与 `native-chunk-62988.js`。本次直接检查它们的请求构造器和操作元数据；契约摘录、字符偏移、文件 SHA-256 保存在 `outputs/compose-reference/primary-contracts.json`。创建操作元数据保存在 `verified-composer-operations.json`。

本地 APK 参考为 `D:/apk-re/chuckle/chuckle-1.1.1-154.apk` 的 JADX 输出，属于第三方 Chuckle 客户端。`u1q.java` 证实 `conversation_control`、`geo.place_id`、`geo_search_request_id` 及原发帖默认字段；其 `Followers` 枚举不能替代网页最新的 `MyNetwork`。本次没有获取官方 X APK，不能将第三方 APK 证据表述为官方 Android 实现。

已有普通发帖继续使用原 APK 操作表；带新增选项的请求使用核实过的官方网页创建操作。OAuth v2 仅发送它支持的设置，图片投票、`MyNetwork` 和定时发布需要网页登录会话。

位置 API 对照本机 SDK `@ohos.geoLocationManager.d.ts` 和 `devecocli docs read` 的官方 Location Kit 文档。声明 `APPROXIMATELY_LOCATION`、`LOCATION`，在前台动作中请求权限；允许用户只授予模糊位置。定位失败、权限拒绝、系统定位关闭都有可见提示，仍允许手动搜索。坐标仅用于查询附近地点，草稿保存选中的地点，不保存设备坐标。

## 组合限制与验证范围

投票不能附加普通图片、GIF 或视频；选项图片通过独立投票卡上传。按照网页定时映射，定时请求没有投票卡、地点和回复范围字段，界面会提示先移除这些设置。社区发帖不支持定时。服务端账号权限和接口错误直接显示，不把 HTTP 200 或缺失回执视作发布成功，也不自动重试不确定的写入。

离线验证运行实际 ArkTS 服务源码，覆盖默认请求不变、五种回复策略、披露字段、图片投票契约、草稿恢复、日期单位、设备定位权限、真实坐标传递、错误与缺失回执。命令：

```powershell
node --test tests/composer-options.test.cjs tests/post-publishing.test.cjs
devecocli build
```

离线测试 30 项通过。已在 API 26 的 HUAWEI Mate 80 Pro Max 上通过 `devecocli run` 完成编译、安装和启动；最后一次构建日志见 `outputs/compose-reference/popup-final-run.log`。

针对点击工具按钮没有弹层的问题，重新编译安装后逐个核验了表情、安排发布时间、位置、内容披露和五种回复范围。系统日期、时间选择器也能打开。收起编辑状态的回调增加异常保护，避免键盘操作异常中断弹层打开；诊断只记录弹层类型、状态码和结果数量，不记录正文或坐标。本次没有捕获旧包不弹层的确切异常，因此不将键盘异常表述为已确认根因。弹层滚动内容改为顶部对齐，投票正文区域缩短后，选项、时长和移除按钮在手机屏幕内完整显示。

真机位置结果为 `fix=true / code=0`；以真实坐标查询 X 地点接口得到 HTTP 200，返回地点数量为 0。已将当时工具读取的日志结果转录到 `outputs/compose-reference/device-validation.json`，页面状态见 `device-final-ui.json`；后续读取的 `popup-device.log` 仅保留滚动日志当前可见的记录。设备当时已授权，本轮没有重新出现系统权限弹窗；首次授权、拒绝和仅模糊位置分支另有离线测试覆盖。没有选中地点或发布测试帖子。

页面证据见 `outputs/compose-reference/device-popup-reply.jpeg`、`device-popup-emoji.jpeg`、`device-popup-location.jpeg`、`device-popup-disclosure.jpeg`、`device-poll-final.jpeg`，以及 `device-datepicker.json`、`device-timepicker.json`。网页静态资源检查与离线请求验证，不等同于新增选项被当前账号成功发布的证明。预排期列表目前提供查看；编辑、删除已有服务端预排期帖子尚未接入。
