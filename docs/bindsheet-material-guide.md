# HarmonyOS：给 bindSheet 添加系统材质

适用于 ArkTS / ArkUI 的 Stage 模型工程。本文介绍 HarmonyOS 7 / API 26.0.0 的原生沉浸式材质。

**接入位置是 `bindSheet` 第三个参数里的 `SheetOptions.systemMaterial`。** 用 `uiMaterial.ImmersiveMaterial` 创建材质对象，弹层背景保持透明，内容区域也不要铺一整面不透明背景。[官方半模态文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-sheet-transition#sheetoptions)

## 1. 已经有 bindSheet，主要加这几行

先导入：

```typescript
import { uiMaterial } from '@kit.ArkUI';
```

在 **API 26.0.0 及以上的运行分支** 中，给现有 options 加材质：

```typescript
.bindSheet($$this.showSheet, this.SheetContent(), {
  // 保留你原来的高度、档位、回调等配置。
  height: SheetSize.MEDIUM,
  backgroundColor: Color.Transparent,
  blurStyle: BlurStyle.NONE,
  systemMaterial: new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.REGULAR,
    interactive: false,
    lightEffect: null
  })
})
```

这里的 `this.showSheet` 和 `this.SheetContent()` 换成你的状态变量和 builder。如果还要兼容旧系统，直接用下一节的写法。

`interactive: false` 关闭材质的交互形变，`lightEffect: null` 关闭光感交互反馈；这是本示例的选择，不是开启材质的必要条件。[官方材质 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-uimaterial#immersiveoptions)

注意，给触发按钮调用 `.systemMaterial(...)`，改变的是按钮外观。要改变整个弹层，应使用上面的 `SheetOptions.systemMaterial`。

## 2. 带版本判断和开关的完整页面

编译环境需要包含 API 26.0.0 的 SDK，工程的 `targetSdkVersion` 使用 `26.0.0` 或更高的有效版本。`compatibleSdkVersion` 按项目实际最低支持版本保留；运行时再判断是否启用新材质。**版本判断不能让旧 SDK 编译它不认识的 API。**

下面示例使用 `@Component` 和 `$$` 双向绑定。已有 `@ComponentV2` 工程请保持自己的组件与状态管理体系，不要直接混用装饰器。

```typescript
import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

@Entry
@Component
struct SheetMaterialDemo {
  @State showSheet: boolean = false;
  @State materialEnabled: boolean = true;

  private makeSheetOptions(): SheetOptions {
    const options: SheetOptions = {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: true,
      backgroundColor: $r('app.color.sheet_demo_surface')
    };

    // 新材质的构造与设置都放在版本判断内部。
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.materialEnabled) {
        options.backgroundColor = Color.Transparent;
        options.blurStyle = BlurStyle.NONE;
        options.systemMaterial = new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.REGULAR,
          interactive: false,
          lightEffect: null
        });
      } else {
        // API 26 上明确关闭该弹层的系统材质。
        options.systemMaterial = uiMaterial.Material.empty;
      }
    }

    // 旧系统保留上面定义的普通背景，不构造新材质。
    return options;
  }

  @Builder
  SheetContent() {
    Column({ space: $r('app.float.sheet_demo_spacing') }) {
      Text($r('app.string.sheet_demo_title'))
        .fontSize($r('app.float.sheet_demo_title_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.sheet_demo_text'))

      Text($r('app.string.sheet_demo_body'))
        .fontColor($r('app.color.sheet_demo_text'))

      Button($r('app.string.sheet_demo_close'))
        .onClick(() => {
          this.showSheet = false;
        })
    }
    .width('100%')
    .height('100%')
    .padding($r('app.float.sheet_demo_padding'))
    .backgroundColor(Color.Transparent)
  }

  build() {
    Column({ space: $r('app.float.sheet_demo_spacing') }) {
      Row({ space: $r('app.float.sheet_demo_spacing') }) {
        Text($r('app.string.sheet_demo_switch'))
          .fontColor($r('app.color.sheet_demo_text'))
        Toggle({ type: ToggleType.Switch, isOn: this.materialEnabled })
          .onChange((value: boolean) => {
            this.materialEnabled = value;
          })
      }

      Button($r('app.string.sheet_demo_open'))
        .onClick(() => {
          this.showSheet = true;
        })
        .bindSheet($$this.showSheet, this.SheetContent(), this.makeSheetOptions())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.sheet_demo_background'))
  }
}
```

示例的开关默认开启，方便观察；需要默认关闭时，把 `materialEnabled` 的初始值改为 `false`。这里的开关只保存在页面状态中，需要跨启动保留时再接入项目的 Preferences 设置存储。

`deviceInfo.apiAvailable('26.0.0')` 用来检查当前设备是否支持该版本。使用 API 26 工具链提供的版本检查方式，不要只用系统名称或机型判断。[官方设备信息 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-device-info#deviceinfoapiavailable)

### 示例需要的资源

把以下条目合并到对应资源文件的数组中，保留已有条目。页面使用的尺寸和颜色也通过 `$r(...)` 引用。

`entry/src/main/resources/base/element/string.json`：

```json
{
  "string": [
    { "name": "sheet_demo_title", "value": "弹层材质" },
    { "name": "sheet_demo_body", "value": "材质由原生半模态容器绘制。" },
    { "name": "sheet_demo_open", "value": "打开弹层" },
    { "name": "sheet_demo_close", "value": "完成" },
    { "name": "sheet_demo_switch", "value": "启用系统材质" }
  ]
}
```

项目有 `en`、`zh_CN` 等语言目录时，在每种语言的 `element/string.json` 中补齐相同名称的翻译。

`entry/src/main/resources/base/element/float.json`：

```json
{
  "float": [
    { "name": "sheet_demo_spacing", "value": "16vp" },
    { "name": "sheet_demo_padding", "value": "24vp" },
    { "name": "sheet_demo_title_size", "value": "20fp" }
  ]
}
```

`entry/src/main/resources/base/element/color.json`：

```json
{
  "color": [
    { "name": "sheet_demo_surface", "value": "#FFFFFFFF" },
    { "name": "sheet_demo_text", "value": "#FF18202A" },
    { "name": "sheet_demo_background", "value": "#FFDCE8F5" }
  ]
}
```

`entry/src/main/resources/dark/element/color.json`：

```json
{
  "color": [
    { "name": "sheet_demo_surface", "value": "#FF20242A" },
    { "name": "sheet_demo_text", "value": "#FFF1F4F8" },
    { "name": "sheet_demo_background", "value": "#FF142236" }
  ]
}
```

这里使用系统 Kit，无需额外安装第三方依赖，也不需要为材质本身添加权限。

## 3. 怎么选择材质厚度

调整 `style` 即可，不需要自己叠加多层模糊。SDK 提供以下五档：[ImmersiveStyle 官方说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-uimaterial#immersivestyle)

| 枚举 | 特点 |
| --- | --- |
| `uiMaterial.ImmersiveStyle.ULTRA_THIN` | 极薄，透明感最强 |
| `uiMaterial.ImmersiveStyle.THIN` | 薄，保留较多背景信息 |
| `uiMaterial.ImmersiveStyle.REGULAR` | 常规厚度 |
| `uiMaterial.ImmersiveStyle.THICK` | 厚，背景模糊较强 |
| `uiMaterial.ImmersiveStyle.ULTRA_THICK` | 极厚，背景模糊很强 |

建议先试 `REGULAR`，内容密集时再比较 `THICK`、`ULTRA_THICK`。这是调试起点，最终以文字可读性和实际设备效果为准。

## 4. 已经设置了，为什么看不到效果

按下面顺序检查：

1. **运行设备版本**：确认版本判断结果为 `true`，同时确认使用的是 API 26 SDK。
2. **配置位置**：材质应放在 `bindSheet(..., ..., options)` 的 `options.systemMaterial` 中。
3. **弹层背板**：启用时设置 `backgroundColor: Color.Transparent`，移除旧模糊或设置 `blurStyle: BlurStyle.NONE`。
4. **内容背景**：检查 builder 的根 `Column`、`Stack`、列表等是否铺满了白色或黑色背景。全幅实色会挡住材质；局部业务卡片可以保留自己的背景。
5. **材质赋色**：先不传 `materialColor`；若要染色，使用带透明度的颜色资源，避免完全不透明的赋色覆盖滤镜。
6. **观察条件**：单一纯色背景很难看出模糊，放到已有图片或彩色列表页面上比较。设备算力和系统沉浸光感设置也会影响表现。

官方明确说明，背景色和旧背景模糊可能覆盖材质层，低算力设备也会使用不同的视觉表现。[官方常见问题](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-faq)

接入已有项目时，保留原 options 的 `height`、`detents`、`preferType`、圆角、键盘配置、关闭拦截和回调；只调整材质相关属性。旧系统或关闭开关时恢复原来的背景与模糊。上面完整示例的普通背景只是示例默认值。

## 5. 是否要在 module.json5 全局开启

给单个 Sheet 显式配置材质，可以使用组件级入口，不需要为了这个弹层额外打开应用级 `enable`。应用级开关会影响更多组件，按项目需求选择。[官方沉浸光感指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense)

如果项目已经开启全局材质，**`systemMaterial: undefined` 表示未显式设置，不等于强制关闭**。要明确关闭该 Sheet，在 API 26 分支中设置：

```typescript
options.systemMaterial = uiMaterial.Material.empty;
```

随后恢复普通背景及原有模糊配置。[Material.empty 官方说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-uimaterial#empty)

## 6. 接入后怎么验收

- 编译页面，检查资源名称、导入和 API 版本是否正确。
- 在 API 26 设备上比较开关开启、关闭，以及五档厚度。
- 在浅色和深色主题下检查文字、图标、输入框的对比度。
- 检查拖动、关闭、键盘与原有关闭拦截是否正常。
- 覆盖项目最低支持版本，确认回退背景仍然可读。

本文依据官方文档、本地 SDK `26.0.0.105` 声明及 HarmonyX 当前实现核对 API 用法；文中的独立示例未单独构建或做真机效果验证。
