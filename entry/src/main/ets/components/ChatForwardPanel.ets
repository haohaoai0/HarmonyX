import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { ChatPerson, xChatActions } from '../services/XChatActions';
import { ProxyAvatar } from './ProxyAvatar';
import { chatInputMaterial } from '../utils/ChatMaterial';
import { DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL, STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL } from '../services/AppearanceStore';
import { materialModifier } from '../utils/SystemMaterial';

@Component
export struct ChatForwardPanel {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop sending: boolean = false;
  @Prop preview: string = '';
  onSend: (person: ChatPerson, note: string) => void = (): void => {};
  @StorageLink('harmonyx.accent_color') accent: string = '#007DFF';
  @StorageProp(STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL) materialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  @State private query: string = '';
  @State private note: string = '';
  @State private people: ChatPerson[] = [];
  @State private selected: ChatPerson | null = null;
  @State private loading: boolean = true;
  @State private failed: boolean = false;
  private generation: number = 0;
  private active: boolean = true;
  private timer: number = -1;
  aboutToAppear(): void { this.search(); }
  aboutToDisappear(): void { this.active = false; this.generation++; if (this.timer >= 0) { clearTimeout(this.timer); } }
  private async search(): Promise<void> {
    const generation: number = ++this.generation;
    this.loading = true; this.failed = false;
    try {
      const people: ChatPerson[] = await xChatActions.people(this.query, false);
      if (this.active && generation === this.generation) { this.people = people; }
    } catch (error) { if (this.active && generation === this.generation) { this.failed = true; } }
    finally { if (this.active && generation === this.generation) { this.loading = false; } }
  }
  @Builder
  private SearchBar(): void {
    Search({ value: this.query, placeholder: $r('app.string.chat_search') })
      .keyboardAppearance(KeyboardAppearance.IMMERSIVE).height(44).margin({ left: 16, right: 16 })
      .backgroundColor(Color.Transparent).borderRadius(24).clip(true).attributeModifier(materialModifier(chatInputMaterial(this.materialLevel)))
      .onChange((query: string): void => {
        this.query = query; this.generation++;
        if (this.timer >= 0) { clearTimeout(this.timer); }
        this.timer = setTimeout((): void => { this.search(); }, 250);
      })
  }
  build(): void {
    Column({ space: 8 }) {
      Navigation() { Column().height(0) }
        .title({ builder: (): void => { this.SearchBar(); }, height: 52 }, { barStyle: BarStyle.STACK })
        .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack).hideToolBar(true)
        .height(52).width('100%').backgroundColor(Color.Transparent)
      if (this.loading) { LoadingProgress().height(24).width(24).color(this.accent) }
      if (this.failed) {
        Button($r('app.string.common_retry')).backgroundColor(Color.Transparent).fontColor(this.accent).onClick((): void => { this.search(); })
      }
      List() {
        ForEach(this.people, (person: ChatPerson) => {
          ListItem() {
            Row({ space: 12 }) {
              ProxyAvatar({verifiedType: person.verifiedType ?? '', avatarShape: person.avatarShape ?? '',  url: person.avatarUrl, avatarSize: 44, radius: 22, fallbackText: person.name.substring(0, 1) })
              Column({ space: 4 }) {
                Text(person.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).maxLines(1)
                Text('@' + person.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).maxLines(1)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.selected?.id === person.id) { SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(24).fontColor([this.accent]) }
            }.padding(12).width('100%').opacity(person.canDm ? 1 : 0.45).enabled(person.canDm && !this.sending)
              .onClick((): void => { this.selected = person; })
          }
        }, (person: ChatPerson): string => person.id)
      }.layoutWeight(1).width('100%')
      Text(this.preview).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).maxLines(2)
        .width('100%').padding({ left: 16, right: 16 })
      TextInput({ text: this.note, placeholder: $r('app.string.chat_forward_note') }).fontFamily(this.appFontFamily)
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE).height(44).maxLength(1000)
        .backgroundColor($r('app.color.bg_field')).borderRadius(24).margin({ left: 16, right: 16 })
        .enabled(!this.sending).onChange((text: string): void => { this.note = text; })
      Button(this.sending ? $r('app.string.chat_forward_sending') : $r('app.string.dm_send'))
        .backgroundColor(this.accent).fontColor($r('app.color.text_on_accent')).height(44).width('90%')
        .enabled(this.selected !== null && !this.sending).onClick((): void => {
          if (this.selected !== null) { this.onSend(this.selected, this.note); }
        })
    }.width('100%').height('100%').padding({ bottom: 16 })
  }
}
