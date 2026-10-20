import { InputModalScope } from '../utils/InputModalScope';
import { contextInputMouse } from '../utils/InputSupport';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { DmMessage, DmReaction, DmAttachment } from '../models/Tweet';
import { CHAT_QUICK_REACTIONS, chatEmojiStore, ChatEmoji } from '../services/ChatEmojiStore';
import { ChatEmojiText } from './ChatEmojiText';
import { xPrivateClient } from '../services/XPrivateClient';
import { chatInputMaterial, chatPageMaterial } from '../utils/ChatMaterial';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL, STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL } from '../services/AppearanceStore';
import hilog from '@ohos.hilog';
import { materialModifier } from '../utils/SystemMaterial';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-ChatPost';

@Builder
function EmptyMessageContent(_onLongPress: () => void): void { Column() {} }

@Component
export struct ChatMessageActions {
  private inputModalScope: InputModalScope = new InputModalScope();

  aboutToDisappear(): void {
    this.clearMenuAppearTimer();
    this.inputModalScope.setActive(false);
  }
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop message: DmMessage = { id: '', conversationId: '', senderId: '', senderName: '', senderUsername: '',
    senderAvatarUrl: '', text: '', time: '', timestampMs: 0, outgoing: false, encrypted: false };
  @Prop pinned: boolean = false;
  @BuilderParam content: (onLongPress: () => void) => void = EmptyMessageContent;
  onReply: () => void = (): void => {};
  onForward: () => void = (): void => {};
  onCopy: () => void = (): void => {};
  onSave: () => void = (): void => {};
  onPin: () => void = (): void => {};
  onInfo: () => void = (): void => {};
  onReport: () => void = (): void => {};
  onDelete: () => void = (): void => {};
  onReaction: (emoji: string) => void = (): void => {};
  onMoreReactions: () => void = (): void => {};
  @StorageProp(STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL) materialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  @State private menuShown: boolean = false;
  @State private quick: string[] = CHAT_QUICK_REACTIONS.slice();
  private afterDismiss: (() => void) | null = null;
  private menuAppeared: boolean = false;
  private menuAppearTimer: number = -1;
  private requestActions: () => void = (): void => { this.showActions(); };

  private clearMenuAppearTimer(): void {
    if (this.menuAppearTimer >= 0) { clearTimeout(this.menuAppearTimer); this.menuAppearTimer = -1; }
  }

  private showActions(): void {
    if (this.menuShown) { return; }
    hilog.info(DOMAIN, TAG, 'message menu requested for %{public}s', this.message.id);
    this.quick = chatEmojiStore.recent(getContext(this) as common.UIAbilityContext).slice(0, 13)
      .map((entry: ChatEmoji): string => entry.emoji);
    this.menuAppeared = false;
    this.menuShown = true;
    this.clearMenuAppearTimer();
    // A rejected menu subwindow never calls onDisappear. Release menuShown so
    // the next long press can retry instead of being ignored for this row.
    this.menuAppearTimer = setTimeout((): void => {
      this.menuAppearTimer = -1;
      if (this.menuShown && !this.menuAppeared) {
        hilog.warn(DOMAIN, TAG, 'message menu did not appear for %{public}s', this.message.id);
        this.menuShown = false;
      }
    }, 1500);
  }

  private dismissThen(action: () => void): void {
    this.afterDismiss = action;
    this.menuShown = false;
  }

  private chosen(emoji: string): boolean {
    return (this.message.reactions ?? []).some((r: DmReaction): boolean => r.active && r.emoji === emoji && r.senderId === xPrivateClient.viewerId());
  }
  @Builder
  private EmojiButton(emoji: string): void {
    Button({ type: ButtonType.Circle }) {
      ChatEmojiText({ text: emoji, fontSize: $r('app.float.chat_emoji_quick_size') })
    }
      .width('14.2857%').height(44).padding(0).backgroundColor(this.chosen(emoji) ? $r('app.color.chat_reaction_selected') : Color.Transparent)
      .accessibilityText(emoji).onClick((): void => { this.menuShown = false; this.onReaction(emoji); })
  }
  @Builder
  private QuickPanel(): void {
    Column() {
      Row() { ForEach(this.quick.slice(0, 7), (emoji: string) => { this.EmojiButton(emoji); }, (emoji: string): string => emoji) }.width('100%')
      Row() {
        ForEach(this.quick.slice(7), (emoji: string) => { this.EmojiButton(emoji); }, (emoji: string): string => emoji)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.more')).fontSize(22).fontColor([$r('app.color.text_primary')])
        }.width('14.2857%').height(44).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.chat_emoji_more')).onClick((): void => { this.menuShown = false; this.onMoreReactions(); })
      }.width('100%')
    }.padding(6).width('100%').height(100).borderRadius(18).clip(true)
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_field'))
      .attributeModifier(materialModifier(chatInputMaterial(this.materialLevel)))
  }
  @Builder
  private QuickReactions(): void {
    Navigation() { Column().height(0).hitTestBehavior(HitTestMode.None) }
      .title({ builder: (): void => { this.QuickPanel(); }, height: 100 }, { barStyle: BarStyle.STACK })
      .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack).hideToolBar(true)
      .height(100).width('100%').backgroundColor(Color.Transparent)
  }
  @Builder
  private ActionRow(label: Resource, icon: Resource, actionId: string,
    action: () => void, destructive: boolean = false): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        Text(label).fontFamily(this.appFontFamily).fontSize(16).fontColor(destructive ? $r('app.color.danger') : $r('app.color.text_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        SymbolGlyph(icon).fontSize(22)
          .fontColor([destructive ? $r('app.color.danger') : $r('app.color.text_secondary')])
      }.width('100%').height('100%')
    }.id(actionId).width('100%').height(46).padding({ left: 16, right: 16 })
      .borderRadius(0).backgroundColor(Color.Transparent).accessibilityText(label)
      .onClick((): void => { this.dismissThen(action); })
  }
  @Builder
  private ActionDivider(): void {
    Divider().strokeWidth(0.5).color($r('app.color.divider')).margin({ left: 16, right: 16 })
  }
  @Builder
  private Actions(): void {
    // The context-menu builder accepts a custom layout. Keep the TitleBar host
    // and operation rows in one measured Column rather than nesting Navigation
    // inside MenuItem, whose native menu measurement can collapse sibling rows.
    Column({ space: 8 }) {
      this.QuickReactions();
      Scroll() {
        Column() {
          this.ActionRow($r('app.string.chat_message_reply'), $r('sys.symbol.arrowshape_turn_up_left'),
            'chat-message-action-reply', this.onReply);
          this.ActionDivider();
          this.ActionRow($r('app.string.chat_message_forward'), $r('sys.symbol.arrowshape_turn_up_right'),
            'chat-message-action-forward', this.onForward);
          if (this.message.text.length > 0) {
            this.ActionDivider();
            this.ActionRow($r('app.string.chat_message_copy'), $r('sys.symbol.plus_square_on_square'),
              'chat-message-action-copy', this.onCopy);
          }
          if ((this.message.attachments ?? []).some((attachment: DmAttachment): boolean =>
            attachment.type === 'Media' && (attachment.mediaType === 1 || attachment.mediaType === 2))) {
            this.ActionDivider();
            this.ActionRow($r('app.string.chat_message_save'), $r('sys.symbol.download'),
              'chat-message-action-save', this.onSave);
          }
          this.ActionDivider();
          this.ActionRow(this.pinned ? $r('app.string.chat_message_unpin') : $r('app.string.chat_message_pin'),
            $r('sys.symbol.pin'), 'chat-message-action-pin', this.onPin);
          this.ActionDivider();
          this.ActionRow($r('app.string.chat_message_info'), $r('sys.symbol.info_circle'),
            'chat-message-action-info', this.onInfo);
          if (!this.message.outgoing) {
            this.ActionDivider();
            this.ActionRow($r('app.string.chat_message_report'), $r('sys.symbol.flag'),
              'chat-message-action-report', this.onReport, true);
          }
          this.ActionDivider();
          this.ActionRow($r('app.string.chat_message_delete_mine'), $r('sys.symbol.trash'),
            'chat-message-action-delete', this.onDelete, true);
        }.width('100%')
      }.id('chat-message-action-list').width('100%').constraintSize({ maxHeight: 336 })
        .scrollBar(BarState.Auto).borderRadius(18).clip(true)
        .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_field'))
        .attributeModifier(materialModifier(chatPageMaterial()))
    }.id('chat-message-context-menu').width(320)
  }
  build(): void {
    Column() { this.content(this.requestActions); }
      .parallelGesture(LongPressGesture({ repeat: false, duration: 500 }).onAction((): void => {
        this.showActions();
      }))
      .onMouse((event: MouseEvent): void => contextInputMouse(event, (): void => this.showActions()))
      .bindContextMenu(this.menuShown, this.Actions(), {
        preview: (this.message.attachments ?? []).some((a: DmAttachment): boolean => a.mediaType === 3) ? MenuPreviewMode.NONE : MenuPreviewMode.IMAGE,
        previewBorderRadius: 22, previewAnimationOptions: { scale: [0.98, 1.035] }, borderRadius: 18,
        backgroundColor: Color.Transparent, backgroundBlurStyle: BlurStyle.COMPONENT_THICK,
        mask: { color: $r('app.color.chat_message_menu_mask'), backgroundBlurStyle: BlurStyle.BACKGROUND_THIN },
        modalMode: ModalMode.TARGET_WINDOW, hapticFeedbackMode: HapticFeedbackMode.AUTO,
        onAppear: (): void => {
          this.menuAppeared = true;
          this.clearMenuAppearTimer();
          this.inputModalScope.setActive(true);
        },
        onDisappear: (): void => {
          this.menuAppeared = false;
          this.clearMenuAppearTimer();
          this.inputModalScope.setActive(false);
          this.menuShown = false;
          const action: (() => void) | null = this.afterDismiss;
          this.afterDismiss = null;
          if (action !== null) { action(); }
        }
      })
  }
}
