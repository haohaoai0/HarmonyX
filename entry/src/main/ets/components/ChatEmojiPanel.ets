import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { ChatEmoji, ChatEmojiGroup, chatEmojiStore } from '../services/ChatEmojiStore';
import { ChatEmojiText } from './ChatEmojiText';
import { chatInputMaterial } from '../utils/ChatMaterial';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL, STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL } from '../services/AppearanceStore';
import { materialModifier } from '../utils/SystemMaterial';
import { MaterialSurfaceHost } from './MaterialSurfaceHost';

interface EmojiRow { id: string; group: string; entries: ChatEmoji[]; }
class EmojiRows implements IDataSource {
  private rows: EmojiRow[];
  constructor(groups: ChatEmojiGroup[]) {
    this.rows = [];
    groups.forEach((group: ChatEmojiGroup): void => {
      this.rows.push({ id: group.id, group: group.id, entries: [] });
      for (let i: number = 0; i < group.entries.length; i += 7) {
        this.rows.push({ id: group.id + ':' + i.toString(), group: '', entries: group.entries.slice(i, i + 7) });
      }
    });
  }
  totalCount(): number { return this.rows.length; }
  getData(index: number): EmojiRow { return this.rows[index]; }
  registerDataChangeListener(_listener: DataChangeListener): void {}
  unregisterDataChangeListener(_listener: DataChangeListener): void {}
}

@Component
export struct ChatEmojiPanel {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  onSelect: (emoji: string) => void = (): void => {};
  @StorageProp(STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL) materialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  @State private query: string = '';
  @State private rows: EmojiRows = new EmojiRows([]);
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void { this.search(); }
  private search(): void {
    this.rows = new EmojiRows(chatEmojiStore.search(getContext(this) as common.UIAbilityContext, this.query));
    this.scroller.scrollEdge(Edge.Top);
  }
  private groupLabel(group: string): Resource {
    if (group === 'recent') { return $r('app.string.chat_emoji_recent'); }
    if (group === 'smileys') { return $r('app.string.chat_emoji_smileys'); }
    if (group === 'people') { return $r('app.string.chat_emoji_people'); }
    if (group === 'animals') { return $r('app.string.chat_emoji_animals'); }
    if (group === 'food') { return $r('app.string.chat_emoji_food'); }
    if (group === 'travel') { return $r('app.string.chat_emoji_travel'); }
    if (group === 'activities') { return $r('app.string.chat_emoji_activities'); }
    if (group === 'objects') { return $r('app.string.chat_emoji_objects'); }
    if (group === 'symbols') { return $r('app.string.chat_emoji_symbols'); }
    return $r('app.string.chat_emoji_flags');
  }
  @Builder
  private SearchBar(): void {
    Search({ value: this.query, placeholder: $r('app.string.chat_search') })
      .keyboardAppearance(KeyboardAppearance.IMMERSIVE).height(44)
      .fontColor($r('app.color.text_primary')).backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_field'))
      .borderRadius(24).clip(!SystemMaterialUtil.isApi26OrAbove()).attributeModifier(materialModifier(chatInputMaterial(this.materialLevel))).margin({ left: 16, right: 16 })
      .onChange((value: string): void => { this.query = value; this.search(); })
  }
  build(): void {
    Column() {
      MaterialSurfaceHost({ surfaceHeight: 52, surfaceContent: (): void => { this.SearchBar(); } })
        .height(52).width('100%').backgroundColor(Color.Transparent)
        .clip(false)
      List({ scroller: this.scroller }) {
        LazyForEach(this.rows, (row: EmojiRow) => {
          ListItem() {
            if (row.group.length > 0) {
              Text(this.groupLabel(row.group)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary')).width('100%').padding({ left: 12, top: 16, bottom: 8 })
            } else {
              Row() {
                ForEach(row.entries, (entry: ChatEmoji) => {
                  Button({ type: ButtonType.Normal }) {
                    ChatEmojiText({ text: entry.emoji, fontSize: $r('app.float.chat_emoji_picker_size') })
                  }
                    .width('14.2857%').height(52).padding(0).borderRadius(16).backgroundColor(Color.Transparent)
                    .accessibilityText(entry.keywords.length > 0 ? entry.keywords : entry.name)
                    .onClick((): void => { this.onSelect(entry.emoji); })
                }, (entry: ChatEmoji): string => entry.emoji)
              }.width('100%')
            }
          }
        }, (row: EmojiRow): string => row.id)
      }.layoutWeight(1).width('100%').padding({ left: 8, right: 8, bottom: 16 }).scrollBar(BarState.Off)
    }.width('100%').height('100%')
  }
}
