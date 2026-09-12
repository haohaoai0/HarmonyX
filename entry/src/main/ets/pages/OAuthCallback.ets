// Receives harmonyx://callback from the system browser and completes the
// PKCE exchange. This page deliberately contains no Web component: Google
// sign-in remains in the browser the user selected.
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { authStore } from '../services/AuthStore';
import { oauthFlowStore } from '../services/OAuthFlowStore';
import { XApiClient } from '../services/XApiClient';
import { X_CLIENT_ID } from '../services/OAuthConfig';

@Entry
@Component
struct OAuthCallback {
  @State statusText: string = '';
  @State finished: boolean = false;
  @State succeeded: boolean = false;
  private api: XApiClient = new XApiClient();
  private started: boolean = false;

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  aboutToAppear(): void {
    if (!this.started) {
      this.started = true;
      this.statusText = this.text($r('app.string.auth_finishing'));
      this.finishOAuth();
    }
  }

  private async finishOAuth(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const callbackUri: string = await oauthFlowStore.takeCallback(ctx);
    const code: string = this.queryParam(callbackUri, 'code');
    const state: string = this.queryParam(callbackUri, 'state');
    const error: string = this.queryParam(callbackUri, 'error');
    const pending = await oauthFlowStore.load(ctx);

    if (error.length > 0) {
      await oauthFlowStore.clear(ctx);
      this.showFailure(this.text($r('app.string.callback_cancelled')));
      return;
    }
    if (code.length === 0) {
      this.showFailure(this.text($r('app.string.callback_no_code')));
      return;
    }
    if (pending.verifier.length === 0) {
      this.showFailure(this.text($r('app.string.callback_session_expired')));
      return;
    }
    if (pending.state.length === 0 || state !== pending.state) {
      await oauthFlowStore.clear(ctx);
      this.showFailure(this.text($r('app.string.callback_verification_failed')));
      return;
    }

    await oauthFlowStore.clear(ctx);
    const result = await this.api.exchangeCode(X_CLIENT_ID, '', code, pending.verifier);
    if (!result.ok) {
      this.showFailure(result.errorText);
      return;
    }

    this.api.setToken(result.accessToken);
    const me = await this.api.me();
    if (me !== null) {
      await authStore.saveToken(ctx, result.accessToken, me.id, me.username);
    } else {
      await authStore.saveToken(ctx, result.accessToken, '', '');
    }
    this.statusText = this.text($r('app.string.callback_opening'));
    this.finished = true;
    this.succeeded = true;
    promptAction.showToast({ message: this.text($r('app.string.auth_signed_in')), duration: 1500 });
    await router.replaceUrl({ url: 'pages/Index' });
  }

  private showFailure(message: string): void {
    this.statusText = message;
    this.finished = true;
  }

  private queryParam(url: string, key: string): string {
    const questionMark: number = url.indexOf('?');
    if (questionMark < 0) {
      return '';
    }
    const parts: string[] = url.substring(questionMark + 1).split('&');
    for (let index = 0; index < parts.length; index++) {
      const equalSign: number = parts[index].indexOf('=');
      if (equalSign > 0 && parts[index].substring(0, equalSign) === key) {
        return decodeURIComponent(parts[index].substring(equalSign + 1));
      }
    }
    return '';
  }

  build(): void {
    Navigation() {
      Column({ space: 16 }) {
        if (!this.finished) {
          LoadingProgress().color($r('app.color.brand'))
        }
        Text(this.statusText)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
        if (this.finished && !this.succeeded) {
          Button($r('app.string.callback_back_to_login'), { stateEffect: true })
            .backgroundColor($r('app.color.brand'))
            .fontColor($r('app.color.text_on_brand'))
            .onClick(() => {
              router.replaceUrl({ url: 'pages/Login' });
            })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .title($r('app.string.callback_navigation_title'))
    .titleMode(NavigationTitleMode.Mini)
  }
}
