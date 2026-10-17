import type { Tweet } from '../models/Tweet';

export function canPostAction(tweet: Tweet, action: string): boolean {
  const visibility = tweet.presentation?.visibility;
  if (visibility === undefined) { return true; }
  if (visibility.hidden) { return false; }
  const names: string[] = action === 'repost' ? ['repost', 'retweet'] : action === 'like' ? ['like', 'favorite'] : [action];
  return !visibility.actions.some((name: string): boolean => names.indexOf(name) >= 0);
}
