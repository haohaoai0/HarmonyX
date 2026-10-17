// XChat's APK conversation type orders one-to-one user IDs numerically and
// serializes them with a colon. Keep IDs as decimal strings: snowflakes may
// exceed Number's safe integer range.
export class XChatConversationId {
  static canonical(value: string): string {
    if (/^g\d+$/.test(value)) { return value; }
    if (!/^\d+[-:]\d+$/.test(value)) { return ''; }
    const users: string[] = value.replace('-', ':').split(':');
    const first: string = users[0].replace(/^0+(?=\d)/, '');
    const second: string = users[1].replace(/^0+(?=\d)/, '');
    const ordered: boolean = first.length < second.length ||
      (first.length === second.length && first <= second);
    return ordered ? first + ':' + second : second + ':' + first;
  }
}
