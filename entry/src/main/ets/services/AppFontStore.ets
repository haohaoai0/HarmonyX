import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';
import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';

export const APP_FONT_FAMILY_KEY: string = 'harmonyx.app_font_family';
export const APP_FONT_NAME_KEY: string = 'harmonyx.app_font_name';
export const DEFAULT_APP_FONT_FAMILY: string = 'HarmonyOS Sans';

export class FontImportResult {
  applied: boolean = false;
  cancelled: boolean = false;
  error: string = '';

  constructor(applied: boolean, cancelled: boolean, error: string) {
    this.applied = applied;
    this.cancelled = cancelled;
    this.error = error;
  }
}

export class AppFontStore {
  private static readonly STORE_NAME: string = 'harmonyx_app_font';
  private static readonly PATH_KEY: string = 'path';
  private static readonly NAME_KEY: string = 'name';
  private static readonly FAMILY_KEY: string = 'family';
  private path: string = '';
  private name: string = '';
  private family: string = DEFAULT_APP_FONT_FAMILY;
  private restorePromise: Promise<void> | null = null;
  private registeredFamily: string = '';
  private registeredContext: UIContext | null = null;

  initialize(context: common.UIAbilityContext): void {
    this.registeredFamily = '';
    this.registeredContext = null;
    this.restorePromise = null;
    try {
      const store: preferences.Preferences = this.preferences(context);
      this.path = store.getSync(AppFontStore.PATH_KEY, '') as string;
      this.name = store.getSync(AppFontStore.NAME_KEY, '') as string;
      this.family = store.getSync(AppFontStore.FAMILY_KEY, DEFAULT_APP_FONT_FAMILY) as string;
    } catch (error) {
      this.path = '';
      this.name = '';
      this.family = DEFAULT_APP_FONT_FAMILY;
    }
    AppStorage.setOrCreate<string>(APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY);
    AppStorage.setOrCreate<string>(APP_FONT_NAME_KEY, this.name);
  }

  async restore(context: common.UIAbilityContext, uiContext: UIContext): Promise<void> {
    if (this.path.length === 0 ||
      (this.registeredFamily === this.family && this.registeredContext === uiContext)) { return; }
    if (this.restorePromise !== null) {
      await this.restorePromise;
      if (this.path.length > 0 && this.registeredContext !== uiContext) {
        await this.restore(context, uiContext);
      }
      return;
    }
    this.restorePromise = this.registerSavedFont(context, uiContext);
    await this.restorePromise;
    this.restorePromise = null;
  }

  private async registerSavedFont(context: common.UIAbilityContext, uiContext: UIContext): Promise<void> {
    try {
      if (!this.family.startsWith('HarmonyXCustom') || !fileIo.accessSync(this.path)) {
        throw new Error('missing');
      }
      await uiContext.getFont().registerFont({ familyName: this.family, familySrc: 'file://' + this.path });
      this.registeredFamily = this.family;
      this.registeredContext = uiContext;
      AppStorage.setOrCreate<string>(APP_FONT_FAMILY_KEY, this.family);
    } catch (error) {
      await this.clear(context);
    }
  }

  async importFont(context: common.UIAbilityContext, uiContext: UIContext): Promise<FontImportResult> {
    if (this.restorePromise !== null) { await this.restorePromise; }
    let uris: string[] = [];
    try {
      const dialog: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const options: picker.DocumentSelectOptions = {
        maxSelectNumber: 1,
        fileSuffixFilters: ['TrueType|.ttf', 'OpenType|.otf', 'TrueType Collection|.ttc']
      };
      uris = await dialog.select(options);
    } catch (error) {
      const message: string = (error as Error).message ?? '';
      return new FontImportResult(false, message.toLowerCase().indexOf('cancel') >= 0, 'picker');
    }
    if (uris.length === 0) { return new FontImportResult(false, true, ''); }
    const uri: string = uris[0];
    const encodedName: string = uri.substring(uri.lastIndexOf('/') + 1).split('?')[0];
    let name: string = encodedName;
    try { name = decodeURIComponent(encodedName); } catch (error) { }
    const dot: number = name.lastIndexOf('.');
    const extension: string = dot >= 0 ? name.substring(dot).toLowerCase() : '';
    if (extension !== '.ttf' && extension !== '.otf' && extension !== '.ttc') {
      return new FontImportResult(false, false, 'format');
    }
    const directory: string = context.filesDir + '/fonts';
    const suffix: string = Date.now().toString();
    const newPath: string = directory + '/custom-' + suffix + extension;
    const newFamily: string = 'HarmonyXCustom' + suffix;
    try {
      if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory); }
      const source: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try { fileIo.copyFileSync(source.fd, newPath); } finally { fileIo.closeSync(source.fd); }
      const size: number = fileIo.statSync(newPath).size;
      if (size === 0) { throw new Error('empty'); }
    } catch (error) {
      this.remove(newPath);
      return new FontImportResult(false, false, 'read');
    }
    try {
      await uiContext.getFont().registerFont({ familyName: newFamily, familySrc: 'file://' + newPath });
    } catch (error) {
      this.remove(newPath);
      return new FontImportResult(false, false, 'register');
    }
    const previousPath: string = this.path;
    try {
      await this.save(context, newPath, name, newFamily);
    } catch (error) {
      this.remove(newPath);
      return new FontImportResult(false, false, 'save');
    }
    this.path = newPath;
    this.name = name;
    this.family = newFamily;
    this.registeredFamily = newFamily;
    this.registeredContext = uiContext;
    AppStorage.setOrCreate<string>(APP_FONT_NAME_KEY, name);
    AppStorage.setOrCreate<string>(APP_FONT_FAMILY_KEY, newFamily);
    if (previousPath.length > 0 && previousPath !== newPath) { this.remove(previousPath); }
    return new FontImportResult(true, false, '');
  }

  async clear(context: common.UIAbilityContext): Promise<boolean> {
    const previousPath: string = this.path;
    try {
      await this.save(context, '', '', DEFAULT_APP_FONT_FAMILY);
    } catch (error) {
      return false;
    }
    this.path = '';
    this.name = '';
    this.family = DEFAULT_APP_FONT_FAMILY;
    this.registeredFamily = '';
    this.registeredContext = null;
    AppStorage.setOrCreate<string>(APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY);
    AppStorage.setOrCreate<string>(APP_FONT_NAME_KEY, '');
    if (previousPath.length > 0) { this.remove(previousPath); }
    return true;
  }

  private preferences(context: common.UIAbilityContext): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: AppFontStore.STORE_NAME });
  }

  private async save(context: common.UIAbilityContext, path: string, name: string, family: string): Promise<void> {
    const store: preferences.Preferences = this.preferences(context);
    try {
      store.putSync(AppFontStore.PATH_KEY, path);
      store.putSync(AppFontStore.NAME_KEY, name);
      store.putSync(AppFontStore.FAMILY_KEY, family);
      await store.flush();
    } catch (error) {
      try {
        store.putSync(AppFontStore.PATH_KEY, this.path);
        store.putSync(AppFontStore.NAME_KEY, this.name);
        store.putSync(AppFontStore.FAMILY_KEY, this.family);
        await store.flush();
      } catch (rollbackError) { }
      throw new Error('font_preference_save_failed');
    }
  }

  private remove(path: string): void {
    try { if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); } } catch (error) { }
  }
}

export const appFontStore: AppFontStore = new AppFontStore();
