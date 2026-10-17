// Community models decoded from X's private GraphQL timeline payloads.
import type { TweetAuthor } from './Tweet';

export interface CommunityRule {
  id: string;
  name: string;
  description: string;
}

export interface CommunityTopic {
  id: string;
  name: string;
}

export interface CommunityRow {
  id: string;
  name: string;
  description: string;
  memberCount: number;
  moderatorCount: number;
  bannerUrl: string;
  joinPolicy: string;
  ruleCount: number;
  rules: CommunityRule[];
  joined: boolean;
  topicName?: string;
  topicId?: string;
  members?: TweetAuthor[];
  moderators?: TweetAuthor[];
  creator?: TweetAuthor;
  createdAt?: string;
  joinQuestion?: string;
}

export interface CommunityPage {
  communities: CommunityRow[];
  // A bottom cursor is supplied by the directory timelines. The membership
  // slice does not guarantee one, so callers treat an empty value as finite.
  nextToken: string;
}
