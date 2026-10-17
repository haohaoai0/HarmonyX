import { DmMessage } from '../models/Tweet';

// ForEach reuses its builder's captured message while its key is unchanged.
// The provisional row has the final message ID but no server attachments.
// Rebuild on confirmation/attachment changes, without rebuilding on progress.
export function chatMessageRenderKey(message: DmMessage, pending: boolean, pinnedMessageId: string, index: number): string {
  const fields: string[] = [message.id, pending ? 'pending' : 'confirmed', message.text,
    String(message.read ?? false), JSON.stringify(message.attachments ?? []), message.keyVersion ?? '',
    JSON.stringify(message.reply ?? null), JSON.stringify(message.reactions ?? []),
    message.senderName, message.senderAvatarUrl, String(message.timestampMs), pinnedMessageId, String(index)];
  return JSON.stringify(fields);
}
