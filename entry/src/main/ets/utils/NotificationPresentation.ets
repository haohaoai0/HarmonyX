import type { AppNotification, Tweet, TweetAuthor } from '../models/Tweet';

export class NotificationTitleParts {
  before: string = '';
  actor: string = '';
  after: string = '';
}

export class NotificationPresentation {
  static isPost(notification: AppNotification): boolean {
    return (notification.kind === 'mention' || notification.kind === 'reply') && notification.targetPostId.length > 0;
  }

  static title(notification: AppNotification): string {
    if ((notification.actionText ?? '').length > 0) { return notification.actionText ?? ''; }
    const suffix: string = ' · ' + notification.postText;
    return notification.postText.length > 0 && notification.text.endsWith(suffix) ?
      notification.text.substring(0, notification.text.length - suffix.length) : notification.text;
  }

  static titleParts(notification: AppNotification): NotificationTitleParts {
    const parts: NotificationTitleParts = new NotificationTitleParts();
    const title: string = NotificationPresentation.title(notification);
    const name: string = notification.authorName;
    const at: number = name.length > 0 ? title.indexOf(name) : -1;
    if (at < 0) { parts.before = title; return parts; }
    parts.before = title.substring(0, at);
    parts.actor = name;
    parts.after = title.substring(at + name.length);
    return parts;
  }

  static excerpt(notification: AppNotification): string {
    const target: Tweet | undefined = (notification.targetPosts ?? []).find((post: Tweet): boolean =>
      post.id === notification.targetPostId);
    return target?.text ?? notification.postText;
  }

  static actors(notification: AppNotification): TweetAuthor[] {
    const actors: TweetAuthor[] = notification.actors ?? [];
    if (actors.length > 0) { return actors.slice(0, 6); }
    if (notification.authorName.length === 0 && notification.authorUsername.length === 0 &&
      notification.authorAvatarUrl.length === 0) { return []; }
    return [{ id: notification.authorId, name: notification.authorName, username: notification.authorUsername,
      avatarUrl: notification.authorAvatarUrl, avatarColor: '#1D9BF0',
      verified: notification.fromVerifiedAccount === true, verifiedType: notification.authorVerifiedType,
      avatarShape: notification.authorAvatarShape }];
  }
}
