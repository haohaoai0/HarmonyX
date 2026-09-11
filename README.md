# OpenTwit
Open source X/Twitter adaptation for HarmonyOS devices.

Native ArkTS + Stage model app targeting **HarmonyOS 6.1.1 (API 24)**,
forward-compatible with HarmonyOS 7 (API 26, developer beta as of HDC 2026).

The UI follows the HarmonyOS design language:
- Navigation (mini title) + bottom Tabs, Search, pull-to-refresh, toasts,
  card layouts with 16vp radii and standard 12/16vp spacing
- All icons are **HarmonyOS Symbols** (`SymbolGlyph` + `$r('sys.symbol.*')`):
  house, magnifyingglass, bell, envelope, person, ellipsis_bubble, repeat,
  heart, eye, share, square_and_pencil, checkmark — with filled variants
  for active/liked states. Symbol names were verified against the system
  `HMSymbolVF` font in the SDK
- iOS X app layout: avatar + centered 𝕏 top bar, 4-metric post rows,
  floating compose button opening a bottom-sheet composer with multiline
  editor (replies prefill @handle)
- System typography (HarmonyOS Sans — the default typeface, never
  overridden) with standard size/weight roles
- Full light/dark adaptation via color resources:
  `resources/base/element/color.json` (light) +
  `resources/dark/element/color.json` (dark) — no hardcoded UI colors,
  so system chrome (titles, status bar, menus) always stays legible

## Features
- **Sign in with X — the only auth method (OAuth 2.0 PKCE)** in an embedded
  WebView. The Client ID ships inside the app
  (`entry/src/main/ets/services/OAuthConfig.ets`), so users just tap once
  and approve — no keys to copy, no tokens to paste, no demo-mode buttons.
- **Works with zero setup**: the timeline shows sample posts without any
  key; sign-in unlocks the live home timeline, posting/replies, likes and
  reposts, all synced with X API v2 (token persisted via preferences).
- Explore with live search, Notifications, DMs, Me tab with sign-out.
- Phone / tablet / 2in1.

## Enabling live sign-in (one time, ~2 min)
OAuth fundamentally requires a registered client — there is no anonymous
X API. But end users never touch it; only the builder does this once:
1. Create a free app at https://developer.x.com (Projects & Apps).
2. Enable OAuth 2.0, choose Native App, and add the callback URL exactly:
   `opentwit://callback` (also shown in-app while unconfigured).
3. Paste the Client ID into `X_CLIENT_ID` in
   `entry/src/main/ets/services/OAuthConfig.ets` and rebuild.
No client secret is needed (PKCE public-client flow).

## Project layout
- `AppScope/` — app.json5 (bundle `com.opentwit.harmony`), icon, label
- `entry/src/main/ets/entryability/EntryAbility.ets` — Stage UIAbility
- `entry/src/main/ets/pages/Login.ets` — OAuth-only sign-in
- `entry/src/main/ets/pages/AuthWeb.ets` — embedded OAuth browser with
  `opentwit://callback` intercept + code exchange
- `entry/src/main/ets/pages/Index.ets` — Navigation + Tabs UI (open timeline;
  sign-in required only to interact)
- `entry/src/main/ets/components/TweetCard.ets`
- `entry/src/main/ets/models/Tweet.ets`
- `entry/src/main/ets/services/AuthStore.ets` (preferences token store),
  `OAuthConfig.ets` (embedded Client ID), `Pkce.ets` (S256),
  `XApiClient.ets`, `MockData.ets`

## Prerequisites (all reachable without a mainland-China proxy)
- HarmonyOS Command Line Tools 6.1.1 (hvigor 6.24.2, ohpm 6.1.2, SDK 6.1.1 API 24)
- JDK 17 (`brew install openjdk@17`), Node 18 (bundled in command-line-tools)
- `~/.npmrc` containing `@ohos:registry=https://repo.harmonyos.com/npm/`

## Build (unsigned debug HAP)
```bash
export PATH="$HOME/Developer/command-line-tools/bin:/opt/homebrew/opt/openjdk@17/bin:$HOME/Developer/command-line-tools/tool/node/bin:$PATH"
export DEVECO_SDK_HOME="$HOME/Developer/command-line-tools/sdk"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
ohpm install
hvigorw assembleApp
# outputs:
#   entry/build/default/outputs/default/entry-default-unsigned.hap
#   build/outputs/default/OpenTwit-default-unsigned.app
```

## Emulator (phone, HarmonyOS 6.1.1)
Image download via `Emulator -install` is geo-gated to the Chinese mainland
since DevEco 6.1.0 Beta1. No proxy software is needed — the locale/timezone
exports below are enough (this is the `export ...` trick):

```bash
export PATH="$HOME/Developer/command-line-tools/bin:$PATH"
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export TZ=Asia/Shanghai
Emulator -license accept
Emulator -imageList -deviceType Phone            # works globally, no proxy
Emulator -install -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)" -force
# ~2.2 GB ARM64 image -> ~/Library/Huawei/Sdk/system-image/HarmonyOS-6.1.1/phone_all_arm/
Emulator -create OpenTwitPhone -deviceType Phone -osVersion "HarmonyOS 6.1.1(24)"
# CLI-tools layout fix so the Emulator UI finds hdc (it looks in ~/Developer/sdk):
ln -s ~/Developer/command-line-tools/sdk ~/Developer/sdk
Emulator -start OpenTwitPhone
# new terminal (hdc appears as 127.0.0.1:5555 once boot finishes):
hdc list targets
hdc -t 127.0.0.1:5555 install entry/build/default/outputs/default/entry-default-unsigned.hap
hdc -t 127.0.0.1:5555 shell aa start -b com.opentwit.harmony -a EntryAbility
```

Why HarmonyOS 6.1 and not 7: HarmonyOS 7 (API 26) was announced at HDC 2026
(June 12) and is developer-beta only; the latest stable Release suite is
6.1.1 (API 24), and no HarmonyOS 7 emulator image is listed by the stable
6.1.1 CLI tools. The app uses only stable Stage-model APIs so it carries
over to API 26 unchanged.

## Signing
Debug builds are unsigned on purpose (`signingConfigs: []`). Provision
release signing materials out-of-band via DevEco Studio
(File > Project Structure > Signing Configs); never commit `.p12`/`.cer`/profiles.
