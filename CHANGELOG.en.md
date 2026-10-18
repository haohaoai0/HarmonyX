# Changelog

User-facing changes in Harmony X. Unreleased entries describe the next version; `AppScope/app.json5` remains the source of truth for the current app version.

中文版见 [CHANGELOG.md](CHANGELOG.md)。

## 3.1.0 — Unreleased (2026-10-18)

This update adds Home-screen cards, native profile editing, traditional colour themes, and a page-transition choice. It also improves photo saving, video gestures, and timeline reading. The build number is 23.

### New features

- **Home-screen cards**: Choose 2×2, 2×4, or 4×4 cards showing For You, Following, Trends, or Notifications. Cards follow the active account and display cached content. Tap a post to open its details, or use the gear to change the source and refresh the card.
- **Native profile editing**: Update your name, bio, location, website, avatar, and banner. Saving reloads the account profile and updates its display throughout the app. If part of a save fails, unfinished edits remain available for retry.
- **Twelve traditional colour themes**: Add cinnabar, vermilion, amber, autumn bamboo, bamboo green, azurite, cloisonne, indigo, begonia, rouge, sandalwood, and mountain palettes, with separate light and dark colours. Existing accent choices remain available.
- **Page-transition choice**: Choose the existing animation or the official style in settings. Changes apply immediately and survive restart; the existing animation remains the default. Photo and video viewers retain their own media-opening and closing transitions.
- **Double-tap video seeking**: Double-tap the right half to seek forward or the left half to seek backward. The default interval is 10 seconds, adjustable from 1 to 60 seconds, with an independent switch that leaves hold-to-speed preferences unchanged.
- **Photo author bar**: The photo viewer now shows author information, a profile shortcut, and follow controls, sharing relationship state with other pages.
- **Alternate icon**: Add a Zombie X icon option.

### Improvements and fixes

- **Me account overview**: Improve the avatar, banner, and account summary, and show known profile details immediately when opening the full profile. Refreshing the overview no longer fetches both post timelines.
- **Compact timeline cards**: Refine covers, text excerpts, and spacing in narrow columns. Galleries retain the full photo sequence, while videos and GIFs continue to follow the existing autoplay preference.
- **Photo saving and long-press menu**: Saving the current photo uses the system secure Save button, preparing its gallery destination after authorization and before the download finishes. Holding a photo opens the more menu, including recognition actions. With Save to files enabled, the system Save As picker confirms a destination for each file.
- **Reduced file-access permissions**: Remove persistent file-access permission and the long-term folder-authorization entry. Existing file-save preferences are retained; canceled or failed saves leave download tasks available for retry.
- **Independent mute choices and playback handoff**: Home previews and opened videos remember separate mute choices. Temporary silence, preloading, and player handoff no longer overwrite those preferences. Related overlays follow video-control visibility.
- **Initial Home rendering and recommendations**: Show real posts before injecting promotional content or opening the startup sheet. Empty and unrequested timelines no longer use promotions as placeholders. Keep multi-column item counts synchronized to address feeds remaining blank after loading.
- **Material defaults**: Sidebar material starts disabled and sheet material starts enabled on first use. Existing independent choices are retained.
- **Storage cleanup**: Recalculate clearable cache before confirmation, retaining completion and failure feedback.
- **Consistent version information**: Both X-new and Harmony-X now use version 3.1.0 (`versionCode` 23), with matching version descriptions in all 21 languages and project documentation. Each keeps its own app name, bundle name, and icons.

### Notes

- This version is unreleased; packages are not being uploaded yet.
- Automated tests and builds do not establish complete device acceptance. Card cold starts, actual profile submissions, video gestures, and tablet and foldable transitions still need full device verification. The previous release's limits for comment submission, playback advance, and server-confirmed account operations still apply.

## 3.0.0 — 2026-10-16

This release adds a Bilibili-style video layout with comment danmaku, shared-post previews in chats, and an interactive Logo page. It also reorganizes settings and improves navigation, pull-to-refresh feedback, and floating-button preferences.

### New features

- **Bilibili-style video layout**: The video feed layout picker now offers a Bilibili mode with author information, post text, actions, a fullscreen capsule, and an episode picker for posts containing multiple videos. It keeps the existing video sizing, fill, and background preferences. With automatic playback advance enabled, it plays the next video in the same post before moving to the next recommendation.
- **Comment danmaku**: Real replies to the current post scroll over the video in both regular and fullscreen playback and pause with playback. Danmaku follows existing automatic translation, target-language, and excluded-language settings, falling back to the original text on failure. You can also write a danmaku comment, which appears locally only after the server confirms publication. Sending publicly replies to the original post; existing comments have no video timestamps and are shown in rotation during playback.
- **Video tap action**: Choose between showing or hiding playback controls and pausing or playing in the video menu or media settings. The default retains the existing controls behavior, and the saved choice applies to Classic, Douyin, and Bilibili layouts.
- **Shared-post cards in chats**: X/Twitter post links and shared-post attachments load real previews with media, author, time, and text. Multiple photos use count-based grids, duplicate links in the message and attachments are merged, and standalone links are no longer repeated beside the card. Tap to open the post or hold to access message actions. Ordinary links can also be opened directly.
- **Interactive Logo and keepsakes**: Tap the app mark on the About page to open a particle Logo. Hold to assemble it, touch to scatter nearby particles, pause its animation, or add the current account avatar. Participation is stored locally per account and can be removed. Generate a keepsake image to save to the gallery or share through the system sheet.

### Improvements

- **Settings categories**: The settings home groups controls into Account and security, Appearance and experience, Content and language, Data and network, and Help and About. Search opens the page containing the control and displays its category path. Phone and desktop share the same catalog.
- **Video action feedback**: Bilibili-layout actions reflect real selection, counts, and pending requests, and capsules provide press feedback. The fullscreen entry fades away automatically, and the overlay hides while comments are open.
- **About page**: App information, version and build numbers, author accounts, and project and release links are presented together, with bundled brand icons.
- **Alternate-icon error messages**: Distinguish unsupported systems, third-party theme conflicts, and cloned-app restrictions while retaining the system failure reason.
- **Consistent version information**: The app is now version 3.0.0 (`versionCode` 22), with matching version labels across all 21 languages and both sets of project documentation.

### Fixes

- **Duplicate destinations and long back stacks**: Reopening the same content reuses its page. Selecting content from a sidebar or list on large screens replaces the previous detail branch, while ordinary phone navigation keeps its normal back path.
- **Hand preference and button position**: Store the manually preferred side independently of device hand detection. Disabling automatic detection restores that preference, and restarting or loading settings elsewhere no longer overwrites a recent choice.
- **Pull-to-refresh indicator**: The phone root-page loading indicator is no longer covered by the title-bar material and follows the pull gesture and refresh state.
- **Settings spacing and wrong categories on return**: Category cards have consistent side margins and short pages align to the top. Each subpage reads its own route parameters so returning through nested settings does not display another category.
- **Danmaku keyboard avoidance**: Adjust the immersive keyboard and sheet height to keep the editor and send action above the keyboard.
- **MeoW push entry**: Temporarily hide its settings and search entries while configuration is incomplete, retaining stored configuration and service code.

### Notes

- This release passes Release compilation, package version and metadata checks, and relevant automated regression tests. Those checks do not establish that every device scenario has been tested.
- Real comment danmaku and entering and leaving fullscreen were previously observed on a Mate 80 Pro Max. Public comment submission, episode auto-advance, live results from each translation provider, and tablet split layouts still need device verification. Settings margins were checked on a phone; desktop split settings remain unverified.
- Chat previews, Logo interactions, and keepsakes have logic regression coverage; complete on-device workflows still need verification. The previous release's server-confirmation and key-rotation limits for adding group members still apply.
- This build is unsigned and must be re-signed with your own HarmonyOS certificate and profile before installation.

## 2.9.0 — 2026-10-15

This update adds a continuous one-shot transition when opening and closing photos and videos, a hold-to-speed control for videos, a switch for the media viewer comment sheet background, and a group chat management page, and it fixes GIF downloads, the download folder, multi-video fullscreen, and the list endpoints.

### New features

- **Hold to speed up video**: Display settings has a new Hold to speed up video switch, enabled by default. Pressing and holding a playing video temporarily raises it to 2x and shows a glass capsule below the back and more row with the current rate and a fast-forward label, and releasing restores the original rate. While holding, sliding the finger up or down changes the rate by 0.5x between 0.5x and 4x, the capsule shows a slow-motion label below 1x, and the rate shown on the playback bar follows along. It works for post videos on Home and profiles and in the video feed; turning the switch off keeps the original hold-to-seek gesture, where the left half rewinds and the right half forwards.
- **Media comment sheet background switch**: Display settings has a new Media comment sheet background switch, enabled by default. When it is on, the post and the comment area inside the photo and video viewer comment sheet have a background; when it is off, both areas become transparent and the media behind them shows through.
- **Group chat management**: Private-message group chats now have a group profile and management page. You can change the group avatar, edit the name and description, switch the invite link and permissions such as admin-only posting, manage admins, add or remove members, give a member a nickname that only applies on this device or message them directly, and leave the group. Member search and adding reuse the shared account row card.

### Improvements

- **Consistent version information**: The app is now version 2.9.0 (`versionCode` 21), with matching version labels across all supported languages and both sets of project documentation.
- **One-shot photo and video transitions**: Photos and videos opened from a timeline, a post, or a chat now expand continuously from the tapped position into the viewer and return along the same path, without blank strips or a black flash. A video returns straight to its original player instead of being covered by a screenshot, and cleanup of the old page is isolated; an image gallery keeps the swipe position it had when the viewer is closed instead of being forced back to the center.
- **Download folder uses the bundle name**: The default download folder is now named after the app bundle name `com.haohaoai0.harmonx` instead of the app name, so File Manager lists the app under its source entry.
- **GIFs saved as animations**: Downloading a GIF now re-encodes it from the video stream and saves it as an animated GIF instead of saving a video; if re-encoding fails it falls back to saving the video and shows “GIF 转换失败，已按视频保存”.
- **List endpoint alignment**: List timelines, members, your lists, and the list directory now use the same requests as x.com, adding `ListBySlug`, `ListLatestTweetsTimeline`, `ListMembers`, `ListMemberships`, and `ListOwnerships` and refreshing the rotated operation identifiers; list authors and the add-members picker match the web behavior.
- **Fullscreen photo viewing**: The photo viewer's black covering layer now extends under the system status bar and navigation bar, so no background shows at the edges, and the system bars themselves are no longer hidden or pushed up.

### Fixes

- **Multi-video fullscreen**: When a post has several videos, the fullscreen button on each video plays that video; previously they all played the first one.
- **List loading failures**: When a list request returns 200 with data, the data is kept even if a non-fatal notice accompanies it, instead of failing the whole response and falling back to a retired endpoint; fatal errors such as rate limits, unauthorized requests, and bans still fail as before.
- **Sign-in status message**: A failed session save no longer reports a successful sign-in.

### Notes

- Hold-to-speed, the media comment sheet background, the download folder, and GIF saving were verified on a Mate 80 Pro Max; the final feel of sliding to adjust the rate while holding is subject to on-device testing, and any remaining detail issues will be addressed in a later version.
- The group chat management page follows the x.com implementation. Adding members still depends on server confirmation and a new key-rotation signature, and this round did not confirm on a real device that an added member can join the group.
- The list changes were verified on a device with a correctly rendering timeline.
- This build is unsigned and must be re-signed with your own HarmonyOS certificate and profile before installation.

## 2.8.0 — 2026-10-13

This update improves notifications and mentions, video recommendations and video-feed layouts, and the composer options, reworks the desktop and sidebar experience, and fixes crashes, the photo viewer, and page transitions.

### New features

- **Local browsing history**: The side menu now has a Browsing history page that keeps a post link list on this device only. Opening a post from a timeline and every video reached in the video feed are recorded. The list groups entries by date with the author, a content summary, and an image or video thumbnail, and supports local search, single-entry deletion, and clearing. Entering the page backfills the summary and thumbnail of older entries.
- **Complete composer options**: The composer toolbar now covers polls, emoji, scheduled posts, location, reply permissions, and content disclosure. Polls support 2–4 choices of 25 characters each, durations from 5 minutes to 7 days, and an image per choice; the emoji panel searches and inserts at the cursor; scheduling uses the system date and time pickers and can list already-scheduled posts; location requests device location permission and resolves one real coordinate to look up nearby places, with keyword search as well; reply permissions offer everyone, verified accounts, accounts you follow, only mentioned accounts, and accounts you follow plus those they follow; content disclosure has separate AI-generated and paid partnership switches. The new options are saved in the local draft together with the text and media.
- **Video feed layout switch**: The video feed's more sheet has a Video feed layout group to switch between the original X layout and a Douyin layout. The choice is stored locally and restored on launch. The Douyin layout moves the avatar, like, reply, repost, bookmark, and share controls into a right-hand vertical material rail and the author and text to the lower left, leaving the bottom playback controls unchanged. The group is hidden in wide landscape and large-screen split view.
- **Desktop sidebar material and expand style**: The desktop left sidebar supports glass, gradient blur, and off, with five strength levels. API 26 and later use the system material and lower versions use the matching background blur, and the phone sidebar shares the same settings. The handle is larger and bolder, and a new expand-style page offers several preset artworks plus imported 128×128 or 256×256 images or GIFs. Expand styles apply to desktop mode only.
- **Desktop sidebar auto-collapse**: The desktop left sidebar stays hidden by default. Swipe right from the left edge of the device to reveal it, swipe left to collapse it, and tapping outside the panel also collapses it. Swipe-to-open can be disabled on its own; the handle and outside taps keep working.
- **Reply capsule material switch**: Display settings now include a reply capsule material switch, enabled by default. When disabled, the small reply buttons and the input box use a transparent background, the text and delete icon switch to the theme and red colors, and the outer capsule keeps its material.
- **Notification content layout**: Ordinary notifications are layered into a type icon, avatar, description, time, and post summary, and mentions render as a full post card that can be liked, replied to, and reposted.
- **Alternate icons**: Two new frog icons, on black and white backgrounds, join the HarmonyOS 7 alternate icons, with names in all 21 languages.

### Improvements

- **Consistent version information**: The app is now version 2.8.0 (`versionCode` 20), with matching version labels across all supported languages and both sets of project documentation.
- **Video recommendation deduplication across sessions**: The video stream now uses X's web ImmersiveMedia timeline and viewing session events, storing timeline state per account and per seed post. Videos actually watched are excluded the next time the stream opens, prefetched but unwatched candidates are kept, and the previous video endpoint is used as a fallback. Reopening the feed from the same seed no longer repeats the first recommendations.
- **Profile title bar transition**: The message and follow buttons scroll with the profile wall and move continuously into the title bar as it approaches; when already following, Grok and search collapse into the more menu, and these buttons now use the same material as the more button.
- **Video feed framing**: Portrait videos that almost fill the screen are scaled by up to 6% to fill the playback area and remove the gap at the top, while other aspect ratios use the largest complete frame in the available area instead of forcing portrait videos to the top.
- **Video progress bar touch target**: The bar is 6vp thick with a 44vp touch area, separated from the speed and mute controls.
- **Large-screen media pages**: The landscape video page restores the post details, action bar, comments, and reply entry, and the outer margin around the media surface is removed.
- **Post detail buttons**: The action buttons below a post on the detail page are smaller.

### Fixes

- **Chat crash**: Tapping the floating compose button on the chat page no longer crashes on an undefined shared payload when opened without parameters.
- **Empty notifications**: The post notification group request was blocked by the client's own path check and never reached X, leaving the list empty; it is now allowed and uses its dedicated notification timeline. The mentions tab previously only filtered notifications already loaded on the All tab; it now issues its own mentions request and parses posts returned directly in it, so mentions appear correctly.
- **Swipe up after enlarging a video**: Enlarging a video from Home, a recommendation, or someone's profile and swiping up now enters the video feed and continues with recommended videos instead of triggering the brightness gesture.
- **Floating button behavior**: On another user's profile the floating Home button still opened the composer; it now returns to the top for the current page.
- **Photo viewer likes**: The like icon in the photo viewer now refreshes with its state, View original moved into the more menu, and the back, download, more, counter, and reply-label foregrounds now use the reverse-color treatment of the system material.
- **Transition gaps**: The navigation animation is clipped and large-screen fullscreen photos use the system cross-fade, removing blank strips when opening, closing, and sliding into post details.
- **Landscape secondary pages**: Tapping a post in the landscape split view replaces the details pane instead of stacking pages, and opening the same post reuses the existing details.
- **Portrait photo light leak**: The light strip on the left of portrait photo details on the Pura X Max is addressed.
- **Phone sidebar material**: Gradient blur no longer looks identical to a disabled material on phones; the legacy blur preset's own mask was washing out the background over the container color. Disabling the material now sets the container background directly so the collapse animation does not race the container and flicker.
- **Composer tool sheets**: Tapping the emoji, date, or location tool buttons now opens its sheet reliably.

### Notes

- The new composer options follow X's web request contracts and each sheet was opened on a real device. Location obtained a real device coordinate, but X's places endpoint returned no nearby places at that moment, and no post with a poll, schedule, or location was actually published, so server acceptance still needs your own verification.
- Location is used only to look up nearby places; the draft stores the selected place rather than the device coordinate. Polls cannot be combined with ordinary images, GIFs, or videos, and Community posts cannot be scheduled.
- The video feed layout switch and recommendation deduplication were verified on a Mate 80 Pro Max. Pura X Max and other foldable form factors, the Douyin layout branch in landscape and large-screen split view, and the desktop expand styles on tablets still need device verification in those scenarios.

## 2.7.0 — 2026-10-12

This update improves video recommendations, Home refresh, notification browsing, and post controls, with custom fonts, ad filtering, and more large-screen layout options.

### New features

- **Custom app fonts**: Import a TTF, OTF, or TTC font in display settings, preview it, and apply it throughout the app interface. The choice is saved locally and restored after restart, with an option to return to the system font.
- **Hide ads switch**: Content filtering now includes “Hide ads,” enabled by default. It hides posts explicitly marked as ads by X and promoted Explore cards. Turn it off to restore them; ordinary paid partnership disclosures are retained.
- **Post menu**: Post cards now have a native menu button for Not interested, following or unfollowing, muting, blocking, and adding or removing the author from your lists. It also provides post interactions, reporting, Community Note requests, and hidden replies.
- **Multiple-post notifications**: Bell notifications and notifications containing multiple posts open a dedicated native list with the corresponding posts, authors, and media, with links to individual post details.
- **Home refresh behavior**: Separate switches control double-tapping Home and pulling to refresh. Both show new posts and return to the top by default. Disable either to keep your reading position and reveal updates through the new-posts pill.
- **Desktop right sidebar switch**: Close the search, trends, and recommendations sidebar directly, or restore it in display settings. The choice persists, and the main content expands into the available space.

### Improvements

- **Consistent version information**: The app is now version 2.7.0 (`versionCode` 19), with matching version labels across all supported languages and both sets of project documentation.
- **Independent video recommendations**: The tapped post starts a video stream with its own recommendation requests and pagination, excluding source-list videos and those already delivered during the session. Failed requests retain the error and a retry option.
- **Home recommendation refresh**: Track posts actually viewed, separately for each account, send recent observations with refresh requests, and filter duplicates. Refresh and pagination use separate cursors; failed refreshes preserve the current content and reading position.
- **Desktop Home columns**: Choose automatic layout or one, two, or three columns. Automatic layout uses the actual content width and responds to sidebar visibility and window resizing.
- **Title bars and tabs**: Improve reuse of shared avatar, logo, and title bar nodes. Tab pills follow their content widths, with better enlarged-text display and horizontal scroll positioning.
- **Large-screen media comment sheets**: Center comment sheets on large screens while preserving photo zoom and video placement when opened or resized. Narrow windows retain bottom sheets and media avoidance.
- **Launch icon**: Use a dedicated 144×144 icon resource for the launch window.
- **Photo viewer edges**: Improve the black backdrop, safe-area coverage, and blurred-background clipping to address exposed edges in portrait photo details.

### Fixes

- **Video taps and continuous playback**: Address video taps failing to open the viewer when autoplay is enabled, and the next video remaining paused when Home autoplay is disabled. Entering the viewer retains the current playback position.
- **Existing large-screen layout**: Restore title bars, the persistent sidebar, and notifications when desktop mode is disabled. Notifications remain accessible from the sidebar or system notifications when their bottom-bar entry is hidden.
- **Browsing during split-view changes**: Keep the Home list and visible post nodes mounted when opening or closing detail panes, reducing video restarts and lost reading positions.
- **Overlapping Explore headers**: Calculate content clearance from the actual account row, search bar, and tabs to address overlap, clipping, and excess spacing after page changes or text enlargement.
- **Large-screen settings crash**: Resolve conflicting navigation scopes in settings split view and restore the full list width after closing the final settings detail.

### Notes

- Not interested submits feedback when X provides valid feedback data. Otherwise, the post is hidden locally with an explicit message. Reporting, Community Note requests, and hidden replies continue on X's official pages.
- X determines recommendation ranking. Better observation history and deduplication do not make the recommended feed chronological or guarantee new content on every refresh.
- Portrait viewer edges on both Pura X Max screens, multiple-post bell notifications, and automatic advancement after a complete video still need verification on devices in those scenarios.

## 2.6.0 — 2026-10-11

- **Consistent version information**: The app is now version 2.6.0 (`versionCode` 18), with matching version labels across all supported languages and project documentation.

## 2.5.0 — 2026-10-10

- **Consistent version information**: The app is now version 2.5.0 (`versionCode` 17), with matching Chinese, English, and Italian version labels and project documentation.

## 2.4.2 — 2026-10-07

- **Consistent version information**: The app is now version 2.4.2 (`versionCode` 16), with matching Chinese, English, and Italian version labels and project documentation.
- **Media viewer backgrounds**: Videos use a blurred cover and photos use the currently selected image. Shared requests, bounded retries, and stale callback guards address missing backgrounds, and each video page restores its own background when swiping back.
- **Reopening photos**: The viewer and backdrop own separate decoded images while retaining the download cache. Resetting each visit prevents previously viewed photos from opening blank.
- **Comment sheets**: Updated keyboard avoidance for video and photo post sheets, aligned the post, reply, and discovery section radii, and added bottom spacing to the post.

## 2.4.0 — 2026-10-07

- **Consistent version information**: The app is now version 2.4.0 (`versionCode` 15), with matching Chinese, English, and Italian version labels and project documentation.

### New features

**Spaces**

- **Native Spaces interface**: The Spaces entry is now a native implementation with live, upcoming, and replay sections, search, and cards showing host details and listener counts.
- **Background listening**: Listening reuses the existing AVPlayer and system audio session, so playback continues on Home after leaving a room; the Home listening bar can reopen the room or stop playback.
- **Listening page and members**: The listening page previews hosts and speakers, then shows a grid of public members. The members page filters everyone, co-hosts, speakers, and listeners, and avatars open the matching profile.
- **Prepare a Space**: Set a name, recording preference, up to three topics, and a schedule within the next 14 days. Drafts are saved on device per account, and publishing still goes through the official X flow.
- **Reminders**: Upcoming Spaces can be added to the system calendar with a 10-minute default reminder that can be edited there.
- **Space floating button and more menu**: Spaces reuses the shared compose floating button, keeping drag, grip posture, material, and press effects. The more menu offers sharing and a per-account "Not interested" action, while reporting happens on the official X page.

**Communities**

- **Browsing**: A new Communities entry lists communities, and each community opens a timeline with its posts, rules, and source.
- **Search**: Communities can be searched by keyword and opened from the results.
- **Post source labels**: Timelines and post details show which community a post came from, and tapping it opens that community.

**Posts and messages**

- **Polls**: In-post polls show their options and current results, with voting from the app.
- **Message emoji**: The message emoji panel and bubbles now render Twemoji artwork, with the long-press menu actions filled in.

### Improvements

- **Video feed**: Mute and other playback settings match the video page, and playback state is coordinated between the feed and the full player to avoid duplicate starts.
- **Quoted posts and profiles**: Quoted post cards and the related profile pages were updated together.

## 2.3.0 — 2026-10-07

- **Consistent version information**: The app is now version 2.3.0 (`versionCode` 14), with matching Chinese, English, and Italian version labels and project documentation.

## 2.0.0 — 2026-10-03

This release covers changes made after the 1.8.0 changelog was completed, from September 30 through October 3, 2026. It includes Home and profile interactions, video playback, GIF search, image recognition and editing, list management, and native Spaces listening.

### New features

**Home and timelines**

- **Timeline management**: Search preset topics and pin or unpin topics such as technology, AI, sports, and gaming. Pinned topics appear in the Home switcher and open their corresponding search results.
- **Pause topics**: Hide selected topics from For You for one day, with automatic expiry and a reset option. Settings are saved locally and do not change who you follow on X.
- **Following order**: Choose Latest or Trending. Loaded posts are ordered by publication time or their combined likes, reposts, and replies.
- **Double-tap Home to refresh**: Tap the Home tab twice in quick succession to refresh the timeline. Both HDS and compatibility bottom navigation support this gesture; the Home floating button keeps its compose action.

**Follow discovery**

- **Suggested accounts**: Home and user profiles provide recommendations with profile links and follow actions. Follow state stays in sync across related pages.
- **Starter packs**: Browse X starter packs by categories such as news, sports, technology, and music, preview their accounts, and follow a whole pack. Loading failures and pack limits have explicit messages.

**Posts, replies, and GIFs**

- **Online GIF search**: The composer's GIF entry offers local selection or online search. Online search provides popular suggestions, keyword search, and animated previews; selecting a GIF returns it to the composer as an attachment.
- **GIF context menu**: Long-press a GIF in search results or a post to see an image preview and a menu over a blurred background, with Save to gallery and Share GIF actions.
- **Mixed image and GIF attachments**: Photos and one GIF can coexist in a draft, with up to four items in total, such as three photos and one GIF. Draft restoration preserves mixed attachments. Videos remain exclusive with photos and GIFs.
- **Expanding reply capsule**: Focusing the input reveals the send action; dismissing the keyboard restores the collapsed state. Selecting one photo stays on the detail page, expands its preview, and opens the keyboard. Tap the image to edit it or use the red material button to remove it.
- **Full-screen reply context**: The original post starts above the visible editing area and can be revealed by pulling down. Your own input remains visible rather than being hidden with the original post beneath the title bar.

- **Edit attached images**: Post and reply composers can open an image editor with original, square, 4:3, and 16:9 crop ratios, left and right rotation, mirroring, and filters such as vintage, black and white, and warm tones.
- **Text and drawing**: Add, move, edit, and delete text overlays; choose text and brush colors; draw or clear strokes; and undo or redo changes. Applying edits returns the processed image to the composer as an attachment.

**Image viewing and recognition**

- **Text recognition**: Long-press an image or choose Recognize text in the full-screen viewer. Copy one line or all recognized text, or use it to search within the app.
- **Subject extraction**: Extract an image subject, preview it as a sticker, and add it to the composer as a transparent PNG. Failed processing shows an error message.

**Video and playback**

- **Four quality modes**: Settings and the video feed menu offer Auto, HD, SD, and LD. Auto limits bitrate using the network type and estimated bandwidth, reverting to a conservative policy when network information is unavailable.
- **Keep controls visible**: A new video feed option keeps controls visible during immersive playback. The preference is saved and takes effect immediately.

**List management**

- **Create and edit lists**: Set a name, description, and public or private visibility, and select, replace, or remove a cover. After creation, add members in a second step or finish and add them later.
- **Manage members**: Search for users and add or remove members of your own lists. Existing membership is checked before management actions become available, preventing existing members from appearing with an Add button.
- **Discover and organize lists**: Search, follow or unfollow, pin or unpin, share public lists, and view Lists you're on. Your own lists can be deleted after confirmation.

**Spaces**

- **Native Spaces pages**: A new drawer entry lets you search Spaces and switch between All and Live. Cards show live, scheduled, and replayable rooms; room details show the host, speakers, listeners, and participant count.
- **Live audio and replays**: Listen, pause, resume, leave, and share a Space, or open a room directly from a Space link in a post. Scheduled, ended, unavailable, and failed connections have distinct states and retry actions where applicable.
- **Background controls**: Listening can continue in the background or with the screen locked, with system media controls. A listening bar at the bottom of the directory lets you return to the room, pause, or leave.

### Improvements

- **Video playback across pages**: Moving from Home to the video feed and back attempts to hand over the same player, preserving position and buffered content. When handoff is unavailable, playback resumes from the saved position.
- **Caching during playback**: MP4 videos shorter than five minutes with a known file length can be progressively cached during playback. Other cases fall back to normal network playback.
- **Video loading recovery**: Retain multiple quality variants, retry temporary failures, and switch to lower bitrates on buffering timeouts while preserving position. Failed segmented sources can fall back to direct playback, and proxy caches check file completeness.
- **Faster image opening**: Post thumbnails and the full-screen viewer reuse downloaded and decoded images, reducing repeated work. GIF search shows a thumbnail first, then the full animation.
- **Original image display**: The viewer keeps the original image. Automatic super-resolution and detail enhancement have been removed; text recognition and subject extraction run when requested.
- **Reply context**: Replies in Home and user profiles can include their parent posts in conversation order, making the discussion easier to follow.
- **Profile layout**: Show a single banner without dimming it while fully expanded. Back, Grok, search, and menu buttons share material and press feedback, and the floating button replies to the current author.
- **Profile tabs**: Swipe horizontally through profile content while icons, labels, and the indicator transition together. The posts category switches between posts and highlights; media switches between videos and photos.
- **User actions**: Improve profile search, sharing, repost visibility, mute, and notification controls. Advanced notification options and reporting open X's official pages.
- **Post information**: Improve parsing and presentation of repost attribution, publication times, view counts, and media in long posts. Cards use relative times, while details retain the exact date and time.
- **Media layout**: Improve shared heights for image pairs, portrait proportions, and wide-screen sizing, preventing media from entering the avatar column or becoming oversized.
- **Floating button materials and visibility**: Improve translucent accent tint, circular bounds, and press feedback. Disable material touch lighting while retaining the button's point light. Home hides the button when scrolling deeper into content and restores it when scrolling back.
- **Spacing and separators**: Center notification content in both lists and waterfall layouts with balanced side spacing. Remove extra separators from Explore categories, search result categories, and search-history suggestions.
- **Playback coordination**: Videos and Spaces share playback coordination. Starting another item pauses the previous one to reduce overlapping audio.
- **Unified video controls**: Remove the Video control style setting and its previous floating-controls option. Existing preferences migrate to bottom controls that fade away.
- **Consistent version information**: The app and Chinese, English, and Italian version labels now show 2.0.0 (`versionCode` 11), with matching project documentation.

### Fixes

- **Home videos restarting after scrolling away**: Retain and reuse paused players while their list items remain cached. Recycled items restore playback using cached files and saved positions.
- **Immersive video filling only the poster**: Correct the video and container layout so the playing image also fills the immersive view.
- **Brief pauses when changing feed videos**: With autoplay enabled, take over the next video's already-running muted preload directly, reducing stalls caused by waiting for pause callbacks.
- **Avatars disappearing across pages**: Display avatars from locally cached files instead of relying on released image objects. Initials remain visible while loading.
- **Profile replies failing to load**: Correct user parameters, fallback requests, and operation identifiers. Reset scroll position when switching categories so an old position does not make new content appear empty.
- **Keyboard avoidance after returning to details**: Restore keyboard observation and avoidance after full-screen replies, keeping the reply capsule above the keyboard without incorrectly shifting the entire page.
- **Oversized GIF attachments**: GIFs share the photo attachment grid and retain their aspect ratio instead of filling the whole attachment area.
- **Looping animations treated as ordinary videos**: Display X animations as muted looping GIFs, hide regular video controls, and exclude them from the video feed, full-screen playback, and picture-in-picture.
- **Static or blank GIF previews**: Preserve GIF animation when a proxy is enabled instead of decoding a single frame. Keep an available thumbnail when the animation cannot be loaded.
- **Spaces failing to resume**: Resuming live audio reconnects to the current stream rather than requesting expired segments. Replays retain their playback position.
- **Unclear list save results**: Distinguish saving list information, uploading a cover, and confirming creation. Failed cover uploads can be retried or skipped, and unconfirmed creation prompts a refresh before retrying to avoid duplicate lists.

### Notes

- Topic pauses filter For You locally using keywords and media types. Trending sorts the Following posts already loaded. Neither changes X's server-side recommendation or ordering settings.
- Spaces currently supports browsing, listening, and replays. Creating a Space, requesting to speak, and host controls are not supported. Audio and replay availability depend on the room state and audio returned by X.
- People you may know links to X's contact settings. Syncing device contacts within Harmony X is not supported yet.
- Image text recognition and subject extraction depend on the corresponding system capabilities. Processing failures show an error; the viewer does not automatically replace or enhance the original image.
- Looping animations in X posts may use MP4; saving and sharing retain the source format. Actual GIF files from GIF search retain the GIF format.

## 1.8.0 — 2026-09-30

This release focuses on getting started, discovering content, managing media downloads, and personalizing the interface.

### New features

- **Getting started guide**: A first-launch walkthrough introduces timelines, Explore, interactions, and media settings. You can sign in to X during the guide or skip sign-in and browse first. Completion is saved on the device.
- **Custom bottom navigation**: Under Settings → Display, choose which of Home, Explore, Notifications, Messages, and Profile appear in the bottom bar. At least two pages must remain visible.
- **Scheduled app icon**: Under Settings → App icon, choose a daily start time, end time, and icon, including time ranges that cross midnight. Outside that range, the app uses your regular icon. It checks the schedule when it returns to the foreground.
- **Download manager**: View image and video download progress, pause, resume, or delete tasks, and clear the app's video playback cache. After a download finishes, you still choose whether to save it to the gallery.
- **Post body font**: Choose the system default, serif, or monospace font for posts, quoted content, post details, and the read-aloud page.

### Improvements

- **Consistent version information**: The app is now version 1.8.0 (`versionCode` 9), with matching version labels on the profile page and in project documentation.
- **Explore content**: Display event highlights, trends, account and post groups, and horizontal event cards from X's response. Video highlights can preview muted and open the video feed.
- **Home title bar**: An optional scroll behavior moves the timeline switcher next to the avatar while browsing down and restores the full title bar when scrolling up. It is off by default.
- **Video controls**: Choose between bottom controls that fade away during playback and the previous floating controls.
- **Video CDN proxy**: A separate proxy setting can route X video CDN MP4 requests through the selected in-app proxy. HLS playback still uses the system network path.

### Notes

- Changing app icons requires HarmonyOS 7.0 or later. The system may pause schedule checks while the app is closed or in the background; the app checks again when brought to the foreground.
- Downloads may be interrupted if the app is force-stopped or the device shuts down. Unfinished tasks can be resumed later.

## 1.7.0 — 2026-09-28

This release synchronizes the 1.7.0 release information across the app and project documents.

### Improvements

- **Consistent version information**: the app version is now 1.7.0 (`versionCode` 8), and the version label on the profile page matches.
- **Updated documentation**: the Chinese and English changelogs and both READMEs now report version 1.7.0.

## 1.6.0 — 2026-09-27

Another overnight iteration after the night of September 25. Communities, Grok and post edit history are new, bookmarks and lists grow into complete browsing paths, and encrypted messages plus cross-device continuation finally work end to end. Grouped by theme.

### New features

**Communities**

- **Community directory**: the Communities entry is split into "My communities / Discover / Recommended / Explore", with community search and topic filtering. Each row shows the banner, name, description, member and moderator counts, and a "Joined" badge, and paging continues as you scroll.
- **Community timeline**: inside a community you can switch between "All posts / Media / Tags". The tag tab filters by keyword and sorts by "Relevance / Latest", and the media tab keeps only posts that carry an image or a video.
- **Community rules**: rows report how many rules a community has, and "View rules" opens a page that lists every rule with its name and description.
- **Saved communities**: a community can be added to the "Favorites" tab. That list lives only in local preferences (capped at 100 entries) as a personal shortcut and never joins or follows anything on X.

**Grok**

- **Open Grok from a post**: the post detail title bar menu gained a Grok entry that carries the current post along as context.
- **Original web mode (default)**: grok.com opens inside the app with the post text and link passed in as a query parameter. You choose whether the active X web session is written into the Web component first so Grok can continue with "Sign in with X"; Grok's own sign-in and usage stay with the official page and X credentials are never handed to grok.com.
- **Built-in API mode**: set an xAI API key, model (default `grok-4-1-fast`) and API base URL (default `https://api.x.ai/v1`) in Settings and replies come back from xAI itself. Requests reuse the in-app proxy and the key stays on the device.
- **Suggested prompts**: the Grok page offers "Summarize this post / Explain the discussion / What is worth asking next". Both modes share the same post context and replies accumulate as a conversation.

**Bookmarks**

- **Bookmark collections**: the bookmarks page gained an "All / Collections" switch. Collections created on X can be browsed and opened one by one, and "Clear filter" leaves a collection again.
- **Bookmark search**: a search field at the top of the bookmarks page searches the current scope — everything or one collection — with paging.

**Lists**

- **My lists**: both the side drawer and Settings → My lists open the lists page, which shows the lists you created and subscribed to; opening one shows that list's post timeline.
- **List members**: a list timeline offers "View members" in the title bar, and the member list reuses the shared account row card so members can be opened in place.

**Posting**

- **Long posts**: the composer's ceiling moved from 280 to 4000 characters. Text past 280 characters is published through the long-post operation, the editor says "Will be published as a long post", and the counter shows 4000 with publishing disabled only beyond that.
- **Undo post**: the composer can enable "Undo post", which publishes through X's undo-post operation so the new post can still be taken back inside its undo window; leaving it off keeps the normal path.
- **Server drafts**: the composer reads the drafts the account already has on X, restores the matching one into the root editor or a specific reply with "Server draft restored", syncs further edits back to the server draft, and can delete it permanently after a confirmation.
- **Post management**: the overflow menu on your own post can pin or unpin it, set who may reply (everyone / followers only / mentioned people only) or delete it, and every action reports its result instead of failing silently.

**Media and multi-device**

- **Cross-device media sources**: the image, video and camera buttons each open a source menu first, listing the local gallery or the system camera next to the devices signed in to the same HUAWEI ID — phone, tablet and 2-in-1 — offered through Service Collaboration Kit.
- **Remote camera**: the camera menu lists nearby devices so the photo is taken by the other device's camera and handed back, while local capture still uses the secure system camera and local video recording keeps its existing path.
- **Returned files are cached**: incoming images and videos are written to the app cache by type before being attached, images stay capped at four with de-duplication, and video stays single-select, clearing the chosen images and GIF.
- **Where it applies**: the root composer and the reply editor share the same source menu. Recording video on another device is not offered, because the system only exposes remote photo capture and remote gallery selection.

**Display and title bar**

- **Three title bar styles**: Settings → Display gained a "Title bar" row that chooses between "Immersive gradient blur / Gradient blur / Glass material". Immersive gradient blur keeps the scroll effect each page was tuned with; gradient blur keeps only the system material and sets no scroll background; glass material adds the app's own glass panel on top of the full scroll styling, with a five-step material thickness.
- **Glass can drop the immersive blur**: in the glass style an extra switch turns the immersive blur off, leaving only the glass panel and system material so the bar no longer blurs as content scrolls. The home, search, profile and every secondary destination — 20 title bars in total — render through the same setting and update immediately.

**Home timeline**

- **New-posts capsule**: when a refresh brings back posts that are off screen, the home feed keeps the reader's position and floats a capsule at the top of the content instead: an upward arrow next to up to three author avatars, with a "+N" badge beyond that. The capsule is tinted with the app accent colour inside the system immersive material, falls back to a solid capsule where the material is unavailable, and its accessibility label reads out the new-post count and the authors.
- **Tap to return to the top**: tapping the capsule merges the new posts at the top over a 220 ms transition, scrolls smoothly back to the newest post, clears the pending state and brings the floating compose button back. Refreshing when the feed is already near the top shows no capsule and simply refreshes the list in place.

**Replies and quotes**

- **Reply sorting**: the reply pane on a post detail gained a "Sort replies" sheet with "Relevance / Recent / Most liked".
- **View quotes**: the detail page gained a "View quotes" entry that opens the list of posts quoting this one, with an explanatory empty state.
- **Comments carry their own numbers**: comment and reply rows no longer show a lone translate button. They display that comment's own reply, repost, like and view counts, drop the number when it is zero, and keep the translate control at the right end.

**Profile**

- **Pull to refresh**: the Me tab refreshes on pull, reloading the signed-in account's profile and posts.

**Edit history**

- **Edit history**: the post detail overflow menu gained "Edit history", which lists the versions X keeps for that post in chronological order, with dedicated empty and failure states.

**Direct messages**

- **Encrypted threads open in the web client**: XChat bodies are end-to-end encrypted events whose keys only exist inside X's own client, so a conversation now opens in the built-in Web component as the active account on x.com/messages. Encrypted threads can be read and replied to from there, while the in-app conversation list, unread counts and badges stay native.
- **Visible, retryable failures**: only a failed main document replaces the conversation (a failed avatar or font no longer hides a readable thread), the failure state offers "Message loading failed, check your network or proxy and retry", and cookies X refreshes while the page runs are written out immediately.

**Multi-device and system entry points**

- **App continuation**: the entry ability is declared continuable. Continuing to a tablet, 2-in-1 or another device carries the home, post detail and composer state — post id, reading position, reply sort, draft text and reply target. Credentials, cookies and device-local media URIs deliberately never enter the continuation payload.
- **Link handling**: x.com, twitter.com and their www/mobile hosts are declared as handled links, so tapping one in another app lists Harmony X in the system "Open with" chooser and opens it in the app. No domain verification is done; this is plain Deep Linking.

**Settings**

- **Grok section**: Settings gained a Grok section that picks "Original web page / Built-in API" and manages the model, API key, API base URL and "Pre-seed the X web session".
- **My lists entry**: Settings gained a My lists row that opens the same page as the drawer entry.
- **Title bar entry**: Settings → Display gained the "Title bar" row where the three styles and the glass material thickness are chosen.
- **Immersive full-screen video**: Settings → Images and video gained a switch. When on, video fills an immersive full-screen view at its full frame with a blurred cover behind the uncovered area and the playback bar moved up; when off, it keeps its original ratio inside the rounded container.
- **Sensitive media**: Settings → Images and video gained "Show media that may contain sensitive content". With it off only a blurred low-resolution preview is loaded, an individual post can still be revealed, and the choice only affects this device.

### Improvements

- **Notification groups**: notifications and direct messages publish into two separate system notification groups while still syncing the launcher badge, and Do Not Disturb keeps updating only the in-app dot.
- **One card and title bar vocabulary**: communities, bookmarks, lists and account lists now share the standard post card, account row card and gradient-blur title bar, so light and dark mode look the same everywhere.

### Fixes

- **A transport success is no longer a publication receipt**: previously any successful response could have an arbitrary nested id mistaken for the new post. Now only the id at the mutation's documented result path counts, and when it is missing the draft is kept with "Sending is not confirmed yet" instead of leaving you on the wrong post or posting twice.
- **Signed-out destinations**: bookmarks, lists and communities ask you to sign in instead of showing an empty list or a raw error.
- **Action bar after translating**: when a post detail has too many actions the bar now wraps into two rows of three equal columns, so adding the translate button no longer skews the icons.
- **Refresh dot during tab switches**: the extra loading dot that was drawn in the bottom corner while switching tabs is gone; switching and pull-to-refresh behave as before.
- **Grok web sign-in kept dropping**: the Grok page now waits for the web cookies to finish restoring before loading, snapshots the session every 5 seconds while signing in, and saves once more on leave or background, so a restart asks for a sign-in far less often.

### Notes

- Communities are read-only for now: browsing, filtering, members, rules and saving are wired up, but posting or joining inside a community is not.
- Grok web mode depends on grok.com's public page and official sign-in, so it can break because of the network, the region or a redesign on their side. Microphone access is requested only for voice input on pages the app itself opens.
- A direct-message thread is an in-app web view, so what it can do matches the x.com web client and the active account's web session is what drives it.
- Continuation carries no credentials, cookies or device-local media URIs; continuing onto a device that is not signed in stops at the sign-in page.
- Link handling is plain Deep Linking without domain verification, so the system may still offer a browser next to Harmony X.
- Long posts and undo-post depend on the account's entitlement on X; without it the server's rejection surfaces as a normal error instead of a fake success.

## 1.4.0 — 2026-09-25

Continuous iteration after the daytime of September 24, grouped by theme.

### New features

**Video and playback**

- **Cross-device gallery selection**: the image and video buttons now open a source menu with this device's gallery and nearby devices available through Service Collaboration Kit. Returned images and videos are written to the app cache and added as attachments.
- **Secure system camera capture**: the composer's camera button now opens the system `cameraPicker` and adds the returned media URI directly as an attachment instead of falling back to the photo library picker.
- **Video posts**: the composer can now attach one video and uploads it through X's `INIT / APPEND / FINALIZE / STATUS` chunked workflow before publishing. Images, GIFs and video are mutually exclusive, and oversized or unprocessable videos get a specific message.
- **Fullscreen player gestures**: swipe horizontally to seek with a time preview, drag up or down on the left half to change the app window brightness (the system brightness returns on exit), and drag up or down on the right half to change the player volume without touching the system volume. A new lock button in the control bar disables every player gesture and control until the surface is tapped, and the screen stays awake while playing fullscreen.
- **Background playback**: Settings → Images and video → Background playback chooses what happens after the app leaves the foreground or the screen locks. "Keep playing audio after exiting or locking" hides the picture and keeps the sound running, with play, pause and scrubbing available from the system media controls; "Keep playing in a small window after exiting" hands the video to picture-in-picture instead. Both paths share one media session, and the long-running audio task is released as soon as the video pauses or is torn down.
- **Caption background opacity**: the video feed's caption menu now adjusts the caption background opacity and persists it, and the same setting is reachable from Settings. Reopening captions no longer snaps back to the 70% default.

**Translation**

- **Keyless web translation**: translation gained a keyless mode that sends the post text to the translation service's public web endpoint, with no provider, model or API key to configure. The existing API-key mode (OpenAI-compatible and Anthropic protocols with an optional custom base URL) keeps working.
- **Translation entry points**: post cards, the main post on the detail page and comments all offer a translate button that expands its result in place, and the master translation switch survives a cold start instead of having to be turned on again after every launch.

**Network**

- **In-app proxy**: Settings → Proxy stores multiple HTTP and SOCKS5 servers (name, host, port, credentials, bypass list), switches the active server or turns proxying off at any time, and supports latency tests and automatic failover. Every in-app HTTP request goes through the selected proxy, and media downloads and the video cache now stream through it as well.

**Appearance and icons**

- **Classic bird icons**: three bird icons joined the app icon list — Blue bird, White bird on blue and Blue bird on white — for a total of eight alternate icons plus the default (Classic, Spectrum, Outline, Brush, Blossom and the three bird marks).
- **Mid-Autumn limited icon**: from September 25 through September 28 the "Mid-Autumn" icon appears in the icon list as a limited item, and the settings page switches back to the default icon once the window ends.
- **Dark surface**: dark mode gained a "Dark surface" choice between pure black and the gentler dark gray, and the selection is remembered.
- **Press effect**: Settings → Display has a new "Press effect" switch, off by default. Only with it enabled do post cards scale down slightly while held.
- **Show compose button**: Settings → Display has a new switch, on by default, that hides the floating compose button on the main screen when turned off and restores it immediately when turned back on.

**Festival**

- **Mid-Autumn greeting**: for three days starting September 25 the home screen shows one Mid-Autumn greeting card a day, which can be accepted or dismissed. The window is decided by the local date, nothing is shown from September 28 onward, and it works offline.

### Improvements

- **Swipe priority for tabbed pages**: on the home timeline, the Explore page and the search results page, a horizontal swipe now switches tabs first and only changes the main page at the first or last tab. Switching through the bottom navigation is unchanged.
- **Explore categories in real time**: Explore, Trending, News, Sports and Entertainment all render the cards, trends and events exactly as the server returns them, and switching a category, tapping the current category again or pulling to refresh always re-requests them instead of being pinned to a never-expiring local cache.
- **Instant theme switching**: pages, title bars, the drawer, cards and input fields now share one set of surface tokens, so switching between pure black and gentle dark gray repaints the current page immediately without leaving the app or reopening a child page.
- **Support entry in the side drawer**: the drawer gained a permanent "Support Harmony X" entry, and the help centre now lists feedback, community and sponsorship in that order with the sponsorship wording staying voluntary and unobtrusive.

### Fixes

- **Posts rejected as automation (HTTP 200 · 226)**: cookie sessions now generate the `X-Client-Transaction-Id` X expects for writes, restoring in-app posting and media posts instead of relying on a web composer that can hit the same guard. Plain text still prefers the authorized official API; the bundled signing material refreshes from a public mirror with a local fallback.
- **Caption background opacity resetting**: the opacity was not persisted, so closing and reopening captions restored the default; it now returns to the last choice.
- **Translation switch lost**: the master translation switch was not restored on a cold start and now loads with the rest of the preferences.

### Notes

- The in-app proxy applies to the app's own HTTP requests. Whether WebView and the system download component follow it depends on the system version, as the settings page explains. SOCKS5 requires HarmonyOS 7.0 / API 26 or newer; older versions can only use HTTP proxies.
- Keyless web translation depends on the translation service's public web endpoint and may become unavailable because of network conditions, rate limits or server-side changes. API keys are stored only in the local preferences and are never uploaded.
- The Mid-Autumn greeting and the Mid-Autumn icon are both decided by the device's local date and end at midnight on September 28.
- Alternate icons ship inside the installation package and require HarmonyOS 7.0 or newer; switching updates the home screen, app list and recent tasks together.

## 1.3.0 — 2026-09-24

Continuous iteration after the daytime of September 23, grouped by theme.

### New features

**Photo viewing**

- **One-row horizontally scrolling previews**: multi-photo posts no longer stack full-width. Photos sit in a single row, about 228vp tall, with each photo taking roughly 70% of the usable card width (capped at 280vp) so the next one peeks in. Tapping a photo opens the fullscreen viewer at that photo.
- **Reworked fullscreen gestures**: a single tap shows or hides the controls, a double tap zooms in around the touch point, and a pinch zooms freely. When not zoomed, dragging down past a threshold closes the viewer and anything shorter springs back; when zoomed, dragging down pans the photo, with bounds enforced.
- **Bottom action area**: "View original", "Download" and "Download all originals" moved into the bottom safe area, leaving only the close button in the top-left corner. The group follows grip-hand detection and slides between the bottom-left and bottom-right corners.

**Video**

- **Playback cache**: a video that has played once is kept as a complete MP4 in the app's private cache directory, so watching it again reads the local file instead of streaming it from scratch. Only complete files are written, and caching pauses while buffering. HLS streams keep streaming directly as before.
- **Fullscreen rotation follows the device**: physically rotating the phone now rotates only the fullscreen video layer. The app window and the post page keep their own orientation and are no longer rebuilt. The rotation uses an eased angle and canvas transition with `renderGroup` enabled, and in landscape the bottom control bar takes 80% of the screen width.
- **First-frame fallback**: when the first frame times out or the stream fails, the player automatically tries one alternate source and otherwise shows a retryable error.

**Accounts and sign-in**

- **Modal sign-in sheet**: the sign-in entry on the "Me" page and the account management entry now open a bottom modal sheet. Signed-in accounts appear as horizontally swiped cards with their avatar, display name and handle; tapping a card switches the account and syncs the Web login cookie. The last card and the button below both add an account, and a newly signed-in account fetches and caches its avatar.

**App icon**

- **Home-screen icon switching**: Settings → App icon offers five alternate icons (Classic, Spectrum, Outline, Brush, Blossom) plus the default. This uses the alternate-icon support added in HarmonyOS 7.0 (API 26): icons ship inside the installation package, so there is no AppGallery Connect review and no quota. Switching updates the home screen, app list and recent-tasks icons together.
- **Graceful degradation**: below HarmonyOS 7.0 the entry stays visible but disabled with an explanation; a third-party theme that contains this app's icon, and opening the screen in a cloned app, each get their own message.

### Improvements

- **Video aspect ratio**: the home timeline and post details display video at its original aspect ratio instead of stretching or cropping it. The video feed keeps its existing full-bleed treatment.
- **Video tap semantics**: tapping the video surface only shows or hides the progress bar and controls; play and pause now use the dedicated button.
- **Default quality**: fresh installs default to the data-saver video quality, while an existing preference continues to apply.
- **Side bar**: on phones the overlay side bar opens and closes by swipe, and tapping the empty area on the right or using the system back gesture only closes the side bar and keeps the current tab. Tablet behaviour with a docked side bar is unchanged.
- **Comments vs. replies**: direct comments stay at the top level, while second-level replies follow their parent comment with indentation and a "replying to" label. Such a reply still shows when its parent comment has not been loaded yet.
- **Profile pagination**: the Posts, Replies and Media tabs each keep their own cursor, loading and error state, load more on scroll, and de-duplicate by post ID, fixing incomplete profile history. OAuth `userPosts` now returns a paginated result with `nextToken` as well.
- **Reply endpoint fallback**: the reply list prefers the existing V2 operation and retries the older one on a 400/404 or an unparsable response, reporting an accurate error with a retry entry.
- **Explicit manual playback**: with autoplay off, tapping a cover states a clear playback intent, including the path from the home timeline into the video page. The spinner only appears while genuinely preparing or buffering, so a tap no longer produces a fake load that needs a second tap.
- **Picture-in-picture gating**: automatic picture-in-picture now happens only while scrolling a video out of sight below the title bar. Navigating to another child page, going back, hiding the page or unmounting the component cancels the automatic trigger first, so a surface about to be destroyed is never handed to picture-in-picture and no longer shows a black window. The manual button is unaffected.

### Fixes

- **Profile pages from the comment area**: avatars and names in comments are clickable again and open the matching profile.
- **Black picture-in-picture after leaving a child page**: returning to the list no longer pops up an empty window.
- **Drifting photos in fullscreen**: opening the fullscreen viewer no longer makes photos drift, so zooming lands precisely where the reader tapped.
- **Accidental exit from the side bar**: swiping back while the side bar is open no longer quits the app.
- **Incomplete profile timelines**: profile history keeps loading, and the Replies tab is no longer blank because of a 404.
- **Poor-network video**: slow or failing loads now fall back to an alternate source with a retry prompt instead of leaving a black frame.

### Notes

- Alternate icons require HarmonyOS 7.0 or newer and ship with the app version, so unlike AGC dynamic icons they cannot be hot-updated.
- The playback cache only applies once a complete MP4 has been fetched; HLS streams are not cached locally.
- Icon assets live in `AppScope/resources/base/media/` and their names must match `alternateIcons` in `app.json5`.

## 1.2.0 — 2026-09-23

Continuous iteration after the daytime of September 22, grouped by theme.

### New features

**Explore and search**

- **Explore page**: the second bottom tab is now "Explore", alongside "Trending / News / Sports / Entertainment". Trending columns list concrete items, promoted content carries a "Promoted" label, and an unavailable column, a failed load and a genuinely empty column each get their own message.
- **Search history and suggestions**: the search page lists recent searches with one-tap clearing, and shows search suggestions filtered by the current keyword; tapping one starts the search immediately.
- **Search filters**: filter by "From (anyone / people you follow)", a publication date, language, and post activity (high engagement), and optionally exclude replies. Once applied, the title bar shows "Filtered" and the filters can be reset at any time.
- **Search result categories**: results are grouped into Top / Latest / People / Media / Lists.

**Reading**

- **Reading filters**: Settings → Content preferences → Reading filters can show media posts only, hide reposts and hide replies, and maintains blocked keywords and muted users line by line. The rules only affect what this device shows; they never unfollow, block or change the X account settings.
- **Long-form posts**: the X long-form structure (note_tweet) is parsed, and an over-long body is folded by line count with "Show more / Show less" for full reading.

**Video**

- **Video feed player**: entering a video from a post opens a dedicated vertical feed; the more menu offers captions, quality, autoplay-next, adding to offline videos, going to the post and reporting.
- **AI captions**: the playback bar gained an AI captions switch backed by the system SpeechKit AI caption component, overlaying live captions on the picture.
- **Immersive full video**: a new switch fits the video to the full screen in its complete ratio, fills the uncovered area with a blurred cover background and raises the playback bar; when off, the original rounded full-bleed container is kept.

**Notifications**

- **System notifications and badge**: a new alert publishes a HarmonyOS notification and syncs the home-screen badge number. It can be disabled on its own in Settings; the in-app dot and the notification page still stay populated.
- **Silent in Do Not Disturb**: while the system is in Do Not Disturb, only the in-app dot is updated and no system notification is posted.
- **System notification settings entry**: Settings can jump straight to HarmonyOS notification management to adjust banners, lock screen, ringtone and vibration, with a clear message when the permission is missing.

**Accounts and profiles**

- **Delete posts**: the more menu on a post detail page can delete your own posts, with confirmation and a failure message.
- **Block accounts**: profiles and account rows can block and unblock accounts, and explain what blocking does.
- **Edit profile**: name and bio can be edited and saved to X.
- **Profile tabs**: the Posts / Replies / Media tabs are complete, each with its own empty state.

**HarmonyOS integration**

- **Open links in the app**: tapping an x.com / twitter.com link in another app lists Harmony X in the system "Open with" dialog. Post, profile and search links route to the matching page, while other links still go to the web view.
- **Handling system shares**: sharing an x.com link from the system share sheet delivers it straight to the app; the sheet closes immediately and the main UI takes over.
- **Background reading aloud**: reading aloud gained the audioPlayback background mode and the background-running permission, so playback continues after leaving the reader page.

**Appearance and language**

- **Italian**: Italiano joins Chinese, English and Follow system as an interface language.
- **Search inside Settings**: the Settings home page can be searched by keyword, with an empty state when nothing matches.

### Improvements

- **Unified account rows**: following, follower and blocked lists share one account-row card with the "People" search results, and blocked accounts can be unblocked from the row itself.
- **Post expand transition**: the post-to-detail transition is now driven by the detail page with the list row following, keeping a single node throughout so two elements no longer fly apart.
- **Reply area on details**: the reply composer floats above the reply list and fades in instead of reflowing the whole page.
- **Write failure messages**: X wraps GraphQL errors in HTTP 200 responses. The app now distinguishes an expired session, account-level posting rate limits and direct rejections in the response body and shows the matching wording instead of always reporting "Cannot reach X".
- **Closing details on wide screens**: the timeline is synced only when a detail page was really opened, so the shared-element animation is no longer interrupted on the way back.

### Fixes

- **Dead text taps**: tappable regions inside the body used to swallow gestures, so tapping plain text did nothing; tapping the body now opens the post too, while mentions, hashtags and links still take priority.
- **Search results covering Explore**: search became its own results page, so the "Explore" tab is no longer replaced by an old search result list.
- **Wrong filter display**: reopening the search filters restores the conditions actually in effect, so a discarded edit no longer looks applied.

### Notes

- "Report post" in the video feed hands the link back to X; the app keeps no report record.
- Reading filters and search filters only affect this device; switching accounts or devices does not sync them.

## 1.1.0 — 2026-09-22

Continuous iteration after midday of September 21, grouped by theme.

### New features

**Accounts and sign-in**

- **Multi-account sign-in and management**: Settings gained a "Your accounts" page for adding, switching and removing accounts. Each account keeps its own cookie session and optional OAuth token, and switching refreshes the data client automatically, so repeated sign-ins are no longer needed.

**Reading and media**

- **Photo viewer**: several photos from the same post can be viewed fullscreen with left/right swiping; zooming in hands the swipe gesture over. Opening and closing uses a shared-element "one-take" transition that scales up from the thumbnail and returns to it.
- **Image and video quality**: Settings → Images and video offers data saver / high / original for images and data saver / high for video. Changes take effect and persist immediately, and downloads follow the same setting.
- **Media download**: photos and videos from the timeline and detail pages can be downloaded into the system gallery (with a one-off system authorization); multi-photo posts offer "All originals" batch downloading.
- **Picture-in-picture**: a video on a detail page moves into the system picture-in-picture window once scrolled off-screen, so comments can be read alongside it; it can be turned off in Settings. Inline videos can also enter picture-in-picture manually, the window gained ±10 second controls, and rotating the screen no longer loses playback.
- **Video fullscreen**: playback now follows the video's original ratio with black bars instead of stretching and cropping, and supports portrait and landscape.
- **Fullscreen control bar**: became a single row of immersive material raised to the height of the bottom tab bar, animating away once playback starts and coming back on a pause tap.
- **Read posts aloud**: the system reading capability (SpeechKit TextReader) is wired in through a reader page with a queue, previous/next, pause and stop. Lists, details, bookmarks and profiles reuse a floating button to enter it, and reading continues after leaving the page.

**Social features**

- **Direct messages**: a conversation list and a conversation detail page with unread markers, group chats, pull-to-refresh and back navigation. End-to-end encrypted conversations are marked read-only in the UI with an explanation.
- **Following and follower lists**: the counts on the Me page and in the side bar open real lists with pagination, pull-to-refresh, profile navigation and follow actions.
- **Bookmarks page**: real bookmarks can be viewed; timeline cards can be bookmarked and unbookmarked, and cards removed in the bookmarks page disappear immediately.
- **Placeholder entries wired up**: the Me list, list timelines, blocked list, diagnostics and help centre all open real pages instead of unresponsive placeholders.
- **Quoted post cards**: the quoted author, verification state, body, time and media thumbnails are parsed and shown (videos show a play badge and do not autoplay in lists), and tapping opens the quoted post.
- **Working post actions**: likes, reposts and bookmarks use the private endpoints with API fallback, write state and counts back into the post model consistently across pages, and roll back with a message on failure.
- **Action feedback**: reposts turn green, hearts fill red, bookmarks fill blue, and taps give haptic feedback and an in-progress state.
- **System sharing**: posts can be shared as a link and body text through the system share sheet.

**Composing**

- **Drafts**: post drafts and per-post reply drafts are saved and restored automatically and cleared after a successful post.
- **Composer**: up to four images (de-duplicated, previewed, individually removable), images and GIFs mutually exclusive, media-only posts, plus a 280-character counter that disables sending when exceeded.

**HarmonyOS features and appearance**

- **Immersive material**: the floating compose / read-aloud buttons, the new-posts pill, the photo download and close buttons, and the profile back / search / more / follow buttons all use system immersive material through a "plain material plate with an outer click target" approach, so the material no longer shows touch glow or deformation.
- **Bottom tab material levels**: exquisite / gentle / smooth / adaptive, applied immediately after switching.
- **Two font-size modes**: follow the system (capped at 1.75x, showing the current system multiplier) or adjust inside the app (0.85x–1.75x slider). The modes are mutually exclusive and persisted, and switching back to follow-system offers "Restart now".
- **New display switches**: auto-hide the top title bar, auto-hide the bottom navigation (hidden by scroll direction, restored immediately on reverse scroll), and keep the compose button always visible or hide it on scroll.
- **Wide-screen masonry**: the home, search, notifications and profile pages can choose auto / one / two / three columns on wide screens, while narrow screens always stay single-column.
- **Two-column post details**: the post and its actions on the left, replies on the right; the floating reply pill narrows to 80% of portrait width and only subscribes to grip-hand detection on wide screens.
- **New-posts pill**: pulling to posts that have not been shown yet offers a pill with avatars; tapping scrolls smoothly to the top and inserts them without losing the reading position.
- **Offline use**: the home timeline is cached so a cold start with no network shows the previous content, with network monitoring and an offline notice that refreshes once the network returns.
- **High-resolution avatars and banners**: avatars and profile banners moved to high-resolution sizes (banners 1500×500); the profile card prefers the high-resolution banner and otherwise derives a background from the avatar colours.
- **Icons and colouring**: the launch icon is rounded, and text and icons on the brand colour returned to white, including the new-posts pill.
- **Persisted preferences**: default home timeline (For you / Following), video autoplay, opening links in the app, notification switches and more.

**UI cleanup**

- Removed the "X API v2" wording from the UI and the "Connected to the X private API" status line from the home page.
- Settings no longer shows the three technical entries for the backend gateway, the developer API and the private-API session.
- Post card display names, handles and times are left-aligned right next to the avatar.
- Card spacing was unified on the OpenHarmony UI 4vp grid.

### Fixes

- **Bookmarks and list subpages**: title-bar text was hard to read in light mode.
- **List loading HTTP 400**: the old REST direct-message endpoint is offline, so XChat private endpoints are used instead.
- **Wrong following list title**: the page opened from "Following" showed "Followers".
- **Sign-in lost in the multi-account dialog**: a new cookie bridge syncs the current account session back into ArkWeb when switching, removing or adding accounts, previewing links and cold starting.
- **Picture-in-picture window**: only pause existed without ±10 second controls, and the video disappeared after rotating.
- **Picture-in-picture failing from home videos**.
- **Oversized "All originals" button**: it covered the download progress.

### Notes

- Write operations such as reposts are limited by X server side (they have returned 404 and write rate limits); failures roll the state back with a clear message instead of pretending to succeed.
- Encrypted direct messages are read-only for now; sending needs the XChat key exchange.
- Grok automatic post reactions were only assessed for feasibility and are not implemented.
- This round also produced the "HarmonyX app feedback collection form" under `outputs/harmonyx_feedback_form_20260921/`.

## 1.1.0 early iterations (private API layer, signing in with an X account, video fixes)

### New

- **Private API layer**: an operation table of 396 GraphQL operations extracted from a reference client is built in, so signing in to x.com reads the real home timeline, following timeline, search, notifications, profiles and user timelines, and supports posting, replying, media uploads, likes and reposts.
- **Sign in with an X account**: the sign-in page gained a primary path that completes x.com sign-in inside the in-app Web component and extracts the cookie session, without applying for a developer app. The original OAuth 2.0 PKCE path remains optional.
- **AI translation**: 12 model providers are supported with your own API key, translating a post from its card in one tap.
- **Optional backend gateway**: the `server/` directory provides a self-hosted harmonyx-gateway that keeps the X session and the private API server-side for several devices to share.

### Fixes

- **No more black video**: the player now sits under the post cover and is only revealed once a real frame is decoded; slow buffering or a failed playback keeps the cover with a spinner and a tappable retry.
- **Video covers in search results**: the search endpoint puts covers under `media_info.preview_image`, which was not parsed before, so videos in search results had neither a cover nor anything but a black box; the image is now read from that structure, keeping the first-frame fallback.
- **Faster video start**: cards use the lowest available bitrate rendition (fullscreen still uses the best quality), so entering a list no longer immediately pulls a 720p stream.
- **Several videos can play on one page**: previously only one video in the whole list pulled a stream, and any cell scrolling into view reset the playing one back to its cover, so the video you wanted stopped and reloaded from the start; two cells stuck at the start threshold also fought each other and neither played. Every video entering the viewport now pulls its own stream without disturbing the others.
- **Invisible follow button in dark mode**: the follow button on a post detail page was filled with `text_primary`, which is nearly white in dark mode, while the label stayed white, so white-on-white made the text disappear. A `text_on_inverse` colour resource (light `#FFFFFF` / dark `#0F1419`) was added to follow the fill colour and keep contrast in both modes. The same colouring problem on the attachment-removal cross in the reply composer was fixed as well.

### Improvements

- Settings no longer shows the backend gateway, developer API and private-API session entries; the account page only keeps account management.
- Video preloading: a card starts resolving the cover of neighbouring videos at 5% visibility and starts buffering playback at 35%, so playback usually starts the moment it scrolls into place.
- Videos playing at the same time each take a bitrate and a decoder (roughly 500 kbps and up inline) and are released when they leave the viewport (below 5% visible).

### Notes

- The private API path violates the X terms of service and risks rate limits or suspension.
- Direct messages depend on the XChat end-to-end encryption protocol and are not supported yet.
- `X-Client-Transaction-Id` computation is not implemented; it will be needed if X starts enforcing validation.

## 1.0.0 — 2026-09-13

First official release, adding the following on top of yesterday's base project and identity rework:

### New

- Post detail page: read a single post with its media, statistics and replies, and reply from the detail page.
- An extensible reply composer supporting text, photo and GIF attachments that keeps local content when posting is not possible.
- Profile and user detail pages, with entry from post authors to their profile and post list.
- Settings centre: configure the X OAuth 2.0 client ID on the device, switch between Chinese and English, follow the system / light / dark theme, and adjust font size and accent colour.
- Side bar and help centre with entries for profile, bookmarks and more, plus feedback, the QQ group and a page for supporting the author.
- Media post cards and more complete local sample data.
- Home "For you / Following" switching, continue-loading hints for timelines and search, and live state feedback for posts, mentions and direct messages.
- A responsive content area for phones, tablets and 2-in-1 devices, supporting fullscreen, split screen and floating windows.

### Improvements

- OAuth configuration moved into the app settings, so no source edit or rebuild is needed; PKCE is still used and a client secret is never required.
- Better X API v2 calls, error states and offline degradation.
- Updated app icon and brand assets, light and dark theme colours, and Chinese and English copy.
- Grip-hand state is kept across windows and pages and keeps avoiding the system safe areas.

### Release artifacts

- The GitHub release ships `HarmonyX-v1.0.0-unsigned.hap`, an unsigned HAP for review, re-signing or self-installation only; sign it with your own HarmonyOS certificate and profile before installing.
