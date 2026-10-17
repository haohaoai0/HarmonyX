import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
// Multi-account manager: shows every signed-in X account, switches the active
// one and adds or removes accounts. Each account keeps its own credential pair
// (cookie session plus optional OAuth token), so switching never re-runs the
// sign-in flow.
import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import webview from '@ohos.web.webview';
import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { XAccount, accountStore } from '../services/AccountStore';
import { xPrivateClient } from '../services/XPrivateClient';
import { meowPushService } from '../services/MeowPushService';
import { xWebCookieBridge } from '../services/XWebCookieBridge';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';

@Builder
export function AccountsBuilder(): void {
  AccountsPage();
}

@Component
export struct AccountsPage {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @State private accounts: XAccount[] = [];
  @State private activeId: string = '';
  // Guards the row buttons while a switch or a removal is in flight.
  @State private busy: boolean = false;
  private scroller: Scroller = new Scroller();

  private pageMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.accounts = accountStore.list(context);
    this.activeId = accountStore.activeId(context);
  }

  // The cached clients are per process, so the switch also refreshes the
  // shared private-interface client before the root page reloads its feed.
  private async switchTo(account: XAccount): Promise<void> {
    if (this.busy || account.id === this.activeId) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.busy = true;
    const switched: boolean = accountStore.setActive(context, account.id);
    this.busy = false;
    if (!switched) {
      promptAction.showToast({ message: this.text($r('app.string.accounts_failed')), duration: 2000 });
      return;
    }
    xPrivateClient.load(context);
    xWebCookieBridge.syncAccount(account);
    this.reload();
    promptAction.showToast({
      message: this.text($r('app.string.accounts_switched')) + account.title(),
      duration: 1800
    });
  }

  private async confirmRemove(account: XAccount): Promise<void> {
    if (this.busy) {
      return;
    }
    const dialog: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: this.text($r('app.string.accounts_remove_title')),
      message: this.text($r('app.string.accounts_remove_confirm')),
      buttons: [
        { text: this.text($r('app.string.compose_cancel')), color: '#666666' },
        { text: this.text($r('app.string.accounts_remove')), color: '#E0245E' }
      ]
    });
    if (dialog.index !== 1) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.busy = true;
    try {
      await meowPushService.beforeSignOut(context, account.id);
    } catch (error) {
      this.busy = false;
      promptAction.showToast({ message: this.text($r('app.string.meow_sign_out_error')), duration: 3000 });
      return;
    }
    const removed: boolean = accountStore.remove(context, account.id);
    this.busy = false;
    if (!removed) {
      promptAction.showToast({ message: this.text($r('app.string.accounts_failed')), duration: 2000 });
      return;
    }
    xPrivateClient.load(context);
    xWebCookieBridge.syncActive(context);
    this.reload();
    promptAction.showToast({ message: this.text($r('app.string.accounts_removed')), duration: 1800 });
  }

  // The account manager skips the retired full-page login surface and opens
  // the in-app X sign-in page directly. Clearing only ArkWeb's cookie jar
  // forces x.com to ask for another account while local sessions stay stored.
  private async openAddAccount(): Promise<void> {
    // Only X has to be signed out here; Grok's web session lives in the same
    // jar and is carried across.
    await xWebCookieBridge.beginFreshXSession();
    try {
      await router.pushUrl({
        url: 'pages/AuthWeb',
        params: { 'mode': 'session', 'addAccount': '1' }
      });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.login_browser_failed')), duration: 2500 });
    }
  }

  @Builder
  private AddAccountCard(): void {
    Row({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.plus_circle_fill'))
        .fontSize(28)
        .fontColor([this.accentColor])
        .width(40)
      Column({ space: 4 }) {
        Text($r('app.string.accounts_add')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.accounts_add_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(3)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .onClick((): void => { this.openAddAccount(); })
  }

  @Builder
  private AccountRow(account: XAccount): void {
    Row({ space: 14 }) {
      if (account.avatarUrl.length > 0) {
        Image(account.avatarUrl)
          .width(44)
          .height(44)
          .objectFit(ImageFit.Cover)
          .borderRadius(userAvatarRadius(44, 22, account.verifiedType ?? '', account.avatarShape ?? ''))
          .clip(true)
      } else {
        Text(account.initial()).fontFamily(this.appFontFamily)
          .width(44)
          .height(44)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_accent'))
          .backgroundColor(this.accentColor)
          .borderRadius(userAvatarRadius(44, 22, account.verifiedType ?? '', account.avatarShape ?? ''))
          .textAlign(TextAlign.Center)
      }

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(account.title()).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (account.id === this.activeId) {
            Text($r('app.string.accounts_current_badge')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor(this.accentColor)
              .borderRadius(8)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }
        }
        Text(account.handle().length > 0 ? account.handle() :
          this.text($r('app.string.accounts_private_only'))).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (account.id !== this.activeId) {
        Text($r('app.string.accounts_switch_action')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor)
      }

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(18)
          .fontColor([$r('app.color.danger')])
      }
      .width(36)
      .height(36)
      .backgroundColor(secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .onClick((): void => {
        this.confirmRemove(account);
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .onClick((): void => {
      this.switchTo(account);
    })
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 0 }) {
          Text($r('app.string.accounts_intro')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 8 })

          if (this.accounts.length === 0) {
            Column({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.person_2_badge_arrow_2_circlepath'))
                .fontSize(30)
                .fontColor([$r('app.color.text_secondary')])
              Text($r('app.string.accounts_empty')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Subtitle_L'))
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            .padding({ top: 28, bottom: 28 })
          } else {
            ForEach(this.accounts, (account: XAccount): void => {
              this.AccountRow(account)
            }, (account: XAccount) => account.id)
          }

          Divider().color($r('app.color.divider')).margin({ top: 4, bottom: 4 })

          this.AddAccountCard()

          Text($r('app.string.accounts_note')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 20, right: 20, top: 12 })
        }
        .width('100%')
        .padding({ top: this.statusBarHeight + 74, bottom: this.navigationIndicatorHeight + 28 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.accounts_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
    .systemMaterial(this.pageMaterial());
  }
}
