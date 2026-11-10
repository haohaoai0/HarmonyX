import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { effectiveAppLocale } from './AppLocale';

// Native Text(Resource) follows the UI locale. Strings composed in code must
// use that same locale rather than the host context's original configuration.
export class AppLocalizedResources {
  private manager: resourceManager.ResourceManager | null = null;
  private context: common.Context | null = null;
  private locale: string = '';

  text(context: common.Context, resource: Resource, locale: string = effectiveAppLocale()): string {
    if (this.manager === null || this.context !== context || this.locale !== locale) {
      const configuration: resourceManager.Configuration = context.resourceManager.getOverrideConfiguration();
      configuration.locale = locale;
      this.manager = context.resourceManager.getOverrideResourceManager(configuration);
      this.context = context;
      this.locale = locale;
    }
    return this.manager.getStringSync(resource.id);
  }
}
