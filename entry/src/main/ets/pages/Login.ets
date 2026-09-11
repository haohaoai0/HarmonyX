// OpenTwit sign-in — OAuth is the only method. The X Client ID ships
// inside the app (see services/OAuthConfig.ets), so users just tap once
// and approve in the X web page. No keys to copy, no tokens to paste.
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { Pkce } from '../services/Pkce';
import { authStore } from '../services/AuthStore';
import { XApiClient, REDIRECT_URI } from '../services/XApiClient';
import { X_CLIENT_ID, isOAuthConfigured } from '../services/OAuthConfig';

@Entry
@Component
struct Login {
  @State busy: boolean = false;

  aboutToAppear(): void {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    authStore.load(ctx).then(() => {
      if (authStore.isSignedIn()) {
        router.replaceUrl({ url: 'pages/Index' });
      }
    });
  }

  private async startOAuth(): Promise<void> {
    if (!isOAuthConfigured()) {
      promptAction.showToast({ message: 'Sign-in is not configured in this build yet', duration: 2500 });
      return;
    }
    this.busy = true;
    try {
      const verifier: string = Pkce.newVerifier();
      const challenge: string = Pkce.challengeS256(verifier);
      const state: string = Pkce.newState();
      const authUrl: string = XApiClient.buildAuthorizeUrl(X_CLIENT_ID, challenge, state);
      await router.pushUrl({
        url: 'pages/AuthWeb',
        params: {
          'authUrl': authUrl,
          'verifier': verifier,
          'state': state
        }
      });
    } finally {
      this.busy = false;
    }
  }

  build(): void {
    Navigation() {
      Scroll() {
        Column({ space: 16 }) {
          Text('𝕏')
            .fontSize(56)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 24 })

          Text('Sign in to OpenTwit')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text('One tap — approve OpenTwit in the X web page and you are in. ' +
            'Your live home timeline, posts, likes and reposts sync with X.')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))

          Button('Continue with X', { stateEffect: true })
            .width('100%')
            .backgroundColor($r('app.color.brand'))
            .fontColor($r('app.color.text_on_brand'))
            .enabled(!this.busy && isOAuthConfigured())
            .onClick(() => this.startOAuth())

          if (!isOAuthConfigured()) {
            Column({ space: 8 }) {
              Text('Developer setup (one time, ~2 min)')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text('1. Create a free app at developer.x.com.\n' +
                '2. Enable OAuth 2.0 (Native App) with callback URL:\n' + REDIRECT_URI + '\n' +
                '3. Paste the Client ID into services/OAuthConfig.ets and rebuild.')
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
        .padding({ left: 24, right: 24, bottom: 32 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .title('Welcome')
    .titleMode(NavigationTitleMode.Mini)
    .hideBackButton(true)
  }
}
