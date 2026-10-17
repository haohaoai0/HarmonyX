# 头像取色背景

设置 → 辅助功能 → 显示 → 头像取色背景，默认关闭，保存在现有外观偏好中。
启用后覆盖通用帖子卡片、帖子详情主体、私信列表每行会话；聊天消息气泡维持既有样式。

取色算法改编自用户提供的 `icon-main-color-master.zip`：
`entry/src/main/ets/utils/ColorUtils.ets` 和 `ImageUtils.ets`，
Copyright (c) 2026 Huawei Device Co., Ltd.，Apache License 2.0。
完整许可见 [icon-main-color-Apache-2.0.txt](licenses/icon-main-color-Apache-2.0.txt)。

实现差异：

- 复用代理感知的头像本地文件缓存；40×40 BGRA 解码，不保留 PixelMap。
- 跳过透明像素和圆形裁剪外的角落，将相近色相聚合，优先提取主体彩色区域；中性头像回退 RGB 主色。
- 浅色直接将原 RGB 与白色混合，保留原色关系和饱和度差异；中性头像保持中性。
- 深色保留 HSV 色相和比例饱和度，单独压低亮度；柔和深色另加亮度偏移。
- 自动跟随应用或系统主题。开关关闭、缺失头像、下载或解码失败均回退原背景。
- 同一头像合并取色请求，缓存最多 512 个颜色结果；头像 URL 和组件代次防止旧结果串色。

新增功能无需额外权限或依赖，沿用模块既有网络权限。
