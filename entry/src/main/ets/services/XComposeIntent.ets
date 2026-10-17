// Builds the documented X Web Intent used to hand a draft to X's own
// composer. The user completes the publication in X; this app never submits
// an internal X web mutation on their behalf.
const X_POST_INTENT_BASE: string = 'https://x.com/intent/tweet';

function isPostId(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  for (let index: number = 0; index < value.length; index++) {
    const code: number = value.charCodeAt(index);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
}

// `text` and `in_reply_to` are the two Web Intent parameters needed by the
// composer. Keeping the reply id numeric prevents an arbitrary query fragment
// from being appended when a post is opened from an external deep link.
export function buildXPostIntentUrl(text: string, replyToId: string): string {
  let url: string = X_POST_INTENT_BASE + '?text=' + encodeURIComponent(text);
  if (isPostId(replyToId)) {
    url += '&in_reply_to=' + encodeURIComponent(replyToId);
  }
  return url;
}
