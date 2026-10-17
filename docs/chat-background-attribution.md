The chat background selector, local-photo import and shared wallpaper renderer
adapt the page structure and rendering approach from
[Petrelgram](https://github.com/miramira8295/Petrelgram), licensed under
[Apache License 2.0](../LICENSE).

Source files: `pages/main/ChatBackgroundPage.ets`,
`pages/main/WallpaperPreview.ets` and `pages/chat/PatternTileLayer.ets` in the
local Petrelgram reference checkout.

Harmony X modifications: HdsNavDestination navigation and title bar, Harmony X
theme resources and message preview, bundled original pattern presets, an explicit
Apply action, account/conversation-scoped local persistence, cancellable image
imports with image validation, and cleanup of replaced or unapplied photos.
Telegram/TDLib background fetching and server-side updates are replaced by
local Harmony X preferences.

The 17 bundled SVG artworks are original Telegram wallpaper patterns from the
same collection used by Petrelgram. Two were copied directly from Petrelgram's
installed wallpaper cache on the user's device:
`pattern.tgv.svg` (warm doodles) and `pattern_(0).tgv.svg` (dream doodles).
Light-mode SVG artwork is byte-for-byte unchanged. Dark-mode copies change
black strokes/fills to white; shapes are unchanged. Light-mode four-stop fills
and the 50% pattern intensity match Petrelgram's saved wallpaper snapshots.
Dark-mode fills are adapted for Harmony X's dark appearance.

The remaining 15 are retrieved from the public
[Telegram Web K wallpaper collection mirror](https://github.com/GSUBx019/migram-web/tree/main/frontend/public/patterns/k).
The mirror's `k-wp-12.svg` and `k-wp-13.svg` have exactly the same SVG paths
as the two device files (the file text is also identical after whitespace
normalization), confirming that these belong to the same artwork collection.
SVG paths are preserved for all imported patterns. The 3 JPEG entries in the
mirror are photo wallpapers and are omitted from this pattern gallery.
Pattern aspect ratios are derived from each original SVG viewBox; square
gallery thumbnails are pre-rendered separately to avoid decoding all SVGs
when the selector scrolls.

Original sources, dimensions, light-mode palettes and SHA-256 hashes are
recorded in [chat-background-assets.json](chat-background-assets.json).

Pattern artwork is supplied by Telegram's wallpaper service, separately from
Petrelgram's Apache-2.0 application code; this file does not relicense it.
See [Telegram's wallpaper specification](https://core.telegram.org/api/wallpapers).
