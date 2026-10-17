use chat_xdk_core::{Chat, ChatCore, EncryptMessageParams, EncryptReplyParams, EncryptReactionParams, Event, SigningKeyEntry, PublicKeyInput,
    ConversationKeyChangeParams, GroupCreateParams, GroupMembersChangeParams, MessageDeleteParams, AttachmentDescriptor,
    GroupActionParams, PreparedConversationChange, GroupActionPermissions};
use chat_xdk_core::keys::juicebox::JuiceboxConfig;
use serde::Deserialize;
use serde_json::{json, Value};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use zeroize::Zeroizing;
use std::sync::Arc;
use std::collections::HashMap;
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use chat_xdk_core::crypto::keys::XChatConversationKey;
use p256::pkcs8::{DecodePublicKey, EncodePublicKey};
mod recovery;

pub struct Session {
    chat: Chat,
    runtime: tokio::runtime::Runtime,
    recovery: Arc<recovery::Recovery>,
    media_keys: HashMap<String, HashMap<String, XChatConversationKey>>,
    raw_key_events: HashMap<String, HashMap<String, String>>,
    raw_edits: HashMap<String, (String, String)>,
    pending_rotations: HashMap<String, PreparedConversationChange>,
}

#[derive(Deserialize)]
struct UnlockArgs {
    pin: String,
    config: Value,
    user_id: String,
    version: String,
    public_key: String,
    #[serde(default)]
    proxy: String,
}

#[derive(Deserialize)]
struct DecryptArgs {
    events: Vec<String>,
    signing_keys: Vec<SigningKeyEntry>,
}

#[derive(Deserialize)]
struct EncryptArgs {
    conversation_id: String,
    text: String,
    #[serde(default)] message_id: Option<String>,
    #[serde(default)] attachments: Vec<AttachmentDescriptor>,
    #[serde(default)] media_key_version: String,
    #[serde(default)] ttl_msec: Option<i64>,
    #[serde(default)] reply: Option<ReplyArgs>,
}

#[derive(Deserialize)]
struct ReplyArgs {
    sequence_id: String,
    sender_id: String,
    text: String,
    #[serde(default)] raw_event: String,
    #[serde(default)] key_version: String,
}

#[derive(Deserialize)]
struct ReactionArgs { conversation_id: String, sequence_id: String, emoji: String, remove: bool }

#[derive(Deserialize)]
struct CreateArgs {
    public_keys: Vec<PublicKeyInput>,
    #[serde(default)] conversation_id: String,
    #[serde(default)] members: Vec<String>,
    #[serde(default)] admins: Vec<String>,
    #[serde(default)] title: String,
    #[serde(default)] for_key_rotation: bool,
}

#[derive(Deserialize)]
struct GroupMembersArgs {
    conversation_id: String,
    public_keys: Vec<PublicKeyInput>,
    new_member_ids: Vec<String>,
    current_member_ids: Vec<String>,
    current_admin_ids: Vec<String>,
    #[serde(default)] current_pending_member_ids: Vec<String>,
    #[serde(default)] current_title: Option<String>,
    #[serde(default)] current_avatar_url: Option<String>,
    #[serde(default)] current_ttl_msec: Option<i64>,
    #[serde(default)] current_screen_capture_blocking_enabled: Option<bool>,
    #[serde(default)] current_description: Option<String>,
    #[serde(default)] current_invite_url: Option<String>,
    #[serde(default)] current_invite_expires_msec: Option<i64>,
    #[serde(default)] current_invite_affiliate_id: Option<String>,
    #[serde(default)] current_admin_settings: Option<GroupActionPermissions>,
    #[serde(default)] key_version: String,
}

#[derive(Deserialize)]
struct DeleteArgs { conversation_id: String, sequence_ids: Vec<String>, delete_for_all: bool }
#[derive(Deserialize)]
struct ConversationArgs { conversation_id: String, #[serde(default)] sequence_id: String }

#[derive(Deserialize)]
struct PinChangeArgs { old_pin: String, new_pin: String }
#[derive(Deserialize)]
struct LocalArgs { conversation_id: String, #[serde(default)] text: String,
    #[serde(default)] key_version: String, #[serde(default)] ciphertext: String }
#[derive(Deserialize)]
struct MediaArgs { conversation_id: String, input_path: String, output_path: String,
    #[serde(default)] key_version: String }
#[derive(Deserialize)]
struct RecoveryArgs { config: Value, proxy: String }
#[derive(Deserialize)]
struct FingerprintArgs { #[serde(default)] public_key: String, #[serde(default)] signing_key: String,
    #[serde(default)] binding: String }

impl Session {
    fn new() -> Result<Self, String> {
        let recovery = Arc::new(recovery::Recovery::default());
        let chat = Chat::with_juicebox(JuiceboxConfig::from_json("{}".into()), recovery.clone());
        chat.set_cache_keys(true);
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2).enable_all().build().map_err(|e| e.to_string())?;
        Ok(Self { chat, runtime, recovery, media_keys: HashMap::new(), raw_key_events: HashMap::new(), raw_edits: HashMap::new(),
            pending_rotations: HashMap::new() })
    }

    fn call(&mut self, method: &str, input: &str) -> Result<Value, String> {
        match method {
            "recoveryConfig" => {
                let a: RecoveryArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                self.recovery.configure(a.proxy);
                self.chat.update_config(JuiceboxConfig::from_x_api_json(&a.config.to_string())?);
                Ok(json!({"configured": true}))
            }
            "unlock" => {
                let mut a: UnlockArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                let pin = Zeroizing::new(std::mem::take(&mut a.pin));
                self.recovery.configure(a.proxy);
                let config = JuiceboxConfig::from_x_api_json(&a.config.to_string())?;
                self.chat.update_config(config);
                self.runtime.block_on(self.chat.unlock(pin.as_bytes())).map_err(|e| e.to_string())?;
                if !self.chat.matches_registered_key(&a.public_key).map_err(|e| e.to_string())? {
                    self.chat.lock();
                    return Err("registered_key_mismatch".into());
                }
                self.chat.set_identity(a.user_id, a.version);
                Ok(json!({"unlocked": true}))
            }
            "decrypt" => {
                let a: DecryptArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                let events: Vec<&str> = a.events.iter().map(String::as_str).collect();
                let mut result = self.chat.decrypt_events(&events, &a.signing_keys);
                // Classic DMs have plaintext Thrift contents and no signature.
                // Decode them in a separate keyless core. It never receives identity
                // keys, conversation keys, or key-change events, so encrypted events
                // cannot bypass the strict verifier above.
                let mut legacy = ChatCore::new();
                legacy.set_reject_unverified(false);
                let mut legacy_messages: Vec<Value> = Vec::new();
                let encryption: Vec<Value> = events.iter().filter_map(|event| {
                    ChatCore::inspect_event_encryption(event).ok().flatten().map(|(id, encrypted)|
                        json!({"conversationId": id, "encrypted": encrypted}))
                }).collect();
                {
                    for (index, event) in events.iter().enumerate() {
                        if !result.errors.contains_key(&index) { continue; }
                        if let Ok(Event::Message(msg)) = legacy.decrypt_event(event, &HashMap::new(), &[]) {
                            if msg.key_version.is_none() {
                                legacy_messages.push(json!({
                                    "id": msg.meta.id, "sequenceId": msg.meta.sequence_id,
                                    "conversationId": msg.meta.conversation_id,
                                    "senderId": msg.meta.sender_id, "timestampMs": msg.meta.created_at_msec,
                                    "text": msg.text(), "verified": false, "legacy": true,
                                    "keyVersion": null, "content": msg.content, "attachments": msg.attachments
                                }));
                                result.errors.remove(&index);
                            }
                        }
                    }
                }
                for m in &result.messages {
                    if let Event::KeyChange(k) = &m.event {
                        if let (Some(key), Some(id)) = (result.conversation_keys.get(&k.key_version), k.meta.conversation_id.as_deref()) {
                            self.media_keys.entry(id.replace(':', "-")).or_default()
                                .insert(k.key_version.clone(), key.clone());
                            if k.verified {
                                let canonical = id.replace(':', "-");
                                if self.pending_rotations.get(&canonical)
                                    .map(|pending| pending.conversation_key_version == k.key_version).unwrap_or(false) {
                                    self.pending_rotations.remove(&canonical);
                                }
                                if let Some(raw) = &m.original_b64 {
                                    self.raw_key_events.entry(id.replace(':', "-")).or_default().insert(k.key_version.clone(), raw.clone());
                                }
                            }
                        }
                    }
                    if let Event::Message(msg) = &m.event {
                        if let chat_xdk_core::MessageContent::Edit { target_message_id, .. } = &msg.content {
                            if let (true, Some(conv), Some(seq), Some(raw)) = (msg.verified, &msg.meta.conversation_id, &msg.meta.sequence_id, &m.original_b64) {
                                let key = format!("{}:{}", conv.replace(':', "-"), target_message_id);
                                let newer = self.raw_edits.get(&key).map(|(old, _)| (seq.len(), seq.as_str()) > (old.len(), old.as_str())).unwrap_or(true);
                                if newer { self.raw_edits.insert(key, (seq.clone(), raw.clone())); }
                            }
                        }
                    }
                }
                // Conversation keys stay inside Chat. No key blobs cross NAPI.
                let mut messages: Vec<Value> = result.messages.iter().filter_map(|m| {
                    match &m.event {
                        Event::Message(msg) => Some(json!({
                            "id": msg.meta.id, "sequenceId": msg.meta.sequence_id,
                            "conversationId": msg.meta.conversation_id,
                            "senderId": msg.meta.sender_id, "timestampMs": msg.meta.created_at_msec,
                            "text": msg.text(), "verified": msg.verified,
                            "keyVersion": msg.key_version, "content": msg.content,
                            "attachments": msg.attachments
                            , "rawEvent": m.original_b64
                        })),
                        Event::MessageDeleted(d) => Some(json!({"type": "deleted", "event": d,
                            "conversationId": d.meta.conversation_id, "sequenceId": d.meta.sequence_id})),
                        Event::KeyChange(k) => Some(json!({"type": "keyChange", "sequenceId": k.meta.sequence_id,
                            "conversationId": k.meta.conversation_id, "keyVersion": k.key_version})),
                        Event::Failure(f) => Some(json!({"type": "failure", "conversationId": f.meta.conversation_id,
                            "id": f.meta.id, "failure": f.failure})),
                        Event::ReadReceipt(r) => Some(json!({"type": "read", "conversationId": r.meta.conversation_id,
                            "id": r.meta.id, "sequenceId": r.meta.sequence_id,
                            "senderId": r.meta.sender_id, "seenUntilId": r.seen_until_id, "verified": r.verified})),
                        Event::SettingsChange(s) => Some(json!({"type": "settings", "event": s,
                            "conversationId": s.meta.conversation_id})),
                        _ => None,
                    }
                }).collect();
                messages.extend(legacy_messages);
                let errors: Vec<String> = result.errors.values().cloned().collect();
                Ok(json!({"messages": messages, "errors": errors, "encryption": encryption,
                    "unlocked": self.chat.is_unlocked()}))
            }
            "encrypt" => {
                let a: EncryptArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                if !self.chat.is_unlocked() { return Err("locked".into()); }
                let payload = if let Some(reply) = a.reply {
                    let mut params = EncryptReplyParams::new(&a.conversation_id, a.text, reply.raw_event);
                    if let Some(raw) = self.raw_key_events.get(&a.conversation_id.replace(':', "-"))
                        .and_then(|versions| versions.get(&reply.key_version)) { params.reply_to_ckces = Some(vec![raw.clone()]); }
                    if let Some((_, raw)) = self.raw_edits.get(&format!("{}:{}", a.conversation_id.replace(':', "-"), reply.sequence_id)) {
                        params.reply_to_edit_event = Some(raw.clone());
                    }
                    params.message_id = a.message_id.filter(|id| !id.is_empty());
                    params.ttl_msec = a.ttl_msec.filter(|ttl| *ttl > 0);
                    if params.reply_to_event.is_none() {
                        params.reply_to_sequence_id = Some(reply.sequence_id);
                        params.reply_to_sender_id = Some(reply.sender_id.parse::<i64>().map_err(|_| "invalid_reply_sender")?);
                        params.reply_to_text = Some(reply.text);
                    }
                    if !a.attachments.is_empty() { params.attachments = Some(a.attachments); }
                    if !a.media_key_version.is_empty() {
                        let key = self.media_keys.get(&a.conversation_id.replace(':', "-"))
                            .and_then(|keys| keys.get(&a.media_key_version)).ok_or("missing_conversation_key")?;
                        params = params.with_conversation_key(key.to_bytes(), a.media_key_version);
                    }
                    self.chat.encrypt_reply(params)
                } else {
                let mut params = EncryptMessageParams::new(&a.conversation_id, a.text);
                params.message_id = a.message_id.filter(|id| !id.is_empty());
                params.ttl_msec = a.ttl_msec.filter(|ttl| *ttl > 0);
                if !a.attachments.is_empty() { params.attachments = Some(a.attachments); }
                if !a.media_key_version.is_empty() {
                    let key = self.media_keys.get(&a.conversation_id.replace(':', "-"))
                        .and_then(|keys| keys.get(&a.media_key_version)).ok_or("missing_conversation_key")?;
                    params = params.with_conversation_key(key.to_bytes(), a.media_key_version);
                }
                self.chat.encrypt_message(params)
                }.map_err(|e| e.to_string())?;
                Ok(json!({
                    "conversation_id": a.conversation_id,
                    "message_id": payload.message_id,
                    "encoded_message_create_event": payload.encrypted_content,
                    "encoded_message_event_signature": payload.encoded_event_signature
                }))
            }
            "encryptReaction" => {
                let a: ReactionArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                if !self.chat.is_unlocked() { return Err("locked".into()); }
                let mut params = EncryptReactionParams::new("", a.emoji);
                params.conversation_id = Some(a.conversation_id.clone());
                params.target_message_sequence_id = Some(a.sequence_id);
                let payload = if a.remove { self.chat.encrypt_remove_reaction(&params) }
                    else { self.chat.encrypt_add_reaction(&params) }.map_err(|e| e.to_string())?;
                Ok(json!({"conversation_id": a.conversation_id, "message_id": payload.message_id,
                    "encoded_message_create_event": payload.encrypted_content,
                    "encoded_message_event_signature": payload.encoded_event_signature}))
            }
            "prepareConversation" | "prepareGroup" | "prepareKeyRotation" => {
                let a: CreateArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                if !self.chat.is_unlocked() { return Err("locked".into()); }
                let change = if method == "prepareGroup" {
                    let mut params = GroupCreateParams::new(a.public_keys, a.conversation_id, a.members, a.admins);
                    if !a.title.is_empty() { params.title = Some(a.title); }
                    self.chat.prepare_group_create(params)
                } else {
                    let mut params = ConversationKeyChangeParams::new(a.public_keys);
                    if !a.conversation_id.is_empty() { params.conversation_id = Some(a.conversation_id); }
                    if method == "prepareKeyRotation" && params.conversation_id.is_none() {
                        return Err("missing_conversation_id".into());
                    }
                    if method == "prepareKeyRotation" { self.chat.prepare_key_rotation(params, a.for_key_rotation) }
                    else { self.chat.prepare_conversation_key_change(params) }
                }.map_err(|e| e.to_string())?;
                if method == "prepareKeyRotation" {
                    self.pending_rotations.insert(change.conversation_id.replace(':', "-"), change.clone());
                }
                // The key-change action signature is bound to the new conversation
                // key, so the verifier can only check it when the same key travels
                // with the mutation. `PreparedConversationChange` hides the raw key
                // from its own serialization (it must never be logged or cached),
                // so expose exactly this one protocol field here using the same
                // unpadded base64 the signed payload uses.
                let mut value = serde_json::to_value(&change).map_err(|e| e.to_string())?;
                if let Some(key) = change.conversation_key.as_ref() {
                    value["base64_encoded_key_rotation"] =
                        json!(base64::engine::general_purpose::STANDARD_NO_PAD.encode(key.encoded()));
                }
                Ok(value)
            }
            "prepareGroupMembers" => {
                let a: GroupMembersArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                if !self.chat.is_unlocked() { return Err("locked".into()); }
                if a.conversation_id.is_empty() { return Err("missing_conversation_id".into()); }
                if a.new_member_ids.is_empty() { return Err("missing_new_member_ids".into()); }
                let mut params = GroupMembersChangeParams::new(a.public_keys, a.conversation_id,
                    a.new_member_ids, a.current_member_ids, a.current_admin_ids, a.current_pending_member_ids);
                params.current_title = a.current_title;
                params.current_avatar_url = a.current_avatar_url;
                params.current_ttl_msec = a.current_ttl_msec;
                params.current_screen_capture_blocking_enabled = a.current_screen_capture_blocking_enabled;
                params.current_invite_url = a.current_invite_url;
                params.current_invite_expires_msec = a.current_invite_expires_msec;
                params.current_invite_affiliate_id = a.current_invite_affiliate_id;
                params.current_admin_settings = a.current_admin_settings;
                let change = if a.key_version.is_empty() {
                    self.chat.prepare_group_members_change(params)
                } else {
                    let pending = self.pending_rotations.get(&params.conversation_id.replace(':', "-"))
                        .filter(|pending| pending.conversation_key_version == a.key_version)
                        .ok_or("missing_prepared_rotation")?;
                    self.chat.finish_group_members_change(params, pending.clone(), a.current_description)
                }.map_err(|e| e.to_string())?;
                // Do not activate a prepared key before the server accepts it.
                // Refresh and decrypt the acknowledged key-change event instead.
                serde_json::to_value(change).map_err(|e| e.to_string())
            }
            "prepareGroupAction" => {
                let a: GroupActionParams = serde_json::from_str(input).map_err(|e| e.to_string())?;
                if !self.chat.is_unlocked() { return Err("locked".into()); }
                let signature = self.chat.prepare_group_action(a).map_err(|e| e.to_string())?;
                Ok(json!({"action_signatures": [signature]}))
            }
            "encryptRead" => {
                let a: ConversationArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                let payload = self.chat.encrypt_read_receipt(&a.conversation_id, &a.sequence_id).map_err(|e| e.to_string())?;
                Ok(json!({"conversation_id": a.conversation_id, "message_id": payload.message_id,
                    "encoded_message_create_event": payload.encrypted_content,
                    "encoded_message_event_signature": payload.encoded_event_signature}))
            }
            "preparePlainRead" => {
                let a: ConversationArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                let (id, event) = self.chat.prepare_plain_read_receipt(&a.conversation_id, &a.sequence_id).map_err(|e| e.to_string())?;
                Ok(json!({"conversation_id": a.conversation_id, "message_id": id, "encoded_message_event": event}))
            }
            "prepareConversationDelete" => {
                let a: ConversationArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                let signature = self.chat.prepare_conversation_delete(&a.conversation_id).map_err(|e| e.to_string())?;
                Ok(json!({"action_signatures": [signature]}))
            }
            "encryptMetadata" | "decryptMetadata" => {
                let a: LocalArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                if !self.chat.is_unlocked() { return Err("locked".into()); }
                let canonical = a.conversation_id.replace(':', "-");
                if method == "encryptMetadata" && !a.key_version.is_empty() {
                    let pending = self.pending_rotations.get(&canonical)
                        .filter(|pending| pending.conversation_key_version == a.key_version)
                        .ok_or("missing_prepared_rotation")?;
                    let key = pending.conversation_key.as_ref().ok_or("missing_prepared_rotation")?;
                    let text = Zeroizing::new(a.text);
                    let ciphertext = self.chat.encrypt(&text, key).map_err(|e| e.to_string())?;
                    return Ok(json!({"ciphertext": ciphertext, "key_version": a.key_version}));
                }
                let keys = self.media_keys.get(&canonical).ok_or("missing_conversation_key")?;
                if method == "encryptMetadata" {
                    let version = keys.keys().max_by(|a, b| a.len().cmp(&b.len()).then(a.cmp(b)))
                        .ok_or("missing_conversation_key")?;
                    let text = Zeroizing::new(a.text);
                    let ciphertext = self.chat.encrypt(&text, &keys[version]).map_err(|e| e.to_string())?;
                    return Ok(json!({"ciphertext": ciphertext, "key_version": version}));
                }
                // Metadata may still use a previous conversation key after a
                // member change. Authenticate it against the retained keys.
                let mut versions: Vec<&String> = keys.keys().collect();
                versions.sort_by(|a, b| b.len().cmp(&a.len()).then(b.cmp(a)));
                for version in versions {
                    if let Ok(text) = self.chat.decrypt(&a.ciphertext, &keys[version]) {
                        return Ok(json!({"text": text, "key_version": version}));
                    }
                }
                Err("metadata_decrypt_failed".into())
            }
            "prepareDelete" => {
                let a: DeleteArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                let signature = self.chat.prepare_message_delete(&MessageDeleteParams::new(
                    a.conversation_id, a.sequence_ids, a.delete_for_all)).map_err(|e| e.to_string())?;
                Ok(json!({"action_signatures": [signature]}))
            }
            "changePin" => {
                let mut a: PinChangeArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                let old = Zeroizing::new(std::mem::take(&mut a.old_pin));
                let new = Zeroizing::new(std::mem::take(&mut a.new_pin));
                if old.len() != 4 || new.len() != 4 || !old.bytes().all(|b| b.is_ascii_digit()) ||
                    !new.bytes().all(|b| b.is_ascii_digit()) { return Err("invalid_pin_length".into()); }
                self.runtime.block_on(self.chat.change_pin(old.as_bytes(), new.as_bytes())).map_err(|e| e.to_string())?;
                Ok(json!({"changed": true}))
            }
            "encryptLocal" | "decryptLocal" => {
                let a: LocalArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                if !self.chat.is_unlocked() { return Err("locked".into()); }
                let keys = self.media_keys.get(&a.conversation_id.replace(':', "-")).ok_or("missing_conversation_key")?;
                let version = if method == "encryptLocal" {
                    keys.keys().max_by(|a, b| a.len().cmp(&b.len()).then(a.cmp(b))).ok_or("missing_conversation_key")?
                } else { &a.key_version };
                let key = keys.get(version).ok_or("missing_conversation_key")?;
                if method == "encryptLocal" {
                    let text = Zeroizing::new(a.text);
                    let encrypted = self.chat.encrypt_stream(text.as_bytes(), key).map_err(|e| e.to_string())?;
                    Ok(json!({"key_version": version, "ciphertext": B64.encode(encrypted)}))
                } else {
                    let bytes = B64.decode(a.ciphertext).map_err(|_| "invalid_ciphertext")?;
                    let plain = Zeroizing::new(self.chat.decrypt_stream(&bytes, key).map_err(|e| e.to_string())?);
                    let text = std::str::from_utf8(&plain).map_err(|_| "invalid_utf8")?;
                    Ok(json!({"text": text}))
                }
            }
            "encryptMedia" | "decryptMedia" | "encryptGroupMedia" => {
                let a: MediaArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                if !self.chat.is_unlocked() { return Err("locked".into()); }
                if method == "encryptGroupMedia" {
                    let pending = self.pending_rotations.get(&a.conversation_id.replace(':', "-"))
                        .filter(|pending| pending.conversation_key_version == a.key_version)
                        .ok_or("missing_prepared_rotation")?;
                    let key = pending.conversation_key.as_ref().ok_or("missing_prepared_rotation")?;
                    let size = std::fs::metadata(&a.input_path).map_err(|_| "media_read_failed")?.len();
                    if size > 34 * 1024 * 1024 { return Err("media_too_large".into()); }
                    let bytes = Zeroizing::new(std::fs::read(&a.input_path).map_err(|_| "media_read_failed")?);
                    let encrypted = Zeroizing::new(self.chat.encrypt_stream(&bytes, key).map_err(|e| e.to_string())?);
                    std::fs::write(&a.output_path, &encrypted).map_err(|_| "media_write_failed")?;
                    return Ok(json!({"key_version": a.key_version, "media_bytes": encrypted.len(), "media_path": a.output_path}));
                }
                let keys = self.media_keys.get(&a.conversation_id.replace(':', "-")).ok_or("missing_conversation_key")?;
                let version = if method == "encryptMedia" {
                    keys.keys().max_by(|a, b| a.len().cmp(&b.len()).then(a.cmp(b))).ok_or("missing_conversation_key")?
                } else { &a.key_version };
                let key = keys.get(version).ok_or("missing_conversation_key")?;
                let size = std::fs::metadata(&a.input_path).map_err(|_| "media_read_failed")?.len();
                if size > 34 * 1024 * 1024 { return Err("media_too_large".into()); }
                let bytes = Zeroizing::new(std::fs::read(&a.input_path).map_err(|_| "media_read_failed")?);
                let processed = Zeroizing::new(if method == "encryptMedia" {
                    self.chat.encrypt_stream(&bytes, key)
                } else { self.chat.decrypt_stream(&bytes, key) }.map_err(|e| e.to_string())?);
                std::fs::write(&a.output_path, &processed).map_err(|_| "media_write_failed")?;
                Ok(json!({"key_version": version, "media_bytes": processed.len(), "media_path": a.output_path}))
            }
            "decryptMetadataFile" => {
                let a: MediaArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                if !self.chat.is_unlocked() { return Err("locked".into()); }
                let keys = self.media_keys.get(&a.conversation_id.replace(':', "-")).ok_or("missing_conversation_key")?;
                let size = std::fs::metadata(&a.input_path).map_err(|_| "media_read_failed")?.len();
                if size > 34 * 1024 * 1024 { return Err("media_too_large".into()); }
                let bytes = Zeroizing::new(std::fs::read(&a.input_path).map_err(|_| "media_read_failed")?);
                // Group avatars use the same authenticated SecretStream file
                // format as attachments. The URL itself may be plaintext;
                // decrypting that string cannot produce the avatar image.
                // A header-only stream has no authenticated image content.
                if bytes.len() <= 24 { return Err("metadata_file_decrypt_failed".into()); }
                let mut versions: Vec<&String> = keys.keys().collect();
                versions.sort_by(|left, right| {
                    let left_hint = !a.key_version.is_empty() && *left == &a.key_version;
                    let right_hint = !a.key_version.is_empty() && *right == &a.key_version;
                    right_hint.cmp(&left_hint).then(right.len().cmp(&left.len())).then(right.cmp(left))
                });
                for version in versions {
                    if let Ok(plain) = self.chat.decrypt_stream(&bytes, &keys[version]) {
                        let plain = Zeroizing::new(plain);
                        std::fs::write(&a.output_path, &plain).map_err(|_| "media_write_failed")?;
                        return Ok(json!({"key_version": version, "media_bytes": plain.len(), "media_path": a.output_path}));
                    }
                }
                Err("metadata_file_decrypt_failed".into())
            }
            "verifyPayload" => {
                #[derive(Deserialize)]
                struct VerifyArgs { public_key: String, signature: String, payload: String }
                let a: VerifyArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                let signature = base64::engine::general_purpose::STANDARD_NO_PAD
                    .decode(a.signature.as_bytes())
                    .or_else(|_| base64::engine::general_purpose::STANDARD.decode(a.signature.as_bytes()))
                    .map_err(|_| "invalid_signature_encoding")?;
                let valid = self.chat.verify(&a.public_key, &signature, a.payload.as_bytes())
                    .map_err(|e| e.to_string())?;
                Ok(json!({"valid": valid}))
            }
            "fingerprint" => {
                let a: FingerprintArgs = serde_json::from_str(input).map_err(|e| e.to_string())?;
                let fingerprint = if a.public_key.is_empty() {
                    self.chat.get_public_key_fingerprint().map_err(|e| e.to_string())?
                } else {
                    if !self.chat.verify_key_binding(&a.public_key, &a.signing_key, &a.binding).map_err(|e| e.to_string())? {
                        return Err("invalid_identity_binding".into());
                    }
                    let bytes = B64.decode(a.public_key).map_err(|_| "invalid_public_key")?;
                    let key = if bytes.len() == 33 || bytes.len() == 65 {
                        p256::PublicKey::from_sec1_bytes(&bytes).map_err(|_| "invalid_public_key")?
                    } else { p256::PublicKey::from_public_key_der(&bytes).map_err(|_| "invalid_public_key")? };
                    let spki = key.to_public_key_der().map_err(|_| "invalid_public_key")?;
                    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(chat_xdk_core::crypto::hash::sha256(spki.as_bytes()))
                };
                Ok(json!({"fingerprint": fingerprint}))
            }
            "lock" => { self.chat.lock(); self.media_keys.clear(); self.raw_key_events.clear(); self.raw_edits.clear(); self.pending_rotations.clear(); Ok(json!({"unlocked": false})) }
            "diagnostics" => Ok(json!({"network": self.recovery.diagnostics()})),
            _ => Err("unsupported_method".into()),
        }
    }
}

#[no_mangle]
pub extern "C" fn hx_chat_new() -> *mut Session {
    match std::panic::catch_unwind(Session::new) {
        Ok(Ok(s)) => Box::into_raw(Box::new(s)),
        _ => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn hx_chat_free(session: *mut Session) {
    if !session.is_null() { drop(Box::from_raw(session)); }
}

#[no_mangle]
pub unsafe extern "C" fn hx_chat_free_string(value: *mut c_char) {
    if !value.is_null() { drop(CString::from_raw(value)); }
}

#[no_mangle]
pub unsafe extern "C" fn hx_chat_call(session: *mut Session, method: *const c_char, input: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if session.is_null() || method.is_null() || input.is_null() { return Err("invalid_session".into()); }
        let method = CStr::from_ptr(method).to_str().map_err(|_| "invalid_method")?;
        let input = Zeroizing::new(CStr::from_ptr(input).to_str().map_err(|_| "invalid_input")?.to_owned());
        (*session).call(method, &input)
    }));
    let value = match result {
        Ok(Ok(data)) => json!({"ok": true, "data": data}),
        Ok(Err(error)) => json!({"ok": false, "error": error}),
        Err(_) => json!({"ok": false, "error": "native_failure"}),
    };
    CString::new(value.to_string()).unwrap().into_raw()
}

#[cfg(test)]
mod tests {
    use super::*;
    use base64::{engine::general_purpose::STANDARD as B64, Engine};

    fn fixture() -> Value {
        serde_json::from_str(include_str!("../../../.codex/dm-reference/chat-xdk-source/tests/fixtures/sdk_vectors.json")).unwrap()
    }

    fn signing_key(v: &Value) -> Value {
        json!({
            "user_id": v["event_sender_id"],
            "public_key_version": v["event_signing_key_version"],
            "public_key": v["signing_public_b64"],
            "identity_public_key": v["identity_public_b64"],
            "identity_public_key_signature": v["identity_public_key_signature_b64"]
        })
    }

    fn loaded(v: &Value) -> Session {
        let s = Session::new().unwrap();
        let keys = Zeroizing::new(B64.decode(v["private_keys_concat_b64"].as_str().unwrap()).unwrap());
        s.chat.import_keys_with_version(&keys, v["event_recipient_key_version"].as_str().unwrap()).unwrap();
        s.chat.set_identity(v["event_sender_id"].as_str().unwrap(), v["event_signing_key_version"].as_str().unwrap());
        s
    }

    #[test]
    fn verified_backlog_decrypts_without_exporting_conversation_keys() {
        let v = fixture();
        let mut s = loaded(&v);
        let input = json!({"events": [v["event_message_b64"], v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]});
        let result = s.call("decrypt", &input.to_string()).unwrap();
        assert_eq!(result["errors"].as_array().unwrap().len(), 0);
        let messages = result["messages"].as_array().unwrap();
        let message = messages.iter().find(|m| m.get("text").is_some()).unwrap();
        assert_eq!(message["text"], v["event_message_text"]);
        assert_eq!(message["verified"], true);
        assert!(result.get("conversation_keys").is_none());
        assert!(!result.to_string().contains(v["conversation_key_b64"].as_str().unwrap()));
    }

    #[test]
    fn bad_signing_key_never_exposes_plaintext() {
        let v = fixture();
        let mut s = loaded(&v);
        let mut key = signing_key(&v);
        key["identity_public_key_signature"] = json!("AAAA");
        let result = s.call("decrypt", &json!({"events": [v["event_key_change_b64"], v["event_message_b64"]],
            "signing_keys": [key]}).to_string()).unwrap();
        assert!(result["messages"].as_array().unwrap().iter().all(|m| m.get("text").is_none()));
        assert!(!result["errors"].as_array().unwrap().is_empty());
    }

    #[test]
    fn native_send_returns_signed_wire_payload_and_lock_disables_send() {
        let v = fixture();
        let mut s = loaded(&v);
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let result = s.call("encrypt", &json!({"conversation_id": v["event_conversation_id"], "text": "你好，原生私信"}).to_string()).unwrap();
        assert!(!result["message_id"].as_str().unwrap().is_empty());
        assert!(!B64.decode(result["encoded_message_create_event"].as_str().unwrap()).unwrap().is_empty());
        assert!(!B64.decode(result["encoded_message_event_signature"].as_str().unwrap()).unwrap().is_empty());
        assert!(!result.to_string().contains("你好"));
        s.call("lock", "{}").unwrap();
        assert!(s.call("encrypt", &json!({"conversation_id": v["event_conversation_id"], "text": "Hello"}).to_string()).is_err());
    }

    #[test]
    fn malformed_untrusted_events_return_errors_without_panicking() {
        let mut s = Session::new().unwrap();
        let result = s.call("decrypt", &json!({"events": ["!!!not-an-event!!!", "////"], "signing_keys": []}).to_string()).unwrap();
        assert!(result["messages"].as_array().unwrap().is_empty());
        assert_eq!(result["errors"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn replies_keep_upload_id_and_reactions_roundtrip_signed_targets() {
        let v = fixture();
        let mut s = loaded(&v);
        s.call("decrypt", &json!({"events": [v["event_message_b64"], v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let conv = v["event_conversation_id"].as_str().unwrap();
        let id = "29d91d13-ffea-4c3c-a7a0-f05fab1d4c2f";
        let reply = s.call("encrypt", &json!({"conversation_id": conv, "text": "reply",
            "message_id": id, "reply": {"raw_event": v["event_message_b64"], "text": "",
                "sender_id": v["event_sender_id"], "sequence_id": "1"}}).to_string()).unwrap();
        assert_eq!(reply["message_id"], id);
        let mut params = EncryptReplyParams::new(conv, "reply", v["event_message_b64"].as_str().unwrap());
        params.message_id = Some(id.into());
        let payload = s.chat.encrypt_reply(params).unwrap();
        let event = chat_xdk_core::internals::frame_send_payload(&payload, id,
            v["event_sender_id"].as_str().unwrap(), conv).unwrap();
        let decoded = s.call("decrypt", &json!({"events": [event], "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        assert_eq!(decoded["messages"][0]["verified"], true);
        assert_eq!(decoded["messages"][0]["content"]["replying_to_preview"]["message_text"], v["event_message_text"]);
        for remove in [false, true] {
            let result = s.call("encryptReaction", &json!({"conversation_id": conv,
                "sequence_id": "9007199254740993", "emoji": "👍", "remove": remove}).to_string()).unwrap();
            assert!(!result["message_id"].as_str().unwrap().is_empty());
            let mut reaction = EncryptReactionParams::new("", "👍");
            reaction.conversation_id = Some(conv.into());
            reaction.target_message_sequence_id = Some("9007199254740993".into());
            let payload = if remove { s.chat.encrypt_remove_reaction(&reaction) }
                else { s.chat.encrypt_add_reaction(&reaction) }.unwrap();
            let event = chat_xdk_core::internals::frame_send_payload(&payload, &payload.message_id,
                v["event_sender_id"].as_str().unwrap(), conv).unwrap();
            let decoded = s.call("decrypt", &json!({"events": [event], "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
            assert_eq!(decoded["messages"][0]["content"]["target_message_id"], "9007199254740993");
            assert_eq!(decoded["messages"][0]["content"]["content_type"], if remove { "ReactionRemoved" } else { "Reaction" });
        }
    }

    #[test]
    fn attachment_upload_id_is_preserved_and_authenticated_by_the_native_signature() {
        let v = fixture();
        let mut s = loaded(&v);
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let conv = v["event_conversation_id"].as_str().unwrap();
        let sender = v["event_sender_id"].as_str().unwrap();
        let id = "29d91d13-ffea-4c3c-a7a0-f05fab1d4c2f";
        let attachment = json!({"attachment_type": "media", "media_hash_key": "upload-hash",
            "width": 480, "height": 320, "filesize_bytes": 123, "filename": "photo.png", "media_type": 1});
        let result = s.call("encrypt", &json!({"conversation_id": conv, "text": "caption",
            "message_id": id, "attachments": [attachment.clone()]}).to_string()).unwrap();
        assert_eq!(result["message_id"], id);

        let mut params = EncryptMessageParams::new(conv, "caption");
        params.message_id = Some(id.into());
        params.attachments = Some(vec![serde_json::from_value(attachment).unwrap()]);
        let payload = s.chat.encrypt_message(params).unwrap();
        let event = chat_xdk_core::internals::frame_send_payload(&payload, id, sender, conv).unwrap();
        let decoded = s.call("decrypt", &json!({"events": [event], "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let message = &decoded["messages"][0];
        assert_eq!(message["id"], id);
        assert_eq!(message["verified"], true);
        assert_eq!(message["text"], "caption");
        assert_eq!(message["attachments"][0]["media_hash_key"], "upload-hash");

        let tampered = chat_xdk_core::internals::frame_send_payload(&payload, "different-id", sender, conv).unwrap();
        let rejected = s.call("decrypt", &json!({"events": [tampered], "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        assert!(rejected["messages"].as_array().unwrap().is_empty());
        assert!(!rejected["errors"].as_array().unwrap().is_empty());
    }

    #[test]
    fn multiple_attachments_and_voice_duration_roundtrip_in_one_signed_message() {
        let v = fixture();
        let mut s = loaded(&v);
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let conv = v["event_conversation_id"].as_str().unwrap();
        let sender = v["event_sender_id"].as_str().unwrap();
        let id = "d0b5c405-c584-47bc-a1df-ecbfc073bd67";
        let attachments = vec![
            json!({"attachment_type":"media", "media_hash_key":"photo-one", "width":480,
                "height":320, "filesize_bytes":100, "filename":"one.jpg", "media_type":1}),
            json!({"attachment_type":"media", "media_hash_key":"photo-two", "width":480,
                "height":320, "filesize_bytes":200, "filename":"two.jpg", "media_type":1}),
        ];
        let mut params = EncryptMessageParams::new(conv, "caption");
        params.message_id = Some(id.into());
        params.attachments = Some(attachments.into_iter().map(|a| serde_json::from_value(a).unwrap()).collect());
        let payload = s.chat.encrypt_message(params).unwrap();
        let event = chat_xdk_core::internals::frame_send_payload(&payload, id, sender, conv).unwrap();
        let decoded = s.call("decrypt", &json!({"events":[event], "signing_keys":[signing_key(&v)]}).to_string()).unwrap();
        let message = &decoded["messages"][0];
        assert_eq!(message["verified"], true);
        assert_eq!(message["text"], "caption");
        assert_eq!(message["attachments"].as_array().unwrap().len(), 2);
        assert_eq!(message["attachments"][0]["media_hash_key"], "photo-one");
        assert_eq!(message["attachments"][1]["media_hash_key"], "photo-two");
        let voice = json!({"attachment_type":"media", "media_hash_key":"voice", "width":0,
            "height":0, "filesize_bytes":300, "filename":"voice.m4a", "media_type":4, "duration_millis":2134});
        let voice_id = "8ccf2f87-241d-4839-a267-cf656999df81";
        let mut params = EncryptMessageParams::new(conv, "");
        params.message_id = Some(voice_id.into());
        params.attachments = Some(vec![serde_json::from_value(voice).unwrap()]);
        let payload = s.chat.encrypt_message(params).unwrap();
        let event = chat_xdk_core::internals::frame_send_payload(&payload, voice_id, sender, conv).unwrap();
        let decoded = s.call("decrypt", &json!({"events":[event], "signing_keys":[signing_key(&v)]}).to_string()).unwrap();
        assert_eq!(decoded["messages"][0]["attachments"][0]["media_type"], "audio");
        assert_eq!(decoded["messages"][0]["attachments"][0]["duration_millis"], 2134);
    }

    #[test]
    fn moving_photo_pair_filenames_survive_a_signed_encrypted_roundtrip() {
        let v = fixture();
        let mut s = loaded(&v);
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let conv = v["event_conversation_id"].as_str().unwrap();
        let sender = v["event_sender_id"].as_str().unwrap();
        let id = "6b409e83-10b7-4b3e-8242-dd2e452183fa";
        let image_name = format!("HXMP_v1_{id}_image.jpg");
        let video_name = format!("HXMP_v1_{id}_video.mp4");
        let attachments = vec![
            json!({"attachment_type":"media", "media_hash_key":"moving-cover", "width":480,
                "height":640, "filesize_bytes":100, "filename":image_name, "media_type":1}),
            json!({"attachment_type":"media", "media_hash_key":"moving-video", "width":480,
                "height":640, "filesize_bytes":200, "filename":video_name, "media_type":3}),
        ];
        let mut params = EncryptMessageParams::new(conv, "moving caption");
        params.message_id = Some(id.into());
        params.attachments = Some(attachments.into_iter().map(|a| serde_json::from_value(a).unwrap()).collect());
        let payload = s.chat.encrypt_message(params).unwrap();
        let event = chat_xdk_core::internals::frame_send_payload(&payload, id, sender, conv).unwrap();
        let decoded = s.call("decrypt", &json!({"events":[event],
            "signing_keys":[signing_key(&v)]}).to_string()).unwrap();
        let message = &decoded["messages"][0];
        assert_eq!(message["verified"], true);
        assert_eq!(message["id"], id);
        assert_eq!(message["text"], "moving caption");
        assert_eq!(message["attachments"].as_array().unwrap().len(), 2);
        assert_eq!(message["attachments"][0]["filename"], image_name);
        assert_eq!(message["attachments"][1]["filename"], video_name);
        assert_eq!(message["attachments"][0]["media_type"], "image");
        assert_eq!(message["attachments"][1]["media_type"], "video");
    }

    // Minimal binary-Thrift fixture matching the official SDK's legacy MCE:
    // holder.contents.message.message_text and an absent conversation-key version.
    fn classic_event(key_version: Option<&str>) -> String {
        fn string_field(out: &mut Vec<u8>, id: i16, bytes: &[u8]) {
            out.push(11); out.extend(id.to_be_bytes());
            out.extend((bytes.len() as i32).to_be_bytes()); out.extend(bytes);
        }
        let mut content = vec![12, 0, 1, 12, 0, 1];
        string_field(&mut content, 1, "旧消息".as_bytes()); content.extend([0, 0, 0]);
        let mut event = Vec::new();
        for (id, value) in [(1, "10"), (2, "classic-message"), (3, "200"), (4, "100-200"), (6, "1700000000000")] {
            string_field(&mut event, id, value.as_bytes());
        }
        event.extend([12, 0, 7, 12, 0, 1]);
        string_field(&mut event, 100, &content);
        if let Some(version) = key_version { string_field(&mut event, 101, version.as_bytes()); }
        event.extend([0, 0, 0]); B64.encode(event)
    }

    #[test]
    fn classic_plaintext_reads_while_locked_and_cannot_bypass_encrypted_verification() {
        let v = fixture(); let mut s = loaded(&v);
        let input = json!({"events": [classic_event(None), classic_event(Some("1"))], "signing_keys": []});
        let result = s.call("decrypt", &input.to_string()).unwrap();
        assert_eq!(result["messages"].as_array().unwrap().len(), 1);
        assert_eq!(result["messages"][0]["text"], "旧消息");
        assert_eq!(result["messages"][0]["legacy"], true);
        assert_eq!(result["messages"][0]["verified"], false);
        assert_eq!(result["errors"].as_array().unwrap().len(), 1);
        s.call("lock", "{}").unwrap();
        let result = s.call("decrypt", &input.to_string()).unwrap();
        assert_eq!(result["messages"].as_array().unwrap().len(), 1);
        assert_eq!(result["messages"][0]["text"], "旧消息");
        assert_eq!(result["errors"].as_array().unwrap().len(), 1);
        assert_eq!(result["encryption"][0]["encrypted"], false);
        assert_eq!(result["encryption"][1]["encrypted"], true);
    }

    #[test]
    fn nickname_uses_authenticated_ciphertext_and_lock_erases_keys() {
        let v = fixture(); let mut s = loaded(&v);
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]], "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let encrypted = s.call("encryptLocal", &json!({"conversation_id": v["event_conversation_id"], "text": "设备私有昵称"}).to_string()).unwrap();
        assert!(!encrypted.to_string().contains("私有"));
        let args = json!({"conversation_id": v["event_conversation_id"], "key_version": encrypted["key_version"], "ciphertext": encrypted["ciphertext"]});
        assert_eq!(s.call("decryptLocal", &args.to_string()).unwrap()["text"], "设备私有昵称");
        let mut wrong = args.clone(); wrong["key_version"] = json!("missing-version");
        assert!(s.call("decryptLocal", &wrong.to_string()).is_err());
        s.call("lock", "{}").unwrap(); assert!(s.media_keys.is_empty());
        assert!(s.call("decryptLocal", &args.to_string()).is_err());
    }

    #[test]
    fn media_files_roundtrip_and_reject_tampering_wrong_version_and_wrong_conversation() {
        let v = fixture(); let mut s = loaded(&v);
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]], "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let dir = std::env::temp_dir().join(format!("harmonyx-chat-{}-{}", std::process::id(),
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
        std::fs::create_dir(&dir).unwrap();
        let source = dir.join("source"); let cipher = dir.join("cipher"); let out = dir.join("out");
        let plain = vec![0x5Au8; 1024 * 1024 + 31]; std::fs::write(&source, &plain).unwrap();
        let encrypted = s.call("encryptMedia", &json!({"conversation_id": v["event_conversation_id"], "input_path": source,
            "output_path": cipher}).to_string()).unwrap();
        let args = json!({"conversation_id": v["event_conversation_id"], "key_version": encrypted["key_version"],
            "input_path": cipher, "output_path": out});
        s.call("decryptMedia", &args.to_string()).unwrap(); assert_eq!(std::fs::read(&out).unwrap(), plain);
        let mut wrong = args.clone(); wrong["key_version"] = json!("missing-version");
        assert!(s.call("decryptMedia", &wrong.to_string()).is_err());
        wrong = args.clone(); wrong["conversation_id"] = json!("another-conversation");
        assert!(s.call("decryptMedia", &wrong.to_string()).is_err());
        let mut bytes = std::fs::read(&cipher).unwrap(); let last = bytes.len()-1; bytes[last] ^= 1;
        std::fs::write(&cipher, bytes).unwrap(); assert!(s.call("decryptMedia", &args.to_string()).is_err());
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn peer_fingerprint_matches_sdk_own_identity_and_rejects_invalid_binding() {
        let v = fixture(); let mut s = loaded(&v);
        let registration = s.chat.generate_keypairs().unwrap();
        let own = s.call("fingerprint", "{}").unwrap();
        let mut args = json!({"public_key": registration.public_key.public_key,
            "signing_key": registration.public_key.signing_public_key,
            "binding": registration.public_key.identity_public_key_signature});
        assert_eq!(s.call("fingerprint", &args.to_string()).unwrap(), own);
        args["binding"] = json!("AAAA"); assert!(s.call("fingerprint", &args.to_string()).is_err());
    }

    #[test]
    fn group_metadata_uses_authenticated_xsalsa_and_previous_keys() {
        let v = fixture(); let mut s = loaded(&v);
        let conv = v["event_conversation_id"].as_str().unwrap();
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let key = s.media_keys[&conv.replace(':', "-")].values().next().unwrap().clone();
        for text in ["测试群聊", "https://pbs.twimg.com/group.jpg"] {
            let cipher = s.chat.encrypt(text, &key).unwrap();
            let args = json!({"conversation_id": conv, "ciphertext": cipher});
            // A newer key cannot authenticate the old metadata; the old key can.
            s.media_keys.get_mut(&conv.replace(':', "-")).unwrap()
                .insert("9999999999999999999".into(), XChatConversationKey::from_bytes(vec![7;32]).unwrap());
            assert_eq!(s.call("decryptMetadata", &args.to_string()).unwrap()["text"], text);
            let mut corrupt = B64.decode(&cipher).unwrap(); let last = corrupt.len()-1; corrupt[last] ^= 1;
            assert!(s.call("decryptMetadata", &json!({"conversation_id": conv,
                "ciphertext": B64.encode(corrupt)}).to_string()).is_err());
        }
    }

    #[test]
    fn group_metadata_encrypts_with_latest_key_and_preserves_utf8() {
        let v = fixture(); let mut s = loaded(&v);
        let conv = v["event_conversation_id"].as_str().unwrap();
        let args = json!({"conversation_id": conv, "text": "群名称、说明和头像 URL 🎉"});
        assert!(s.call("encryptMetadata", &args.to_string()).is_err());
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let latest = "9999999999999999999";
        let key = XChatConversationKey::from_bytes(vec![7;32]).unwrap();
        s.media_keys.get_mut(&conv.replace(':', "-")).unwrap().insert(latest.into(), key.clone());
        let first = s.call("encryptMetadata", &args.to_string()).unwrap();
        let second = s.call("encryptMetadata", &args.to_string()).unwrap();
        assert_eq!(first["key_version"], latest);
        assert_ne!(first["ciphertext"], second["ciphertext"]);
        assert_eq!(s.chat.decrypt(first["ciphertext"].as_str().unwrap(), &key).unwrap(),
            args["text"].as_str().unwrap());
        assert!(first.get("conversation_key").is_none());
        let result = s.call("decryptMetadata", &json!({"conversation_id": conv,
            "ciphertext": first["ciphertext"]}).to_string()).unwrap();
        assert_eq!(result["text"], args["text"]);
        assert_eq!(result["key_version"], latest);
        s.call("lock", "{}").unwrap();
        assert!(s.call("encryptMetadata", &args.to_string()).is_err());
    }

    #[test]
    fn group_member_add_and_rotation_bind_the_group_and_keep_keys_private() {
        let v = fixture(); let mut s = loaded(&v);
        let public_keys = json!([
            {"user_id": v["event_sender_id"], "public_key": v["identity_public_b64"], "key_version": "1"},
            {"user_id": "new-member", "public_key": v["identity_public_b64"], "key_version": "1"}
        ]);
        let args = json!({"conversation_id": "g555", "public_keys": public_keys,
            "new_member_ids": ["new-member"], "current_member_ids": [v["event_sender_id"]],
            "current_admin_ids": [v["event_sender_id"]], "current_pending_member_ids": ["pending"],
            "current_title": "encrypted-title", "current_avatar_url": "https://example.com/avatar",
            "current_ttl_msec": 86400000, "current_screen_capture_blocking_enabled": true});
        let added = s.call("prepareGroupMembers", &args.to_string()).unwrap();
        assert_eq!(added["conversation_id"], "g555");
        assert_eq!(added["participant_keys"].as_array().unwrap().len(), 2);
        assert!(added.get("conversation_key").is_none());
        let signatures = added["action_signatures"].as_array().unwrap();
        assert_eq!(signatures.len(), 2);
        // The key change is verified from the payload the client submits, so
        // it is present alongside the member-add payload.
        assert!(signatures[0]["signature_payload"]
            .as_str()
            .unwrap()
            .starts_with("ConversationKeyChangeEvent,"));
        let add = &signatures[1];
        let payload = add["signature_payload"].as_str().unwrap();
        assert!(payload.starts_with("GroupChangeEvent.GroupMemberAddChange,"));
        assert!(payload.contains(",g555,new-member,"));
        assert!(payload.contains(",encrypted-title,https://example.com/avatar,86400000,"));
        assert!(payload.ends_with(",true"));
        // An invite-enabled group binds the invite triple after the screen
        // state, matching what the private client submits and the server
        // re-derives; a group without an invite link must not gain a trailer.
        let mut invited = args.clone();
        invited["current_invite_url"] = json!("https://x.com/i/chat/group_join/g555/invite0001");
        let with_invite = s.call("prepareGroupMembers", &invited.to_string()).unwrap();
        let invite_payload = with_invite["action_signatures"].as_array().unwrap()[1]["signature_payload"]
            .as_str().unwrap();
        assert!(invite_payload.ends_with(",true,https://x.com/i/chat/group_join/g555/invite0001,null,null"));
        let signature = base64::engine::general_purpose::STANDARD_NO_PAD
            .decode(add["signature"].as_str().unwrap()).unwrap();
        assert!(s.chat.verify(v["signing_public_b64"].as_str().unwrap(), &signature, payload.as_bytes()).unwrap());
        assert!(s.media_keys.get("g555").is_none(), "an unaccepted prepared key must not be activated");
        let rotated = s.call("prepareKeyRotation", &json!({"conversation_id": "g555",
            "public_keys": public_keys}).to_string()).unwrap();
        assert_eq!(rotated["conversation_id"], "g555");
        assert_eq!(rotated["action_signatures"].as_array().unwrap().len(), 1);
        assert!(rotated.get("conversation_key").is_none());
        assert!(s.call("prepareKeyRotation", &json!({"public_keys": public_keys}).to_string()).is_err());
        let mut invalid = args.clone(); invalid["new_member_ids"] = json!([]);
        assert!(s.call("prepareGroupMembers", &invalid.to_string()).is_err());
        s.call("lock", "{}").unwrap();
        assert!(s.call("prepareGroupMembers", &args.to_string()).is_err());
    }

    #[test]
    fn group_avatar_files_authenticate_with_retained_keys_without_overwriting_on_failure() {
        let v = fixture(); let mut s = loaded(&v);
        let conv = v["event_conversation_id"].as_str().unwrap();
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let key = s.media_keys[&conv.replace(':', "-")].values().next().unwrap().clone();
        // Include non-UTF8 bytes and several chunks to exercise binary framing.
        let mut image = vec![0x89, b'P', b'N', b'G', 13, 10, 26, 10];
        image.extend((0..5000).map(|index| (index % 256) as u8));
        let ciphertext = s.chat.encrypt_stream(&image, &key).unwrap();
        let stem = format!("harmonyx-avatar-test-{}-{}", std::process::id(),
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos());
        let cipher_path = std::env::temp_dir().join(format!("{stem}.enc"));
        let image_path = std::env::temp_dir().join(format!("{stem}.png"));
        std::fs::write(&cipher_path, &ciphertext).unwrap();
        s.media_keys.get_mut(&conv.replace(':', "-")).unwrap()
            .insert("9999999999999999999".into(), XChatConversationKey::from_bytes(vec![7;32]).unwrap());
        let args = json!({"conversation_id": conv, "input_path": cipher_path,
            "output_path": image_path, "key_version": "missing-hint"});
        let result = s.call("decryptMetadataFile", &args.to_string()).unwrap();
        assert_eq!(std::fs::read(&image_path).unwrap(), image);
        assert_eq!(result["media_bytes"], image.len());
        assert_ne!(result["key_version"], "9999999999999999999");
        let mut corrupt = ciphertext; let last = corrupt.len() - 1; corrupt[last] ^= 1;
        std::fs::write(&cipher_path, &corrupt).unwrap();
        assert!(s.call("decryptMetadataFile", &args.to_string()).is_err());
        assert_eq!(std::fs::read(&image_path).unwrap(), image);
        std::fs::write(&cipher_path, &corrupt[..24]).unwrap();
        assert!(s.call("decryptMetadataFile", &args.to_string()).is_err());
        let mut wrong = args.clone(); wrong["conversation_id"] = json!("g-another");
        assert!(s.call("decryptMetadataFile", &wrong.to_string()).is_err());
        s.call("lock", "{}").unwrap();
        assert!(s.call("decryptMetadataFile", &args.to_string()).is_err());
        std::fs::remove_file(cipher_path).unwrap(); std::fs::remove_file(image_path).unwrap();
    }

    #[test]
    fn group_actions_match_official_payloads_and_verify_through_the_event_parser() {
        let v = fixture(); let mut s = loaded(&v);
        let cases = vec![
            (json!({"action":"removeMembers","user_ids":["11","12"]}), "GroupChangeEvent.GroupMemberRemoveChange", ",11,12"),
            (json!({"action":"addAdmin","user_ids":["11"]}), "GroupChangeEvent.GroupAdminAddChange", ",11"),
            (json!({"action":"removeAdmin","user_ids":["11"]}), "GroupChangeEvent.GroupAdminRemoveChange", ",11"),
            (json!({"action":"title","text":"cipherTitle","key_version":"42"}), "GroupChangeEvent.GroupTitleChange", ",42,cipherTitle"),
            (json!({"action":"avatar","text":"https://example.com/avatar","key_version":"42","for_key_rotation":true}), "GroupChangeEvent.GroupAvatarUrlChange", ",42,https://example.com/avatar"),
            (json!({"action":"description","text":"cipherDescription","key_version":"42"}), "GroupChangeEvent.GroupDescriptionChange", ",42,cipherDescription"),
            (json!({"action":"inviteEnable","text":"https://x.com/i/chat/group_join/g555/token","expires_at_msec":1234,"affiliate_id":"11"}), "GroupChangeEvent.GroupInviteEnable", ",https://x.com/i/chat/group_join/g555/token,1234,11"),
            (json!({"action":"permissions","permissions":{"add_member":true,"edit_group_info":false,"send_message":true,"start_call":false,"edit_message_ttl":true,"block_screen_capture":false}}), "GroupChangeEvent.GroupAdminSettingsChange", ",true,false,true,false,true,false"),
            (json!({"action":"ttl","ttl_msec":86400000}), "ConversationMetadataChangeEvent.MessageDurationChange", ",86400000"),
            (json!({"action":"removeTtl","ttl_msec":86400000}), "ConversationMetadataChangeEvent.MessageDurationRemove", ""),
            (json!({"action":"screenCapture","enabled":true}), "ConversationMetadataChangeEvent.EnableScreenCaptureBlocking", ""),
            (json!({"action":"screenCapture","enabled":false}), "ConversationMetadataChangeEvent.DisableScreenCaptureBlocking", ""),
        ];
        let signing_keys: Vec<SigningKeyEntry> = serde_json::from_value(json!([signing_key(&v)])).unwrap();
        for (mut args, event_type, trailer) in cases {
            args["conversation_id"] = json!("g555");
            let result = s.call("prepareGroupAction", &args.to_string()).unwrap();
            let signature: chat_xdk_core::signatures::ActionSignature = serde_json::from_value(result["action_signatures"][0].clone()).unwrap();
            let expected = format!("{},{},{},g555{}", event_type, signature.message_id,
                v["event_sender_id"].as_str().unwrap(), trailer);
            let bytes = base64::engine::general_purpose::STANDARD_NO_PAD.decode(&signature.signature).unwrap();
            assert!(s.chat.verify(v["signing_public_b64"].as_str().unwrap(), &bytes, expected.as_bytes()).unwrap(), "{event_type}");
            let framed = chat_xdk_core::internals::frame_action_signature(&signature,
                v["event_sender_id"].as_str().unwrap(), "g555").unwrap();
            let event = s.chat.decrypt_event(&framed, &HashMap::new(), &signing_keys).unwrap();
            assert!(match event { Event::GroupChange(g) => g.verified, Event::SettingsChange(settings) => settings.verified, _ => false });
        }
        for action in ["inviteDisable", "leave"] {
            let result = s.call("prepareGroupAction", &json!({"conversation_id":"g555","action":action}).to_string()).unwrap();
            let signature: chat_xdk_core::signatures::ActionSignature = serde_json::from_value(result["action_signatures"][0].clone()).unwrap();
            let event_type = if action == "leave" { "GroupChangeEvent.GroupMemberRemoveChange" } else { "GroupChangeEvent.GroupInviteDisable" };
            let sender = v["event_sender_id"].as_str().unwrap();
            let expected = format!("{},{},{},g555,{}", event_type, signature.message_id, sender, sender);
            let bytes = base64::engine::general_purpose::STANDARD_NO_PAD.decode(&signature.signature).unwrap();
            assert!(s.chat.verify(v["signing_public_b64"].as_str().unwrap(), &bytes, expected.as_bytes()).unwrap());
        }
        assert!(s.call("prepareGroupAction", &json!({"conversation_id":"g555","action":"title","text":"with,comma","key_version":"42"}).to_string()).is_err());
        assert!(s.call("prepareGroupAction", &json!({"conversation_id":"g555","action":"removeMembers","user_ids":[]}).to_string()).is_err());
        assert!(s.call("prepareGroupAction", &json!({"conversation_id":"g555","action":"unsupported"}).to_string()).is_err());
        s.call("lock", "{}").unwrap();
        assert!(s.call("prepareGroupAction", &json!({"conversation_id":"g555","action":"inviteDisable"}).to_string()).is_err());
    }

    #[test]
    fn staged_group_add_reuses_the_prepared_key_for_metadata_and_avatar_without_activating_it() {
        let v = fixture(); let mut s = loaded(&v);
        let public_keys = json!([
            {"user_id":v["event_sender_id"],"public_key":v["identity_public_b64"],"key_version":v["event_recipient_key_version"]},
            {"user_id":"new-member","public_key":v["identity_public_b64"],"key_version":"1"}
        ]);
        let rotation = s.call("prepareKeyRotation", &json!({"conversation_id":"g555","public_keys":public_keys}).to_string()).unwrap();
        let version = rotation["conversation_key_version"].as_str().unwrap();
        let key = s.pending_rotations["g555"].conversation_key.as_ref().unwrap().clone();
        let title = s.call("encryptMetadata", &json!({"conversation_id":"g555","text":"新群名","key_version":version}).to_string()).unwrap();
        let description = s.call("encryptMetadata", &json!({"conversation_id":"g555","text":"新的群简介","key_version":version}).to_string()).unwrap();
        assert_eq!(s.chat.decrypt(title["ciphertext"].as_str().unwrap(), &key).unwrap(), "新群名");
        let stem = format!("harmonyx-staged-avatar-{}", std::process::id());
        let plain_path = std::env::temp_dir().join(format!("{stem}.png"));
        let encrypted_path = std::env::temp_dir().join(format!("{stem}.enc"));
        let image = vec![0x89, b'P', b'N', b'G', 255, 0, 1];
        std::fs::write(&plain_path, &image).unwrap();
        s.call("encryptGroupMedia", &json!({"conversation_id":"g555","key_version":version,
            "input_path":plain_path,"output_path":encrypted_path}).to_string()).unwrap();
        assert_eq!(s.chat.decrypt_stream(&std::fs::read(&encrypted_path).unwrap(), &key).unwrap(), image);
        let args = json!({"conversation_id":"g555","public_keys":public_keys,"key_version":version,
            "new_member_ids":["new-member"],"current_member_ids":[v["event_sender_id"]],"current_admin_ids":[v["event_sender_id"]],
            "current_title":title["ciphertext"],"current_description":description["ciphertext"],"current_avatar_url":"https://example.com/new-avatar"});
        let added = s.call("prepareGroupMembers", &args.to_string()).unwrap();
        assert_eq!(added["conversation_key_version"], version);
        assert_eq!(added["participant_keys"], rotation["participant_keys"]);
        assert_eq!(added["action_signatures"][0], rotation["action_signatures"][0]);
        assert_eq!(added["action_signatures"].as_array().unwrap().len(), 2);
        assert!(s.media_keys.get("g555").is_none());
        assert!(s.chat.encrypt_message(EncryptMessageParams::new("g555", "must not send yet")).is_err());
        let add_signature: chat_xdk_core::signatures::ActionSignature = serde_json::from_value(added["action_signatures"][1].clone()).unwrap();
        let event = chat_xdk_core::internals::frame_action_signature(&add_signature,
            v["event_sender_id"].as_str().unwrap(), "g555").unwrap();
        let signing_keys: Vec<SigningKeyEntry> = serde_json::from_value(json!([signing_key(&v)])).unwrap();
        assert!(matches!(s.chat.decrypt_event(&event, &HashMap::new(), &signing_keys).unwrap(), Event::GroupChange(g) if g.verified));
        let mut invalid = args.clone(); invalid["key_version"] = json!("wrong");
        assert!(s.call("prepareGroupMembers", &invalid.to_string()).is_err());
        s.call("lock", "{}").unwrap(); assert!(s.pending_rotations.is_empty());
        std::fs::remove_file(plain_path).unwrap(); std::fs::remove_file(encrypted_path).unwrap();
    }

    #[test]
    fn read_receipt_roundtrips_as_signed_non_message_content() {
        let v = fixture(); let mut s = loaded(&v);
        let conv = v["event_conversation_id"].as_str().unwrap();
        s.call("decrypt", &json!({"events": [v["event_key_change_b64"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let payload = s.chat.encrypt_read_receipt(conv, "9007199254740993").unwrap();
        let event = chat_xdk_core::internals::frame_send_payload(&payload, &payload.message_id,
            v["event_sender_id"].as_str().unwrap(), conv).unwrap();
        let decoded = s.call("decrypt", &json!({"events": [event], "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        assert_eq!(decoded["messages"][0]["content"]["content_type"], "MarkRead");
        assert_eq!(decoded["messages"][0]["verified"], true);
        assert!(s.chat.encrypt_read_receipt(conv, "").is_err());
        s.call("lock", "{}").unwrap();
        assert!(s.call("encryptRead", &json!({"conversation_id": conv, "sequence_id":"1"}).to_string()).is_err());
    }

    #[test]
    fn plaintext_read_receipt_is_signed_without_a_conversation_key() {
        let v = fixture(); let mut s = loaded(&v);
        let conv = v["event_conversation_id"].as_str().unwrap();
        let payload = s.call("preparePlainRead", &json!({"conversation_id": conv,
            "sequence_id": "9007199254740993"}).to_string()).unwrap();
        let decoded = s.call("decrypt", &json!({"events": [payload["encoded_message_event"]],
            "signing_keys": [signing_key(&v)]}).to_string()).unwrap();
        let read = &decoded["messages"][0];
        assert_eq!(read["type"], "read"); assert_eq!(read["verified"], true);
        assert_eq!(read["id"], payload["message_id"]);
        assert_eq!(read["seenUntilId"], "9007199254740993");
        s.call("lock", "{}").unwrap();
        assert!(s.call("preparePlainRead", &json!({"conversation_id": conv,
            "sequence_id": "9007199254740993"}).to_string()).is_err());
    }

    #[test]
    fn conversation_delete_signature_binds_the_account_and_conversation() {
        let v = fixture(); let mut s = loaded(&v);
        let conv = v["event_conversation_id"].as_str().unwrap();
        let result = s.call("prepareConversationDelete", &json!({"conversation_id":conv}).to_string()).unwrap();
        let action = &result["action_signatures"][0];
        let payload = format!("ConversationDeleteEvent,{},{},{}", action["message_id"].as_str().unwrap(),
            v["event_sender_id"].as_str().unwrap(), conv);
        let signature = B64.decode(action["signature"].as_str().unwrap()).unwrap();
        assert!(s.chat.verify(v["signing_public_b64"].as_str().unwrap(), &signature, payload.as_bytes()).unwrap());
        assert!(!s.chat.verify(v["signing_public_b64"].as_str().unwrap(), &signature, b"changed conversation").unwrap());
        assert!(s.call("prepareConversationDelete", "{\"conversation_id\":\"\"}").is_err());
    }

    #[test]
    fn prepared_conversation_and_delete_actions_do_not_export_raw_keys() {
        let v = fixture(); let mut s = loaded(&v);
        let result = s.call("prepareConversation", &json!({"public_keys": [
            {"user_id": v["event_sender_id"], "public_key": v["identity_public_b64"], "key_version": "1"},
            {"user_id": "another-user", "public_key": v["identity_public_b64"], "key_version": "1"}
        ]}).to_string()).unwrap();
        assert_eq!(result["participant_keys"].as_array().unwrap().len(), 2);
        assert!(result.get("conversation_key").is_none());
        assert!(result.get("raw_conversation_key").is_none());
        let delete = s.call("prepareDelete", &json!({"conversation_id": v["event_conversation_id"], "sequence_ids": ["9007199254740993"],
            "delete_for_all": false}).to_string()).unwrap();
        assert!(!delete["action_signatures"][0]["signature"].as_str().unwrap().is_empty());
    }
}

