# 私信动态照片

从私信的「照片和视频」选择器选择鸿蒙动态照片后，输入框显示一张可播放的预览。
发送端使用系统接口导出原始图片和带声音的视频，两份资源沿用 XChat 的加密媒体上传，
在同一条签名消息中发送。支持该功能的 HarmonyX 客户端将两份附件显示为一张动态照片卡片。

## 配对协议 v1

配对标识使用现有媒体描述符的 `filename` 字段。该字段参与 XChat 消息的签名和加密，
不向正文添加标记，也不向服务端发送自定义消息类型。

- 图片：`HXMP_v1_<UUID>_image.jpg`，媒体类型为 image。
- 视频：`HXMP_v1_<UUID>_video.mp4`，媒体类型为 video。
- 在一条消息内匹配相同 UUID，要求恰好一份有效图片和一份有效视频，且媒体 hash 不同。
- 附件顺序可以颠倒。缺少资源、重复角色、未知协议版本、错误类型或无效标识保持普通附件展示。
- 不跨消息配对，不根据时长、相邻位置或「一图一视频」猜测。

其他客户端收到的是标准图片和视频附件。只有支持此协议的客户端会合并显示。
转发沿用两份附件的文件名，新消息仍可以识别为动态照片。

## 资源与生命周期

使用 picker 授予的 URI 查询 PhotoAsset 子类型，读取动态照片时请求 `HIGH_QUALITY_MODE`。
按官方 picker 使用方式，无需增加全相册读取权限。
调用 `MovingPhoto.requestContent` 拆分，接收后通过 `MediaAssetManager.loadMovingPhoto`
构造沙箱中的动态照片，以原生 `MovingPhotoView` 播放。

`MovingPhoto` 含有 NAPI 原生句柄，不能经由 `@Prop` 深拷贝后传给播放器。
卡片以普通字段保留原实例，以独立布尔状态触发渲染；选择预览和接收后的播放遵循同一规则。

两份资源全部上传完成后才发送消息。上传失败或发送结果不确定时保留原配对标识、上传结果和消息 ID，
相同内容重试复用它们。成功发送、丢弃附件、清理缓存或切换账号时清理导出文件；
首次加载媒体缓存时清理上次进程中断遗留的导出文件。

先显示已下载的封面，视频准备完成后启用播放。自动下载分别遵循照片和视频设置，手动点击可以下载。
播放保留音轨，切出页面或移出可见区域时停止，并与语音消息共用单一播放所有权。
单击照片播放；左上角「实况」角标展开「关闭实况 / 重新播放」，关闭后可从同一菜单重新开启。
实况开关仅控制当前卡片的显示，不删除消息附件。右下角声音按钮切换静音。
角标、声音按钮和展开菜单均使用 `Navigation` 的自定义堆叠标题栏承载系统材质。
现有消息最多四份媒体附件，因此一条消息最多发送两张动态照片，或与普通媒体混合选择。

图片、视频和动态照片不再使用消息背景色包裹；文字说明单独显示在文本气泡中。
单张媒体按原始比例一起缩小，最大 240×280 vp；相册最大 320×320 vp，
根据每张图片比例选择并排、多行或左大右小布局，极端比例仅在相册预览中做适度裁切。
`resourceManager.getNumber` 返回带单位 float 的 px 值，参与布局计算前必须使用当前 UIContext 的 `px2vp`。
布局几何独立持有状态，窗口或媒体原始尺寸变化时重新计算，避免 Builder 参数持有初始布局。
卡片使用互斥长按与点击，不用全幅透明按钮、事件独占或高优先级手势。
长按成功打开消息菜单后，本次触摸不会再触发图片查看器或实况播放。
滑动由会话 List 的原生手势识别；长按仍显示原有回复、转发、保存等消息菜单。
实况和声音按钮用 RelativeContainer 相对容器定位到左上角和右下角，材质继续由 Navigation 标题栏承载。
图片点击进入现有 PhotoViewer，视频进入复用 SurfaceVideoPlayer 的薄页面。
视频封面与尺寸包含 `videoOrientation` 旋转信息；视频页面顶部避让状态栏，底部避让导航指示条。
解密后的沙箱文件通过本地 FD 打开；不进入 HTTP 代理或公共媒体缓存，并保留会话禁截屏设置。

## 验证

```powershell
node --test tests/chat-album-layout.test.cjs tests/chat-local-video.test.cjs tests/chat-local-viewer-services.test.cjs tests/chat-moving-photo.test.cjs tests/xchat-media.test.cjs tests/xchat-service.test.cjs tests/chat-voice.test.cjs tests/xchat-inbox-actions.test.cjs
cargo test --locked --offline --manifest-path native/xchat/Cargo.toml
devecocli build --modules entry
```

原生测试验证配对文件名经过实际 XChat 签名、加密和解密后完整保留。
本地测试不替代两台鸿蒙设备之间的真实服务端收发验证。
