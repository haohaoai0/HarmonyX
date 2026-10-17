// Read only error fields, never notification/post text. Some X responses
// carry a rate-limit error in a successful HTTP response.
export class NotificationRateLimit {
  static reason(status: number, body: string, fallback: string = ''): string {
    let limited: boolean = status === 429;
    let reason: string = '';
    try {
      const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const errors: Object | undefined = root['errors'];
      if (errors instanceof Array) {
        for (let i: number = 0; i < errors.length; i++) {
          const value: Object = errors[i] as Object;
          if (value === null || typeof value !== 'object') { continue; }
          const error: Record<string, Object> = value as Record<string, Object>;
          const extensions: Record<string, Object> = (error['extensions'] ?? {}) as Record<string, Object>;
          const code: string = String(error['code'] ?? extensions['code'] ?? '');
          const message: string = NotificationRateLimit.text(error['message']);
          const matches: boolean = code === '88' || code === '429' ||
            NotificationRateLimit.matches(code) || NotificationRateLimit.matches(message);
          if (matches) { limited = true; reason = message; break; }
          if (reason.length === 0) { reason = message; }
        }
      }
      const detail: string = NotificationRateLimit.text(root['detail']);
      const title: string = NotificationRateLimit.text(root['title']);
      if (NotificationRateLimit.matches(detail) || NotificationRateLimit.matches(title)) { limited = true; }
      if (reason.length === 0) { reason = detail.length > 0 ? detail : title; }
    } catch (_error) {
      // A plain server error may still explain an HTTP 429.
      if (status === 429 && !body.trim().startsWith('<')) { reason = body.trim(); }
    }
    if (NotificationRateLimit.matches(fallback)) {
      limited = true;
      if (reason.length === 0 && fallback !== 'rate_limit_exceeded') { reason = fallback; }
    }
    if (!limited) { return ''; }
    const transport: string = 'HTTP ' + status;
    reason = reason.replace(/\s+/g, ' ').trim().substring(0, 200);
    return reason.length > 0 ? reason + ' · ' + transport : transport;
  }

  private static text(value: Object | undefined): string {
    return typeof value === 'string' ? value as string : '';
  }

  private static matches(value: string): boolean {
    return /rate[ _-]*limit|too[ _-]*many[ _-]*requests/i.test(value);
  }
}
