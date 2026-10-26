import { hdsMaterial, TitleBarStyleOptions } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';

// HDS owns button geometry, materials and safe-area avoidance on media pages.
export function mediaViewerTitleBarStyle(): TitleBarStyleOptions {
  const options: TitleBarStyleOptions = {
    originalStyle: {
      backgroundStyle: { backgroundColor: Color.Transparent },
      contentStyle: {
        titleStyle: { mainTitleColor: $r('app.color.text_on_brand') },
        menuStyle: { iconColor: $r('app.color.text_on_brand') },
        backIconStyle: { iconColor: $r('app.color.text_on_brand') }
      }
    }
  };
  if (deviceInfo.apiAvailable('6.1.0(23)')) {
    options.systemMaterialEffect = {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
  }
  return options;
}
