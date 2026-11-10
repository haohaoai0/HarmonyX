import { DesktopLayout } from '../utils/DesktopLayout';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
// Grok chat opened from a post detail's native title-bar menu. The original
// post is sent as explicit xAI context for every reply, not simulated locally.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import webview from '@ohos.web.webview';
import { TweetCard } from '../components/TweetCard';
import type { Tweet } from '../models/Tweet';
import { GrokChatMessage, GrokResult, grokService } from '../services/GrokService';
import { GROK_MODE_API, GROK_MODE_WEB, GrokSettings, grokSettingsStore } from '../services/GrokSettingsStore';
import { DISPLAY_MODE_DARK, DISPLAY_MODE_LIGHT } from '../services/AppearanceStore';
import { xWebCookieBridge } from '../services/XWebCookieBridge';
import { WebProxyCredential, proxyStore } from '../services/ProxyStore';
import { GROK_WEB_SESSION_ORIGINS, webSessionStore } from '../services/WebSessionStore';
import { WEB_AUDIO_CAPTURE, webPermission } from '../utils/WebPermission';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { cardSurfaceColor, fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';

export interface GrokRouteParam {
  tweet?: Tweet;
  mode?: string;
}

const GROK_WEB_URL: string = 'https://grok.com/';
const GROK_SESSION_CHECKPOINT_MS: number = 5000;

@Builder
export function GrokBuilder(): void {
  GrokPage();
}

@Component
export struct GrokPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.desktop_layout') desktopLayoutEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') windowBreakpoint: string = 'sm';
  @State private tweet: Tweet | null = null;
  @State private prompt: string = '';
  @State private messages: GrokChatMessage[] = [];
  @State private submitting: boolean = false;
  @State private mode: string = GROK_MODE_WEB;
  @State private webReady: boolean = false;
  private scroller: Scroller = new Scroller();
  private webController: webview.WebviewController = new webview.WebviewController();
  private webSessionTimer: number = -1;
  private webSessionSaving: boolean = false;
  private alive: boolean = true;

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private async applyRouteParam(param?: GrokRouteParam): Promise<void> {
    this.tweet = param?.tweet ?? null;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: GrokSettings = grokSettingsStore.load(context);
    this.mode = (param?.mode ?? settings.mode) === GROK_MODE_API ? GROK_MODE_API : GROK_MODE_WEB;
    if (this.mode === GROK_MODE_WEB && settings.useXWebSession) {
      // Writes only into the x.com ArkWeb cookie jar. Grok receives no raw
      // X credential and still owns its normal OAuth/SSO authorization step.
      xWebCookieBridge.syncActive(context);
    }
    if (this.mode === GROK_MODE_WEB) {
      // The stored Grok session has to be back in the jar before the first
      // navigation, so the Web component is created afterwards.
      try {
        await webSessionStore.restore(context, GROK_WEB_SESSION_ORIGINS);
      } catch (error) {
        // A failed cookie restore must not prevent the page from opening.
      }
      if (this.alive) {
        this.webReady = true;
        this.startWebSessionCheckpoint();
      }
    }
    this.messages = [];
    this.prompt = '';
  }

  private webDarkMode(): WebDarkMode {
    if (this.themeDisplayMode === DISPLAY_MODE_DARK) {
      return WebDarkMode.On;
    }
    if (this.themeDisplayMode === DISPLAY_MODE_LIGHT) {
      return WebDarkMode.Off;
    }
    return WebDarkMode.Auto;
  }

  private webForceDark(): boolean {
    return this.themeDisplayMode !== DISPLAY_MODE_LIGHT;
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.stopWebSessionCheckpoint();
    this.persistWebSession();
  }

  private startWebSessionCheckpoint(): void {
    if (this.webSessionTimer >= 0) {
      return;
    }
    this.persistWebSession();
    this.webSessionTimer = setInterval((): void => {
      this.persistWebSession();
    }, GROK_SESSION_CHECKPOINT_MS);
  }

  private stopWebSessionCheckpoint(): void {
    if (this.webSessionTimer < 0) {
      return;
    }
    clearInterval(this.webSessionTimer);
    this.webSessionTimer = -1;
  }

  private persistWebSession(): void {
    if (this.mode !== GROK_MODE_WEB || this.webSessionSaving) {
      return;
    }
    this.webSessionSaving = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    webSessionStore.persist(context, GROK_WEB_SESSION_ORIGINS).then((): void => {
      this.webSessionSaving = false;
    }).catch((): void => {
      this.webSessionSaving = false;
    });
  }

  private postUrl(tweet: Tweet): string {
    if (tweet.author.username.length > 0) {
      return 'https://x.com/' + tweet.author.username + '/status/' + tweet.id;
    }
    return 'https://x.com/i/status/' + tweet.id;
  }

  // q is a Grok web prompt parameter, not an API contract. If a future Grok
  // web release ignores it, the genuine page still opens and never displays a
  // locally fabricated response.
  private webUrl(): string {
    const current: Tweet | null = this.tweet;
    if (current === null) {
      return GROK_WEB_URL;
    }
    const handle: string = current.author.username.length > 0 ? '@' + current.author.username : current.author.name;
    const prompt: string = this.text($r('app.string.grok_web_prompt_prefix')) + '\nURL: ' + this.postUrl(current) +
      '\nAuthor: ' + current.author.name + ' (' + handle + ')\nPost:\n' + current.text;
    return GROK_WEB_URL + '?q=' + encodeURIComponent(prompt);
  }

  private useSuggestion(label: Resource): void {
    this.prompt = this.text(label);
    this.submitPrompt();
  }

  private appendMessage(role: string, text: string): void {
    const next: GrokChatMessage[] = [];
    for (let i: number = 0; i < this.messages.length; i++) {
      next.push(this.messages[i]);
    }
    next.push({ role: role, text: text });
    this.messages = next;
  }

  private resultError(result: GrokResult): string {
    if (result.errorText === 'not_configured') {
      return this.text($r('app.string.grok_not_configured'));
    }
    if (result.errorText === 'empty_prompt') {
      return this.text($r('app.string.grok_empty_prompt'));
    }
    const suffix: string = result.status > 0 ? ' · HTTP ' + result.status : '';
    return this.text($r('app.string.grok_failed')) + suffix;
  }

  private async submitPrompt(): Promise<void> {
    const current: Tweet | null = this.tweet;
    const question: string = this.prompt.trim();
    if (this.submitting) {
      return;
    }
    if (question.length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.grok_empty_prompt')), duration: 1800 });
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: GrokSettings = grokSettingsStore.load(context);
    const history: GrokChatMessage[] = [];
    for (let i: number = 0; i < this.messages.length; i++) {
      history.push(this.messages[i]);
    }
    this.appendMessage('user', question);
    this.prompt = '';
    this.submitting = true;
    const result: GrokResult = await grokService.reply(current, question, history, settings);
    this.submitting = false;
    if (!this.alive || this.tweet?.id !== current?.id) {
      return;
    }
    if (result.ok) {
      this.appendMessage('assistant', result.text);
      return;
    }
    promptAction.showToast({ message: this.resultError(result), duration: 3200 });
  }

  @Builder
  private Suggestion(label: Resource): void {
    Text(label).fontFamily(this.appFontFamily)
      .fontSize($r('sys.float.Body_M'))
      .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .borderRadius(18)
      .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .enabled(!this.submitting)
      .opacity(this.submitting ? 0.45 : 1)
      .onClick((): void => {
        this.useSuggestion(label);
      })
  }

  @Builder
  private MessageBubble(message: GrokChatMessage): void {
    Column() {
      Text(message.text).fontFamily(this.appFontFamily)
        .width('100%')
        .fontSize($r('sys.float.Body_L'))
        .fontColor(message.role === 'user' ? $r('app.color.text_on_accent') : pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, message.role === 'user' ? this.accentColor :
      pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue)))
        .lineHeight(22)
    }
    .width('88%')
    .padding(14)
    .borderRadius(18)
    .backgroundColor(message.role === 'user' ? this.accentColor :
      pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue))
    .alignSelf(message.role === 'user' ? ItemAlign.End : ItemAlign.Start)
  }

  @Builder
  private Conversation(): void {
    if (this.messages.length > 0) {
      ForEach(this.messages, (message: GrokChatMessage, index: number): void => {
        this.MessageBubble(message)
      }, (message: GrokChatMessage, index: number): string => message.role + '-' + index)
    }
    if (this.submitting) {
      Row({ space: 10 }) {
        LoadingProgress().color(this.accentColor).width(18).height(18)
        Text($r('app.string.grok_processing')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      }
      .padding({ left: 10, top: 2, bottom: 2 })
    }
  }

  @Builder
  private ContentBuilder(): void {
    Scroll(this.scroller) {
      Column({ space: 18 }) {
        if (this.tweet !== null) {
          TweetCard({ tweet: this.tweet, showActions: false })
        }

        Column({ space: 10 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.wand_and_stars'))
              .fontSize(22)
              .fontColor([this.accentColor])
            Text(this.tweet === null ? $r('app.string.grok_title') : $r('app.string.grok_context_title')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Subtitle_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue)))
          }
          .width('100%')
          Text(this.tweet === null ? $r('app.string.grok_chat_hint') : $r('app.string.grok_context_hint')).fontFamily(this.appFontFamily)
            .width('100%')
            .fontSize($r('sys.float.Body_L'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue)))
            .lineHeight(22)
          if (this.tweet !== null) {
            Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
              this.Suggestion($r('app.string.grok_suggestion_summary'))
              this.Suggestion($r('app.string.grok_suggestion_context'))
              this.Suggestion($r('app.string.grok_suggestion_questions'))
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(16)
        .borderRadius(20)
        .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue))

        this.Conversation()
      }
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint) ?
          8 : this.statusBarHeight + 64,
        bottom: this.navigationIndicatorHeight + 104
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .clip(!(DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint)))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  private PromptComposer(): void {
    Row({ space: 10 }) {
      TextInput({ placeholder: $r('app.string.grok_prompt_placeholder'), text: this.prompt }).fontFamily(this.appFontFamily)
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .layoutWeight(1)
        .height(52)
        .fontSize($r('sys.float.Body_L'))
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .maxLength(8000)
        .onChange((value: string): void => {
          this.prompt = value;
        })
        .onSubmit((): void => {
          this.submitPrompt();
        })
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        if (this.submitting) {
          LoadingProgress()
            .color($r('app.color.text_on_accent'))
            .width(18)
            .height(18)
        } else {
          Text($r('app.string.dm_send')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_on_accent'))
        }
      }
      .height(44)
      .backgroundColor(this.accentColor)
      .enabled(this.prompt.trim().length > 0 && !this.submitting)
      .opacity(this.prompt.trim().length > 0 && !this.submitting ? 1 : 0.45)
      .onClick((): void => {
        this.submitPrompt();
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: this.navigationIndicatorHeight + 8 })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .border({ width: { top: 1 }, color: $r('app.color.divider') })
  }

  // grok.com owns its authentication, model choice and account quota.  It is
  // intentionally embedded untouched instead of trying to imitate its chat
  // protocol or inject a fabricated reply into a web page.
  @Builder
  private GrokWebContent(): void {
    Column({ space: 0 }) {
      if (this.webReady) {
        Web({ src: this.webUrl(), controller: this.webController, incognitoMode: false })
          .width('100%')
          .layoutWeight(1)
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .databaseAccess(true)
          .darkMode(this.webDarkMode())
          .forceDarkAccess(this.webForceDark())
          // The cookie jar flushes on a 30 second timer, so a sign-in that
          // happens right before the reader leaves would be lost: force the
          // write once the page settles, and keep the copy the app owns.
          .onPageEnd((): void => {
            this.persistWebSession();
          })
          .onHttpAuthRequest((event): boolean => {
            if (event === undefined || event === null) {
              return false;
            }
            const credential: WebProxyCredential = proxyStore.webCredential();
            if (!credential.usable) {
              event.handler.cancel();
              return false;
            }
            return event.handler.confirm(credential.username, credential.password);
          })
          // ArkWeb hands a getUserMedia request to the app instead of asking
          // the reader; an unanswered request is a denial, so Grok's voice
          // input only works once this answers.
          .onPermissionRequest((event): void => {
            if (event === undefined || event === null) {
              return;
            }
            const resources: string[] = event.request.getAccessibleResource();
            let wantsAudio: boolean = false;
            for (let i: number = 0; i < resources.length; i++) {
              if (resources[i] === WEB_AUDIO_CAPTURE) {
                wantsAudio = true;
              }
            }
            if (!wantsAudio) {
              event.request.deny();
              return;
            }
            const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
            webPermission.canUseMicrophone(context, event.request.getOrigin())
              .then((granted: boolean): void => {
                if (granted) {
                  event.request.grant([WEB_AUDIO_CAPTURE]);
                } else {
                  event.request.deny();
                }
              })
              .catch((): void => {
                event.request.deny();
              });
          })
          .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      } else {
        Column({ space: 12 }) {
          LoadingProgress().color(this.accentColor).width(18).height(18)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    // Leave the native destination title bar unobstructed while rendering
    // grok.com directly below it, with no app-authored web-mode banner.
    .padding({
      top: DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint) ?
        0 : this.statusBarHeight + 56
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      if (this.mode === GROK_MODE_WEB) {
        this.GrokWebContent()
      } else {
        Stack({ alignContent: Alignment.Bottom }) {
          this.ContentBuilder()
          this.PromptComposer()
        }
        .width('100%')
        .height('100%')
      }
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context);
      const param: GrokRouteParam = context.pathInfo?.param as GrokRouteParam;
      this.applyRouteParam(param);
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint),
      content: { title: { mainTitle: $r('app.string.grok_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue));
  }
}
