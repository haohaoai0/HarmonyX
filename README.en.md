<p align="center">
  <img src="AppScope/resources/base/media/app_icon.png" width="132" alt="Harmony X app icon">
</p>

<h1 align="center">Harmony X</h1>

<p align="center">
  A native X client for HarmonyOS.<br>
  Built with ArkTS and the Stage model for an immersive, clean, device-native dark experience.
</p>

<p align="center"><a href="README.md">简体中文</a></p>

<p align="center">
  <img src="https://img.shields.io/badge/HarmonyOS-API%2026-1677FF?style=flat-square" alt="HarmonyOS API 26">
  <img src="https://img.shields.io/badge/ArkTS-Stage%20model-0B0B0D?style=flat-square" alt="ArkTS Stage model">
  <img src="https://img.shields.io/badge/License-Apache--2.0-2EA44F?style=flat-square" alt="Apache-2.0 license">
</p>

<p align="center">
  <a href="#highlights">Highlights</a> ·
  <a href="#screens">Screens</a> ·
  <a href="#changes-from-opentwit">Changes from OpenTwit</a> ·
  <a href="#project-configuration">Project configuration</a> ·
  <a href="#build">Build</a> ·
  <a href="#upstream--license">Upstream &amp; license</a>
</p>

---

## Highlights

| | |
|:--|:--|
| **Complete social shell** | Home timeline, Explore, Alerts, messages, profile, and a floating compose action. Sample content is available before sign-in. |
| **Native HarmonyOS design** | ArkUI, HarmonyOS system symbols, light/dark adaptation, and support for phones, tablets, and 2-in-1 devices. |
| **Live X capabilities when configured** | OAuth 2.0 PKCE runs in the system browser; after sign-in, the app can use live timelines, search, posting, likes, and reposts. |
| **Honest offline fallback** | When X is unavailable or API access is restricted, the interface stays usable and clearly explains the current state. |

## Screens

<p align="center">
  <img src="docs/screenshots/home-dark.jpg" width="22.5%" alt="Home timeline">
  <img src="docs/screenshots/explore-dark.jpg" width="22.5%" alt="Explore search">
  <img src="docs/screenshots/alerts-dark.jpg" width="22.5%" alt="Alerts">
  <img src="docs/screenshots/messages-dark.jpg" width="22.5%" alt="Messages">
</p>

<p align="center"><sub>Home · Explore · Alerts · Messages</sub></p>

<p align="center">
  <img src="docs/screenshots/sign-in-dark.jpg" width="23%" alt="Harmony X sign-in screen">
  <img src="docs/screenshots/oauth-authorization-dark.jpg" width="23%" alt="X.com authorization screen in the system browser">
</p>

<p align="center"><sub>Harmony X sign-in · X.com authorization in the system browser</sub></p>

## Design notes

- **Actual app icon** — the header uses `AppScope/resources/base/media/app_icon.png`. The installed app uses paired layered resources: an opaque black background and a transparent blue-and-white foreground mark, both at 1024 × 1024.
- **System-first design** — HarmonyOS Sans and system `SymbolGlyph` icons are used throughout. Colors are defined in resources rather than hard-coded in pages.
- **Adaptive layout** — the Stage model organizes interface and state for phones, tablets, and 2-in-1 devices.

## Changes from OpenTwit

Harmony X is more than a reskin. It is an API 26-oriented HarmonyOS adaptation of OpenTwit with the following project-level changes:

- **Immersive HDS tab bar** — replaces the conventional bottom navigation with `HdsTabs`, adaptive immersive material, and bound scrollers for the five primary pages.
- **Immersive HDS title bar** — uses `HdsNavigation` with an immersive gradient-blur title treatment; the avatar and brand mark are part of the navigation content.
- **Intelligent compose action** — the full-page draggable HDS compose button listens for holding-hand changes where supported, remembers the most recent usable side otherwise, and avoids both safe areas and the tab bar.
- **Point-light interaction** — pressing or dragging activates HDS point lighting to illuminate component borders and content. The compose action scales while dragging for clear tactile feedback.
- **Fullscreen and safe-area handling** — `EntryAbility` enables layout fullscreen and observes system and navigation-indicator avoid areas, keeping immersive content usable around cutouts, rounded corners, and gesture regions.
- **Chinese localization** — product names, interface copy, and status messages are localized in `zh_CN`, with matching English resources and a Chinese base resource set.
- **Harmony X identity and sign-in** — new package identity, layered app icon, system-browser OAuth callback flow, dark visual system, and project documentation.

## Project configuration

| Setting | Current value |
|:--|:--|
| Application | `Harmony X` · `com.haohaoai0.harmonyx` · version `1.0.0` (`versionCode` 1) |
| Module | `entry` · Stage model · `modelVersion` 5.0.0 |
| SDK profile | No explicit compile SDK (uses the installed DevEco SDK) · compatible SDK `6.1.0 (API 23)` · target SDK `26.0.0` |
| Devices | `phone`, `tablet`, `2in1` · fullscreen `EntryAbility` |
| Permissions | `ohos.permission.INTERNET`, `ohos.permission.DETECT_GESTURE` |
| Build tools | Hvigor `6.26.4` · `@ohos/hvigor-ohos-plugin` `6.26.4` · `@ohos/hypium` `1.0.19` (development dependency) |

## Build

Install HarmonyOS Command Line Tools (or DevEco Studio) and JDK 17, then add this npm configuration:

```ini
@ohos:registry=https://repo.harmonyos.com/npm/
```

```bash
devecocli build
```

Output:

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

`build-profile.json5` is a local DevEco signing configuration and is not committed to this repository. Create it and configure certificates, profiles, and passwords only in your local DevEco Studio environment; never commit it.

## Enable X sign-in

1. Create an application at [developer.x.com](https://developer.x.com/).
2. Enable **OAuth 2.0**, choose **Native App**, and set the callback URI to `harmonyx://callback`.
3. Add the Client ID in `entry/src/main/ets/services/OAuthConfig.ets`, then rebuild.

Harmony X uses PKCE and does not require a Client Secret. Tapping **Continue with X** launches the system browser through `ohos.want.action.viewData`; the X.com permission page shown above is rendered and managed by X, not imitated by the app. Some X endpoints require paid API access; the app reports that state and continues to show sample content.

## Upstream & license

Harmony X is a derivative work of [Abhi-Flex1/OpenTwit](https://github.com/Abhi-Flex1/OpenTwit). This repository retains the Apache-2.0 license and applicable upstream attribution. Harmony X-specific additions include the application identity, visual system, localized interface, OAuth flow, responsive UI refinements, and documentation.

Licensed under [Apache-2.0](LICENSE).
