# Page backgrounds

Open **Settings → Display → Page background**. Changes remain a local draft until
**Apply** is pressed. **Restore defaults**, followed by **Apply**, returns to the
normal theme. Leaving without applying discards the draft and removes imported
draft photos. The preference is application-wide and survives account changes.

The **Enable page background** switch at the top applies immediately and does
not discard the saved style. Turning it off restores the normal theme canvas,
post and conversation surfaces, and contrast treatment together. Turning it on
again restores the last applied wallpaper and its individual settings. Unlike
the switch, edits elsewhere on the page remain a draft until **Apply**.

The compositing order is:

1. Theme surface, selected solid color, or a durable copy of a selected photo.
2. Optional kraft or parchment grain and fibers, with adjustable strength.
3. Full pattern collections, or independently selected individual motifs.
4. Optional dimming; content cards have independently adjustable opacity.

**Transparent post cards** and **Transparent message list** are separate switches.
They remove the actual post/quoted-post or conversation-row surfaces rather than
changing text opacity. Turning either off restores its normal surface and the
configured opacity. The selected conversation retains an outline.

Full-pattern mode supports multiple collections at once. Individual-motif mode
offers 148 motifs across 21 collections: the existing 17 collections, plus 12
alternate-icon motifs, 12 Plants vs. Zombies motifs, 12 AI assistant motifs, and 16 phone brand/system motifs. The generated artwork
and exact prompts are documented in [the artwork notes](page-background-artwork/README.md). Selecting an
entire motif set adds its extracted motifs to the selection; switching the
collection preserves selections from other collections. Density changes spacing
without changing icon size. Placement is deterministic across redraws and
scrolling, and the node count is bounded for large windows.

Kraft and parchment supply theme-aware paper colors when the base follows the
theme. Selected colors and photos can retain their own base underneath the same
paper texture. Pattern ink follows the luminance of solid and paper bases.

Ordinary native pages own their background layers so navigation cannot expose
the previous page through a transparent surface. Sheets, dialogs, controls and
fields retain their existing themed surfaces. Chat wallpapers remain separately
configured. Fullscreen photo/video viewers keep their immersive backgrounds.

Text contrast follows the composited wallpaper and each actual card surface,
including post/inbox opacity and avatar tints. Image tone sampling ignores
transparent pixels and retains bright/dark extremes. A minimal readability veil
protects text over mixed photographs and dense patterns; middle-opacity panels
can receive a slight tint while preserving the exact requested alpha. Primary
and secondary text retain their original colors whenever contrast permits.
Native title bars retain a themed reading surface and matching navigation ink.
Post action icons and their counters use the same policy in both selected and
unselected states, preserving the like/repost/accent hue whenever contrast
allows. The overflow button receives its foreground from its actual post host.
Inline playback controls also receive the host card surface, including avatar
tints. Playback icons, timestamps, selected progress, unfilled track and thumb
all adapt; unfilled tracks retain a distinct, softer contrast. Immersive player
capsules and their sliders participate in native material foreground inversion
on API 26. Chat playback retains its separately owned background context.

The title-bar **+** imports `.hxb` / JSON background schemes into the local draft.
The share button exports that draft through the native system share sheet.
Version-1 `harmonyx.page-background` documents contain all background settings
and an embedded base64 photo when used. They never import device-local paths or
remote image references. Imported photos go through the same sandbox-copy and
image-decode checks as picked photos. Apply remains an explicit separate step.
Scheme input is limited to 48 MiB; embedded photos are limited to 32 MiB.
Shared cache files remain available to receiving applications for seven days,
and old exports are cleaned up on a subsequent share.

Photos are decoded for validation and copied to `filesDir/page_backgrounds`.
Preference writes finish before UI publication or deletion of the previous
photo. Cleanup only removes owned files and protects the currently saved photo.

The original 96 motifs derive from the existing wallpaper assets; see
[chat-background-attribution.md](chat-background-attribution.md) and the crop
manifest [page-background-motifs.json](page-background-motifs.json). The 52 new
signature, Plants vs. Zombies, AI assistant and phone brand/system motifs are generated artwork; see the
[source atlases and prompts](page-background-artwork/README.md). Paper textures
are generated deterministically by `tools/Create-PagePaperTextures.cjs`. The
optional asset-generation tools require `sharp`; no app dependency is added.

Focused regression checks:

```text
node --test tests/page-background.test.cjs tests/chat-background.test.cjs tests/theme-palette.test.cjs tests/desktop-layout.test.cjs
devecocli build --modules entry
```
