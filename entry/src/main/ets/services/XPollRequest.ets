import type { PollOption, TweetPoll } from '../models/Tweet';

export interface PollVoteRequest {
  path: string;
  body: string;
}

// Contract verified against X's saved official web bundle (cards.vote):
// host caps.x.com, /v2/capi/<binding.api minus capi://>, form-encoded fields.
export function pollVoteRequest(postId: string, poll: TweetPoll, choice: string): PollVoteRequest | null {
  const endpoint: string = poll.api.replace(/^capi:\/\//, '');
  if (!/^\d+$/.test(postId) || poll.cardUri.length === 0 || poll.cardName.length === 0 ||
    !/^[A-Za-z0-9_-]+(?:\/[A-Za-z0-9_.-]+)*$/.test(endpoint) || endpoint.indexOf('..') >= 0 ||
    !poll.options.some((option: PollOption): boolean => option.id === choice)) {
    return null;
  }
  const fields: Record<string, string> = {
    'twitter:string:card_uri': poll.cardUri,
    'twitter:long:original_tweet_id': postId,
    'twitter:string:response_card_name': poll.cardName,
    'twitter:string:cards_platform': 'Web-12',
    'twitter:string:selected_choice': choice
  };
  const pairs: string[] = [];
  const keys: string[] = Object.keys(fields);
  for (let i: number = 0; i < keys.length; i++) {
    pairs.push(encodeURIComponent(keys[i]) + '=' + encodeURIComponent(fields[keys[i]]));
  }
  return { path: '/v2/capi/' + endpoint, body: pairs.join('&') };
}
