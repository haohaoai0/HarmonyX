import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { offlineReadingStore, OfflineReadingEntry, STORAGE_KEY_OFFLINE_READING_REVISION } from '../services/OfflineReadingStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { fieldSurfaceColor, pageCanvasColor } from '../utils/ThemeColors';
import type { ThreadReaderRouteParam } from '../pages/ThreadReader';
import { STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';

@Component
export struct OfflineReadingLibrary {
  @Consume('pageStack') private pageStack: NavPathStack;
  @BuilderParam header: () => void;
  @Prop topInset: number = 0;
  @Prop bottomInset: number = 0;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accent: string = '#007DFF';
  @StorageProp(STORAGE_KEY_OFFLINE_READING_REVISION) @Watch('reload') private revision: number = 0;
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('reload') private accountsRevision: number = 0;
  @State private entries: OfflineReadingEntry[] = [];
  @State private query: string = '';
  @State private unreadOnly: boolean = false;
  @State private images: boolean = false;
  @State private editing: boolean = false;
  @State private tags: string = '';
  @State private note: string = '';
  @State private unread: boolean = true;
  @State private failed: boolean = false;
  private editingId: string = '';
  private account: string = '';
  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }
  aboutToAppear(): void { this.account = offlineReadingStore.account(this.context()); this.reload(); }
  private reload(): void {
    if (this.account !== offlineReadingStore.account(this.context())) { this.editing = false; this.editingId = ''; }
    this.account = offlineReadingStore.account(this.context());
    this.entries = offlineReadingStore.entries(this.context());
    try { this.images = offlineReadingStore.includeImages(this.context()); } catch (_error) { this.failed = true; }
  }
  private visible(): OfflineReadingEntry[] {
    const query: string = this.query.trim().toLowerCase();
    return this.entries.filter((entry: OfflineReadingEntry): boolean => (!this.unreadOnly || entry.unread) &&
      (query.length === 0 || (entry.title + '\n' + entry.author + '\n' + entry.tags.join(' ') + '\n' + entry.note).toLowerCase().includes(query)));
  }
  private edit(entry: OfflineReadingEntry): void {
    this.editingId = entry.id; this.tags = entry.tags.join(', '); this.note = entry.note;
    this.unread = entry.unread; this.failed = false; this.editing = true;
  }
  private save(): void {
    if (this.account !== offlineReadingStore.account(this.context())) { this.reload(); return; }
    try {
      offlineReadingStore.update(this.context(), this.editingId, this.tags, this.note, this.unread);
      this.editing = false; this.reload();
    } catch (_error) { this.failed = true; }
  }
  private async remove(entry: OfflineReadingEntry): Promise<void> {
    const account: string = this.account;
    const answer = await promptAction.showDialog({ title: this.text($r('app.string.offline_delete')),
      message: entry.title, buttons: [{ text: this.text($r('app.string.compose_cancel')), color: this.accent },
        { text: this.text($r('app.string.offline_delete')), color: this.accent }] });
    if (answer.index !== 1 || account !== offlineReadingStore.account(this.context())) { return; }
    try { offlineReadingStore.remove(this.context(), entry.id); this.reload(); } catch (_error) { this.failed = true; }
  }
  @Builder
  private Editor(): void {
    Column({ space: 16 }) {
      Text($r('app.string.offline_edit')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M'))
        .fontColor($r('app.color.text_primary'))
      TextInput({ text: this.tags, placeholder: $r('app.string.offline_tags_hint') }).onChange((value: string): void => { this.tags = value; })
        .maxLength(800).accessibilityText($r('app.string.offline_tags'))
      TextArea({ text: this.note, placeholder: $r('app.string.offline_note') }).height(140).maxLength(4000)
        .onChange((value: string): void => { this.note = value; }).accessibilityText($r('app.string.offline_note'))
      Row({ space: 12 }) {
        Text($r('app.string.offline_unread')).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.unread }).selectedColor(this.accent)
          .accessibilityText($r('app.string.offline_unread')).onChange((value: boolean): void => { this.unread = value; })
      }.width('100%')
      if (this.failed) { Text($r('app.string.offline_save_failed')).fontColor($r('app.color.text_secondary')) }
      Button($r('app.string.offline_done')).width('100%').backgroundColor(this.accent).fontColor($r('app.color.text_on_accent'))
        .onClick((): void => this.save())
    }.width('100%').padding(24)
  }
  @Builder
  private Entry(entry: OfflineReadingEntry): void {
    Column({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            if (entry.unread) { Text($r('app.string.offline_unread')).fontColor(this.accent).fontSize($r('sys.float.Caption_L')) }
            Text(Math.round(entry.progress * 100).toString() + '%').fontColor($r('app.color.text_secondary')).fontSize($r('sys.float.Caption_L'))
            if (!entry.complete || !entry.imagesComplete) {
              Text($r('app.string.offline_partial')).fontColor($r('app.color.text_secondary')).fontSize($r('sys.float.Caption_L'))
            }
          }.width('100%')
          Text(entry.title).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Medium).fontFamily(this.appFontFamily)
            .fontColor($r('app.color.text_primary')).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          Text(entry.author).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
          if (entry.tags.length > 0) { Text(entry.tags.join(' · ')).fontSize($r('sys.float.Body_M')).fontColor(this.accent) }
          if (entry.note.length > 0) { Text(entry.note).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').padding(0).backgroundColor(Color.Transparent).onClick((): void => {
        const param: ThreadReaderRouteParam = { offlineId: entry.id };
        this.pageStack.pushPath({ name: 'ThreadReader', param: param });
      })
      Row() {
        Button($r('app.string.offline_edit')).fontColor(this.accent).backgroundColor(Color.Transparent)
          .onClick((): void => this.edit(entry))
        Blank()
        Button($r('app.string.offline_delete')).fontColor($r('app.color.text_secondary')).backgroundColor(Color.Transparent)
          .onClick((): void => { void this.remove(entry); })
      }.width('100%')
    }.width('100%').padding(16).borderRadius(16).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
  }
  build(): void {
    List({ space: 12 }) {
      ListItem() {
        Column({ space: 10 }) {
          this.header()
          Search({ value: this.query, placeholder: $r('app.string.offline_search') }).onChange((value: string): void => { this.query = value; })
          Row({ space: 12 }) {
            Text($r('app.string.offline_unread_only')).fontColor($r('app.color.text_primary')).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.unreadOnly }).selectedColor(this.accent)
              .accessibilityText($r('app.string.offline_unread_only')).onChange((value: boolean): void => { this.unreadOnly = value; })
          }.width('100%')
          Row({ space: 12 }) {
            Text($r('app.string.offline_images')).fontColor($r('app.color.text_primary')).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.images }).selectedColor(this.accent)
              .accessibilityText($r('app.string.offline_images')).onChange((value: boolean): void => {
                try { offlineReadingStore.setIncludeImages(this.context(), value); this.images = value; }
                catch (_error) { this.failed = true; }
              })
          }.width('100%')
          Text($r('app.string.offline_intro')).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
          if (this.visible().length === 0) { Text($r('app.string.offline_empty')).fontColor($r('app.color.text_secondary')).padding(24) }
          if (this.failed && !this.editing) { Text($r('app.string.offline_save_failed')).fontColor($r('app.color.text_secondary')) }
        }.width('100%')
      }
      ForEach(this.visible(), (entry: OfflineReadingEntry): void => {
        ListItem() { this.Entry(entry) }
      }, (entry: OfflineReadingEntry): string => entry.id)
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: this.topInset, bottom: this.bottomInset + 16 })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, ''))
      .bindSheet($$this.editing, this.Editor, { height: SheetSize.FIT_CONTENT, showClose: true,
        backgroundColor: fieldSurfaceColor(this.displayMode, this.darkSurface) })
  }
}
