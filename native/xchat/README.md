# Harmony X native XChat adapter

ArkUI renders the conversation. The on-device ARM64 NAPI library embeds X's
official Chat XDK 0.5.0 and Juicebox SDK; it does not load the X website.
The adapter preserves the upstream signature verification, bounded wire parser,
conversation-key downgrade checks and PIN recovery. Private and conversation
keys remain in the native SDK for the active account and are cleared on account
switch/sign-out. The PIN is used for one recovery attempt and is not persisted.

The prebuilt `entry/libs/arm64-v8a/libharmonyx_chat.so` targets HarmonyOS ARM64.
Rebuild from pinned sources with Rust's `aarch64-unknown-linux-ohos` target and
the DevEco native SDK:

```powershell
./native/xchat/build.ps1 -DownloadProxy http://127.0.0.1:7890
devecocli build --modules entry
```

Omit `DownloadProxy` when direct downloads work. Sources are downloaded into
`.codex/dm-reference`; `Cargo.lock` pins registry dependencies. The script checks
each dependency commit and uses the SDK's pinned Thrift revision.

For an incremental rebuild that keeps the current dependency checkouts and
local patches, use `./native/xchat/build-local.ps1`. It only compiles the Rust
library and links/strips the ARM64 NAPI library.

Group bridge methods accept a JSON object and return the usual
`{ ok, data, error }` envelope:

- `encryptMetadata`: `{ conversation_id, text }` returns
  `{ ciphertext, key_version }`. This uses XSalsa20-Poly1305 with a fresh nonce
  and the latest retained key; it is distinct from local nickname encryption.
- `decryptMetadata`: `{ conversation_id, ciphertext }` returns
  `{ text, key_version }`, authenticating against retained keys.
- `decryptMetadataFile`: `{ conversation_id, input_path, output_path,
  key_version? }` returns `{ key_version, media_bytes, media_path }`. Downloaded
  group-avatar files use the attachment SecretStream format, not UTF-8 metadata
  encryption. The key-version hint is tried first, then historical keys. The
  output file is written only after successful authentication.
- `prepareGroupMembers`: `{ conversation_id, public_keys, new_member_ids,
  current_member_ids, current_admin_ids, current_pending_member_ids?,
  current_title?, current_avatar_url?, current_ttl_msec?,
  current_screen_capture_blocking_enabled? }` returns a prepared **member-add**
  change, with two action signatures and encrypted participant keys. Optional
  snapshot fields are passed to the XDK without interpretation or encryption.
- `prepareKeyRotation`: `{ conversation_id, public_keys }` returns a key-change
  preparation for the supplied group, with one action signature.

Each `public_keys` item is `{ user_id, public_key, key_version }`. Prepared
changes return `{ conversation_id, conversation_key_version, participant_keys,
action_signatures }`; raw conversation keys never cross NAPI. Prepared keys
are not activated before server acceptance. Refresh and decrypt the server's
acknowledged key-change events after submitting an accepted mutation.

`patches/media-message-id.patch` adds an optional stable message ID to the
SDK's message-encryption parameters and corresponding language bindings.
The build applies it to the pinned source. Attachment initialization,
finalization and the signed message use that same ID; uncertain delivery
retries preserve the original ciphertext and ID. Signature verification and
SecretStream framing remain upstream implementations.

Chat transport uses the account's existing cookie session and registered
GraphQL operations (`GetPublicKeys`, `GetConversationPageQuery`, and
`SendMessageCreateMutation`). Existing registered keys are recovered using the
user's current X Chat PIN; no registration, PIN reset or key replacement is
performed. A send is confirmed only by the returned server event.
Recovery uses the official Juicebox protocol over a native HTTP transport with
the application's explicit proxy setting. Its diagnostics report only host,
HTTP status and connection errors; request headers and bodies are excluded.

The media transport uses private GraphQL initialization/finalization and raw
encrypted TON parts with the existing cookie session. It accepts empty 2xx
part acknowledgments and confirms delivery through the returned signed event.
The native tests cover authenticated media round trips and rejection of a
changed signed message ID. Device delivery still requires a real server check.

Upstream sources and licenses:

- Chat XDK (MIT): https://github.com/xdevplatform/chat-xdk
- Juicebox SDK (MIT): https://github.com/juicebox-systems/juicebox-sdk
- Apache Thrift (Apache-2.0): https://github.com/apache/thrift

See `THIRD_PARTY_NOTICES.md` for the bundled notices.
