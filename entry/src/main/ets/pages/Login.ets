// Harmony X sign-in — OAuth is the only method. The X Client ID ships
// inside the app (see services/OAuthConfig.ets), so users just tap once
// and approve in the X web page. No keys to copy, no tokens to paste.
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { curves } from '@kit.ArkUI';
import { Pkce } from '../services/Pkce';
import { authStore } from '../services/AuthStore';
import { oauthFlowStore } from '../services/OAuthFlowStore';
import { XApiClient, REDIRECT_URI } from '../services/XApiClient';
import { X_CLIENT_ID, isOAuthConfigured } from '../services/OAuthConfig';

@Entry
@Component
struct Login {
  @State busy: boolean = false;
  @State private xMarkOpacity: number = 1;
  @State private xMarkScale: number = 1;
  @State private foregroundOpacity: number = 0;
  @State private foregroundScale: number = 0.72;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') private navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  aboutToAppear(): void {
    this.playBrandIntro();
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    authStore.load(ctx).then(() => {
      if (authStore.isSignedIn()) {
        router.replaceUrl({ url: 'pages/Index' });
      }
    });
  }

  private playBrandIntro(): void {
    this.xMarkOpacity = 1;
    this.xMarkScale = 1;
    this.foregroundOpacity = 0;
    this.foregroundScale = 0.72;
    this.getUIContext().animateTo({ duration: 680, curve: curves.springMotion(0.72, 0.86) }, (): void => {
      this.xMarkOpacity = 0;
      this.xMarkScale = 0.78;
      this.foregroundOpacity = 1;
      this.foregroundScale = 1;
    });
  }

  private topSafePadding(): number {
    return Math.max(this.statusBarHeight, 16) + 8;
  }

  private async startOAuth(): Promise<void> {
    if (!isOAuthConfigured()) {
      promptAction.showToast({ message: this.text($r('app.string.login_not_configured')), duration: 2500 });
      return;
    }
    this.busy = true;
    try {
      const verifier: string = Pkce.newVerifier();
      const challenge: string = Pkce.challengeS256(verifier);
      const state: string = Pkce.newState();
      const authUrl: string = XApiClient.buildAuthorizeUrl(X_CLIENT_ID, challenge, state);
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const saved: boolean = await oauthFlowStore.save(ctx, verifier, state);
      if (!saved) {
        promptAction.showToast({ message: this.text($r('app.string.login_prepare_failed')), duration: 2500 });
        return;
      }
      await ctx.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: authUrl
      });
      promptAction.showToast({ message: this.text($r('app.string.login_continue_browser')), duration: 2000 });
    } catch (e) {
      promptAction.showToast({ message: this.text($r('app.string.login_browser_failed')), duration: 2500 });
    } finally {
      this.busy = false;
    }
  }

  build(): void {
    Column() {
      Text($r('app.string.login_navigation_title'))
        .width('100%')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .padding({ left: 24, right: 24, top: this.topSafePadding(), bottom: 12 })

      Scroll() {
        Column({ space: 16 }) {
          Stack({ alignContent: Alignment.Center }) {
            Text('𝕏')
              .fontSize(76)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .opacity(this.xMarkOpacity)
              .scale({ x: this.xMarkScale, y: this.xMarkScale })

            Image($r('app.media.icon_foreground'))
              .width(88)
              .height(88)
              .objectFit(ImageFit.Contain)
              .opacity(this.foregroundOpacity)
              .scale({ x: this.foregroundScale, y: this.foregroundScale })
          }
          .width(104)
          .height(104)
          .renderGroup(true)
          .margin({ top: 56 })

          Text($r('app.string.login_title'))
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.login_description'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))

          Button($r('app.string.login_continue_x'), { stateEffect: true })
            .width('100%')
            .backgroundColor($r('app.color.brand'))
            .fontColor($r('app.color.text_on_brand'))
            .enabled(!this.busy && isOAuthConfigured())
            .onClick(() => this.startOAuth())

          if (!isOAuthConfigured()) {
            Column({ space: 8 }) {
              Text($r('app.string.login_developer_setup'))
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text(this.text($r('app.string.login_developer_steps_prefix')) + REDIRECT_URI +
                this.text($r('app.string.login_developer_steps_suffix')))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.bg_card'))
            .borderRadius(16)
          }

          if (this.busy) {
            LoadingProgress().color($r('app.color.brand'))
          }
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: this.navigationIndicatorHeight + 32 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
