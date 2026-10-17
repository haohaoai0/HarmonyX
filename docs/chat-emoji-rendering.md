# Chat emoji rendering

The chat picker contains the Unicode 17 RGI set. Chat emoji are standard Unicode
characters, including ZWJ, skin-tone, flag and keycap sequences. The system font
may not contain every glyph, so `ChatEmojiText` uses bundled Twemoji SVG graphics
in native ArkUI `ImageSpan` components. It covers message text, reply and pin
previews, reaction badges, quick reactions and the full emoji picker.

The same `EmojiSpans` builder also serves posts, comments and replies:

| Display | Integration |
| --- | --- |
| Home, search, bookmarks, lists, communities and profile posts | `TweetCard` |
| Comments, replies, parent chains and composer original-post previews | `TweetCard` / `ConversationTweetCard` |
| Detail body and translated text | `PostDetail` |
| Quoted post | `QuotedPostCard` |
| Video captions in portrait and landscape | `VideoFeedViewer` |
| Profile video rows and biography | `UserDetail` |
| Notification post previews | `Index` |
| Read-aloud post and quote previews | `ReadAloud` |
| Post share-card preview and article preview | `PostDetail` / `TweetCard` |
| Poll options, website/rich-card titles and descriptions | `PostPollCard` / `PostRichCard` |
| Article preview, title, formatted runs and plain body | `PostArticleCard` / `PostArticle` |
| Community note preview and detail; Space card title and host | `PostPresentationCard` / `CommunityNoteDetailSheet` / `SpacePostCard` |

Existing Text sizing, fonts, line limits and entity callbacks are retained.
`EmojiCopyMenu` maps native selection positions (one per image span) back to the
original Unicode, so copying posts does not substitute image data for emoji.

Settings → Display → Use system emoji switches the shared renderer to native
Unicode text spans. It is off by default, persists with appearance preferences,
and updates existing post/chat surfaces through AppStorage bindings. Image-span
selection positions map to whole Unicode emoji when off; native selections use
UTF-16 text positions when on. Emoji availability in system mode follows the
device's font coverage. Turning it off restores the bundled graphics.

The API parser also converts `display_text_range` code-point positions before
slicing ArkTS strings. Slicing those positions directly as UTF-16 units can
turn a final 🫠 into a lone high surrogate, matching the damaged terminal
character observed in a live phone post and reproduced in the regression test. This is
independent of the selected renderer. X's reference library documents
[code-point display ranges](https://github.com/twitter/twitter-text/blob/master/objc/README.md#api).

Text, encryption, searching and copying retain the original Unicode string.
Longest-sequence matching keeps compound emoji together, including every subset
of omitted VS16 selectors in ZWJ sequences. The display manifest includes all
4,009 upstream graphics: isolated skin-tone/hair components, regional indicators
and upstream compatibility sequences are available beyond the 3,944-entry picker.
All 5,225 forms in Unicode 17's unmodified `emoji-test.txt` are regression-tested.
The fixture is in `tests/fixtures/emoji-test-17.txt` and uses the bundled Unicode
license. VS15 requests text
presentation and stays text. Unknown text and literal question marks stay text;
already-corrupted input cannot be recovered by changing its display.

One to three emoji without other text use the enlarged message appearance,
including BMP hearts and long family sequences.

## Reference implementation checked on 2026-10-10

The local `D:/apk-re/chuckle/chuckle-1.1.1-154.apk` uses
`TweetTextView extends ug0` (AppCompat TextView). Its helper `rf0` enables
EmojiCompat by default and attaches an emoji input filter. The manifest registers
`androidx.emoji2.text.EmojiCompatInitializer`; `c96` locates a system emoji-font
provider through `androidx.content.action.LOAD_EMOJI_FONT` with the request
`emojicompat-emoji-font`. `zsq` draws replacement spans with that font. This is
Android font fallback, not a bundled Twemoji collection for post bodies.

The captured X web main bundle `main.fb59cf3316c2d48ea.js` was fetched again from
the official CDN. Module `465991` selects SVG by default and sets
`https://abs.twimg.com/emoji/v2` as the graphic base; parser module `407427` in
the vendor bundle retains UTF-16 indices and original emoji text. The renderer
uses inline images with aria-label/text, sized at 1.2em with 0.075em side margins
and -20% vertical alignment. Native emoji are initially disabled in this bundle.
This is evidence for that captured responsive-web build; the current logged-out
homepage serves a separate x-web entry and was not used to claim signed-in
runtime behavior. Harmony X uses native ArkUI ImageSpan and local licensed
graphics to keep display independent of both system glyph coverage and network.

## Validation

The 58 emoji/appearance/display-range/poll/rich-card/website-card checks pass. This includes
all 5,225 Unicode fixture forms, unmodified SVG hashes, native mode without
graphic loading, persistence, all 21 locales, and selection mapping in both
rendering modes.

On 2026-10-10, a temporary device page rendered the real TweetCard and
PostArticleCard on MatePad Pro. Partially qualified ZWJ, flags, keycaps,
isolated skin/hair components and Unicode 16/17 examples displayed correctly.
The @mention callback passed; native Copy → Paste preserved the exact
`ab👁️‍🗨 cd🏽` string. The temporary route/page was removed and the prior startup
files restored byte-for-byte. This checks the renderer with known samples;
the originally reported post has not been supplied for direct reproduction.

On 2026-10-11, the system-emoji preference build installed and launched on
Mate 80 Pro Max. A subsequent build adds the display-range fix and passes
ArkTS compilation. Its final installation is pending because USB disconnected;
native toggle persistence and the repaired live post still need that device check.

## Graphics attribution

Twemoji v17.0.3, Copyright Twitter, Inc. and other contributors.
Source: <https://github.com/jdecked/twemoji/releases/tag/v17.0.3>.
Unmodified graphics are licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The full license and attribution ship in `chat-twemoji-LICENSE.txt` and are copied
to `docs/licenses/twemoji-CC-BY-4.0.txt`. The generated file manifest is specific
to Harmony X. File hashes are in `docs/chat-twemoji-assets.json`.

To reproduce, extract the upstream v17.0.3 source archive, then run:

```powershell
node tools/bundle-chat-twemoji.cjs <extracted-source-directory>
```
