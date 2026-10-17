export interface XXAuthAnnouncement {
  id: string;
  title: string;
  content: string;
  priority: number;
  created_at?: string;
  updated_at?: string;
  status?: number;
}

export interface XXAuthArticle {
  id: string;
  title: string;
  content: string;
  sort_order?: number;
}

export interface XXAuthBanner {
  id: string;
  title?: string;
  image_url?: string;
  link_url?: string;
  sort_order?: number;
}

export interface XXAuthVersion {
  version: string;
  download_url?: string;
  change_log?: string;
  published_at?: string;
  channel?: string;
}

export interface XXAuthVersionCheck {
  is_latest?: boolean;
  latest_version?: string | XXAuthVersion;
  download_url?: string;
  change_log?: string;
  update_notice?: string;
  update_strategy?: string;
  force_update?: boolean;
  file_hash?: string;
}

// Optional application-owned variable, stored as JSON in XXAuth.
export interface XXAuthPopupConfig {
  enabled?: boolean;
  recommendation_enabled?: boolean;
  // One switch for the whole recommendation: popup, timeline post and the
  // comment-section rows. recommendation_enabled / post_enabled stay as
  // per-channel sub-switches.
  promotion_enabled?: boolean;
  announcements_enabled?: boolean;
  banners_enabled?: boolean;
  articles_enabled?: boolean;
  recommendation_title?: string;
  recommendation_description?: string;
  recommendation_icon?: string;
  post_enabled?: boolean;
  post_count?: number;
  post_comment_count?: number;
  // Bumping this makes every reader's "hide for 7 days" expire immediately,
  // without touching the copy.
  post_revision?: number;
}

export interface XXAuthVariable {
  key: string;
  value: Object;
}

export class XXAuthResult<T> {
  ok: boolean = false;
  status: number = 0;
  code: number = -1;
  data: T | undefined = undefined;
}

export class XXAuthPanel {
  id: string = '';
  kind: string = '';
  title: string = '';
  content: string = '';
  imageUrl: string = '';
  link: string = '';
  version: string = '';
  forced: boolean = false;
  repeat: boolean = false;
  fingerprint: string = '';
  subtitle: string = '';
  structuredRecommendation: boolean = false;
  reminderForced: boolean = false;
  recommendationAppId: string = '';
  snoozeTitle: string = '';
  snoozeMessage: string = '';
}
