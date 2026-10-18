import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { SpaceDraft, SPACE_TITLE_LIMIT, SPACE_TOPIC_KEYS, SPACE_TOPIC_LIMIT, SPACE_SCHEDULE_DAYS } from '../models/SpaceDraft';
import { spaceDraftStore } from '../services/SpaceDraftStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSurfaceColor } from '../utils/ThemeColors';

@Builder
export function SpaceDraftBuilder(): void { SpaceDraftPage(); }

@Component
struct SpaceDraftPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private title: string = '';
  @State private record: boolean = true;
  @State private topics: string[] = [];
  @State private scheduled: boolean = false;
  @State private scheduledStart: number = Date.now() + 3600000;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const draft: SpaceDraft = spaceDraftStore.load(getContext(this) as common.UIAbilityContext);
    this.title = draft.title; this.record = draft.record; this.topics = draft.topics;
    this.scheduled = draft.scheduledStart > 0;
    this.scheduledStart = draft.scheduledStart > Date.now() ? draft.scheduledStart : Date.now() + 3600000;
  }
  aboutToDisappear(): void { this.save(false); }
  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }
  private draft(): SpaceDraft {
    const draft: SpaceDraft = new SpaceDraft();
    draft.title = this.title; draft.record = this.record; draft.topics = this.topics;
    draft.scheduledStart = this.scheduled ? this.scheduledStart : 0; return draft;
  }
  private save(validate: boolean): boolean {
    if (validate && this.title.trim().length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.spaces_draft_title_required')) }); return false;
    }
    if (validate && this.scheduled && !SpaceDraft.scheduleValid(this.scheduledStart, Date.now())) {
      promptAction.showToast({ message: this.text($r('app.string.spaces_draft_schedule_invalid')) }); return false;
    }
    if (!spaceDraftStore.save(getContext(this) as common.UIAbilityContext, this.draft())) {
      promptAction.showToast({ message: this.text($r('app.string.spaces_save_failed')) }); return false;
    }
    return true;
  }
  private topicTitle(index: number): Resource {
    const titles: Resource[] = [$r('app.string.spaces_topic_technology'), $r('app.string.spaces_topic_music'),
      $r('app.string.spaces_topic_science'), $r('app.string.spaces_topic_entertainment'),
      $r('app.string.spaces_topic_arts'), $r('app.string.spaces_topic_sports')];
    return titles[index];
  }
  private toggleTopic(key: string): void {
    if (this.topics.indexOf(key) >= 0) { this.topics = this.topics.filter((value: string): boolean => value !== key); }
    else if (this.topics.length < SPACE_TOPIC_LIMIT) { this.topics = [...this.topics, key]; }
    else { promptAction.showToast({ message: this.text($r('app.string.spaces_draft_topics_limit')) }); }
  }
  private changeDate(date: Date): void {
    const current: Date = new Date(this.scheduledStart);
    this.scheduledStart = new Date(date.getFullYear(), date.getMonth(), date.getDate(), current.getHours(), current.getMinutes()).getTime();
  }
  private changeTime(value: TimePickerResult): void {
    const current: Date = new Date(this.scheduledStart);
    this.scheduledStart = new Date(current.getFullYear(), current.getMonth(), current.getDate(),
      value.hour ?? current.getHours(), value.minute ?? current.getMinutes()).getTime();
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Column() {
        Scroll(this.scroller) {
          Column({ space: 24 }) {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.music_note_mic')).fontSize(36).fontColor([$r('app.color.space_accent')])
              Text($r('app.string.spaces_draft_intro')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.text_secondary')).layoutWeight(1)
            }.width('100%').padding(16).borderRadius(20).backgroundColor($r('app.color.space_soft'))
            Column({ space: 10 }) {
              Text($r('app.string.spaces_draft_name')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              TextInput({ text: this.title, placeholder: this.text($r('app.string.spaces_draft_name_placeholder')) }).fontFamily(this.appFontFamily)
                .maxLength(SPACE_TITLE_LIMIT).height(56).fontSize($r('sys.float.Body_L'))
                .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.space_search_surface'))
                .keyboardAppearance(KeyboardAppearance.IMMERSIVE).onChange((value: string): void => { this.title = SpaceDraft.trimTitle(value); })
              Text(String(SpaceDraft.titleLength(this.title)) + '/' + String(SPACE_TITLE_LIMIT)).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).width('100%').textAlign(TextAlign.End)
            }.width('100%').alignItems(HorizontalAlign.Start)
            Row({ space: 12 }) {
              Column({ space: 5 }) {
                Text($r('app.string.spaces_draft_record')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text($r('app.string.spaces_draft_record_body')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.record }).selectedColor($r('app.color.space_button'))
                .onChange((value: boolean): void => { this.record = value; })
            }.width('100%')
            Column({ space: 12 }) {
              Text($r('app.string.spaces_draft_topics')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(SPACE_TOPIC_KEYS, (key: string, index: number): void => {
                  Button(this.topicTitle(index)).fontSize($r('sys.float.Body_M')).height(36)
                    .backgroundColor(this.topics.indexOf(key) >= 0 ? $r('app.color.space_button') : $r('app.color.space_soft'))
                    .fontColor(this.topics.indexOf(key) >= 0 ? $r('app.color.space_card_text') : $r('app.color.text_primary'))
                    .margin({ right: 8, bottom: 8 }).accessibilitySelected(this.topics.indexOf(key) >= 0)
                    .onClick((): void => this.toggleTopic(key))
                }, (key: string): string => key)
              }.width('100%')
            }.width('100%').alignItems(HorizontalAlign.Start)
            Row() {
              Text($r('app.string.spaces_draft_schedule')).fontFamily(this.appFontFamily).layoutWeight(1).fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
              Toggle({ type: ToggleType.Switch, isOn: this.scheduled }).selectedColor($r('app.color.space_button'))
                .onChange((value: boolean): void => { this.scheduled = value; })
            }.width('100%')
            if (this.scheduled) {
              DatePicker({ start: new Date(), end: new Date(Date.now() + SPACE_SCHEDULE_DAYS * 86400000),
                selected: new Date(this.scheduledStart) }).width('100%').height(160)
                .onDateChange((date: Date): void => this.changeDate(date))
              TimePicker({ selected: new Date(this.scheduledStart) }).width('100%').height(140).useMilitaryTime(true)
                .onChange((value: TimePickerResult): void => this.changeTime(value))
            }
          }.width('100%').constraintSize({ maxWidth: $r('app.float.space_content_width') })
            .padding({ left: 20, right: 20, top: 20, bottom: 24 }).alignItems(HorizontalAlign.Start)
        }.width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
        Button($r('app.string.spaces_draft_save')).width('90%').height($r('app.float.space_listen_height'))
          .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold).fontColor($r('app.color.space_card_text'))
          .backgroundColor($r('app.color.space_button')).margin({ top: 12, bottom: this.navigationIndicatorHeight + 16 })
          .onClick((): void => {
            if (this.save(true)) {
              promptAction.showToast({ message: this.text($r('app.string.spaces_draft_saved')) }); this.pageStack.pop();
            }
          })
      }.width('100%').height('100%').padding({ top: this.statusBarHeight + 60 })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .onBackPressed((): boolean => { if (this.save(false)) { this.pageStack.pop(); } return true; })
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.spaces_create_draft') } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .systemMaterial(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined)
  }
}
