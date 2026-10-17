// MeoW's HTTP status is normally 200 even when its business status is an error.
// https://www.chuckfang.com/MeoW/api_doc.html
export async function sendMeow(nickname, notice, fetcher = fetch) {
  const response = await fetcher(`https://api.chuckfang.com/${encodeURIComponent(nickname)}`, {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(15000),
    headers: { 'content-type': 'application/json' }, body: JSON.stringify(notice)
  });
  let body;
  try { body = await response.json(); } catch { throw new Error('meow_invalid_response'); }
  if (!response.ok || body?.status !== 200) {
    const error = new Error('meow_rejected');
    error.status = Number(body?.status) || response.status;
    throw error;
  }
}

// X payloads vary between DM, encrypted-chat and social notifications. Missing
// preview text is legitimate. Never request chat recovery keys from the phone.
export function notificationText(payload, previews = false) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) throw new Error('invalid_payload');
  if (!previews) return { title: 'Harmony X', msg: '你有新的 X 消息，请打开 Harmony X 查看。', url: 'https://x.com/messages' };
  const notification = payload.notification && typeof payload.notification === 'object' ? payload.notification : payload;
  const text = typeof notification.body === 'string' ? notification.body :
    typeof notification.text === 'string' ? notification.text : '';
  return {
    title: typeof notification.title === 'string' ? notification.title.slice(0, 120) : 'Harmony X',
    msg: text.slice(0, 1500) || '你有新的 X 消息，请打开 Harmony X 查看。',
    url: 'https://x.com/messages'
  };
}
