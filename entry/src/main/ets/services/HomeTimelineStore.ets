import type { CommunityRow } from '../models/Community';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { Tweet, MediaAttachment, ListRow } from '../models/Tweet';

export const STORAGE_KEY_HOME_TIMELINE_REVISION: string = 'harmonyx.home_timeline_revision';
export const FOLLOWING_SORT_LATEST: number = 0;
export const FOLLOWING_SORT_TRENDING: number = 1;
const PAUSE_DURATION_MS: number = 24 * 60 * 60 * 1000;

export class TimelineTopic {
  id: string;
  tag: string = '';
  listId: string = '';
  communityId: string = '';
  localGroupId: string = '';
  localGroupVersion: number = 0;
  iconText: string = '';
  bannerUrl: string = '';
  rankingMode: string = 'Recency';
  displayTitle: string = '';
  title: Resource;
  icon: Resource;
  query: string;
  keywords: string[];
  pausable: boolean;

  constructor(id: string, title: Resource, icon: Resource, query: string,
    keywords: string[], pausable: boolean = true) {
    this.id = id;
    this.title = title;
    this.icon = icon;
    this.query = query;
    this.keywords = keywords;
    this.pausable = pausable;
  }
}

class TopicPause {
  id: string;
  expiresAt: number;

  constructor(id: string, expiresAt: number) {
    this.id = id;
    this.expiresAt = expiresAt;
  }
}

class PausedTopicMatcher {
  video: boolean;
  patterns: RegExp[] = [];
  keywords: string[] = [];

  constructor(topic: TimelineTopic) {
    this.video = topic.id === 'video';
    for (const keyword of topic.keywords) {
      if (/^[a-z]+$/.test(keyword)) {
        this.patterns.push(new RegExp('\\b' + keyword + '\\b', 'i'));
      } else {
        this.keywords.push(keyword);
      }
    }
  }
}

export class HomeTimelineStore {
  private matcherKey: string = '';
  private matchers: PausedTopicMatcher[] = [];
  private pauses: TopicPause[] = [];
  private pins: string[] = [];
  private listTopics: TimelineTopic[] = [];
  private communityTopics: TimelineTopic[] = [];
  private localGroupTopics: TimelineTopic[] = [];
  private localGroupPins: string[] = [];
  private sourceOrder: string[] = [];
  private accountTopics: TimelineTopic[] | null = null;
  private accountPins: string[] = [];
  private order: number = FOLLOWING_SORT_LATEST;
  private topics: TimelineTopic[] = [
    new TimelineTopic('football', $r('app.string.timeline_topic_football'), $r('sys.symbol.ball_fill'),
      '(football OR soccer OR 足球)', ['足球', 'football', 'soccer'], false),
    new TimelineTopic('economy', $r('app.string.timeline_topic_economy'), $r('sys.symbol.waveform_path_ecg_square'),
      '(stocks OR economy OR 股票 OR 经济)', ['股票', '经济', 'stocks', 'economy'], false),
    new TimelineTopic('politics', $r('app.string.timeline_topic_politics'), $r('sys.symbol.building'),
      '(politics OR election OR 政治)', ['政治', '选举', 'politics', 'election', 'parliament']),
    new TimelineTopic('conflict', $r('app.string.timeline_topic_conflict'), $r('sys.symbol.list_bullet_square'),
      '(Iran OR 伊朗)', ['伊朗', 'iran'], false),
    new TimelineTopic('sports', $r('app.string.timeline_topic_sports'), $r('sys.symbol.basketball'),
      '(sports OR 体育)', ['体育', '足球', '篮球', 'sports', 'football', 'soccer', 'basketball']),
    new TimelineTopic('business', $r('app.string.timeline_topic_business'), $r('sys.symbol.briefcase'),
      '(business OR finance OR 商业 OR 金融)', ['商业', '金融', '股票', '经济', 'business', 'finance', 'stocks', 'economy']),
    new TimelineTopic('science', $r('app.string.timeline_topic_science'), $r('sys.symbol.lightbulb_1'),
      '(science OR 科学)', ['科学', 'science'], false),
    new TimelineTopic('technology', $r('app.string.timeline_topic_technology'), $r('sys.symbol.keyboard_square'),
      '(technology OR 科技)', ['科技', '芯片', 'technology', 'tech', 'chip']),
    new TimelineTopic('entertainment', $r('app.string.timeline_topic_entertainment'), $r('sys.symbol.film'),
      '(entertainment OR art OR 娱乐 OR 艺术)', ['娱乐', '艺术', '电影', 'entertainment', 'cinema', 'art']),
    new TimelineTopic('ai', $r('app.string.timeline_topic_ai'), $r('sys.symbol.keyboard_square'),
      '(AI OR 人工智能)', ['人工智能', '大模型', 'ai', 'openai', 'chatgpt', 'gemini', 'claude']),
    new TimelineTopic('gaming', $r('app.string.timeline_topic_gaming'), $r('sys.symbol.gamecontroller'),
      '(gaming OR esports OR 游戏)', ['游戏', '电竞', 'gaming', 'esports']),
    new TimelineTopic('crypto', $r('app.string.timeline_topic_crypto'), $r('sys.symbol.yuansign_circle'),
      '(crypto OR bitcoin OR 加密货币)', ['加密货币', '比特币', 'crypto', 'bitcoin', 'ethereum']),
    new TimelineTopic('video', $r('app.string.timeline_topic_video'), $r('sys.symbol.video'),
      'filter:videos', [])
  ];

  allTopics(): TimelineTopic[] {
    return this.accountTopics ?? this.topics;
  }

  legacyTopics(): TimelineTopic[] { return this.topics; }
  legacyPins(): string[] { return this.pins.slice(); }

  setAccountTopics(topics: TimelineTopic[], pins: string[]): void {
    this.accountTopics = topics; this.accountPins = pins.slice(); this.publish();
  }

  tagSource(tag: string, name: string, tabLabel: string, iconUrl: string): TimelineTopic {
    const topic: TimelineTopic = new TimelineTopic('tag:' + tag, $r('app.string.timeline_title'),
      $r('sys.symbol.list_bullet_square'), '', [], false);
    topic.tag = tag; topic.displayTitle = tabLabel || name; topic.bannerUrl = iconUrl;
    return topic;
  }

  topicById(id: string): TimelineTopic | null {
    const accountTopic: TimelineTopic | undefined = this.accountTopics?.find((topic: TimelineTopic): boolean => topic.id === id);
    if (accountTopic !== undefined) { return accountTopic; }
    for (let i: number = 0; i < this.topics.length; i++) {
      if (this.topics[i].id === id) {
        return this.topics[i];
      }
    }
    return [...this.listTopics, ...this.communityTopics, ...this.localGroupTopics].find((topic: TimelineTopic): boolean => topic.id === id) ?? null;
  }

  pinnedTopics(): TimelineTopic[] {
    const topics: TimelineTopic[] = [];
    const pins: string[] = this.accountTopics === null ? this.pins : this.accountPins;
    for (let i: number = 0; i < pins.length; i++) {
      const topic: TimelineTopic | null = this.topicById(pins[i]);
      if (topic !== null) {
        topics.push(topic);
      }
    }
    const combined: TimelineTopic[] = [...topics, ...this.listTopics, ...this.communityTopics,
      ...this.localGroupTopics.filter((topic: TimelineTopic): boolean => this.localGroupPins.indexOf(topic.id) >= 0)];
    return combined.sort((a: TimelineTopic, b: TimelineTopic): number => {
      const ai: number = this.sourceOrder.indexOf(a.id); const bi: number = this.sourceOrder.indexOf(b.id);
      return (ai < 0 ? this.sourceOrder.length : ai) - (bi < 0 ? this.sourceOrder.length : bi);
    });
  }

  listSource(row: ListRow): TimelineTopic {
    const topic: TimelineTopic = new TimelineTopic('list:' + row.id, $r('app.string.lists_title'),
      $r('sys.symbol.list_bullet_square'), '', [], false);
    topic.listId = row.id; topic.displayTitle = row.name; topic.bannerUrl = row.bannerUrl ?? '';
    return topic;
  }

  communitySource(row: CommunityRow, ranking: string = 'Recency'): TimelineTopic {
    const topic: TimelineTopic = new TimelineTopic('community:' + row.id, $r('app.string.communities_title'),
      $r('sys.symbol.person_2_fill'), '', [], false);
    topic.communityId = row.id; topic.displayTitle = row.name; topic.bannerUrl = row.bannerUrl;
    topic.rankingMode = ranking; return topic;
  }

  setListTopics(rows: ListRow[]): void {
    this.listTopics = rows.map((row: ListRow): TimelineTopic => this.listSource(row)); this.publish();
  }

  setLocalGroupTopics(topics: TimelineTopic[], pins: string[]): void {
    this.localGroupTopics = topics; this.localGroupPins = pins.slice(); this.publish();
  }

  setCommunityTopics(rows: CommunityRow[], rankings: string[], order: string[]): void {
    this.communityTopics = rows.map((row: CommunityRow, index: number): TimelineTopic =>
      this.communitySource(row, rankings[index] ?? 'Recency'));
    this.sourceOrder = order.slice(); this.publish();
  }

  pauseTopics(): TimelineTopic[] {
    return this.topics.filter((topic: TimelineTopic): boolean => topic.pausable);
  }

  load(context: common.Context): void {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_home_timelines' });
      const savedPauses: string = store.getSync('pauses', '') as string;
      const savedPins: string = store.getSync('pins', '') as string;
      this.order = store.getSync('order', FOLLOWING_SORT_LATEST) === FOLLOWING_SORT_TRENDING ?
        FOLLOWING_SORT_TRENDING : FOLLOWING_SORT_LATEST;
      this.pauses = [];
      const items: string[] = savedPauses.split(';');
      for (let i: number = 0; i < items.length; i++) {
        const pair: string[] = items[i].split(':');
        if (pair.length === 2 && this.topics.some((topic: TimelineTopic): boolean => topic.id === pair[0])) {
          const expiresAt: number = Number(pair[1]);
          if (Number.isFinite(expiresAt) && expiresAt > Date.now()) {
            this.pauses.push(new TopicPause(pair[0], expiresAt));
          }
        }
      }
      this.pins = [];
      const pins: string[] = savedPins.split(';');
      for (let i: number = 0; i < pins.length; i++) {
        if (this.topicById(pins[i]) !== null && this.pins.indexOf(pins[i]) < 0) {
          this.pins.push(pins[i]);
        }
      }
      this.publish();
    } catch (error) {
      // Keep the current session's settings when preferences are unavailable.
    }
  }

  isPaused(id: string): boolean {
    return this.pauses.some((pause: TopicPause): boolean => pause.id === id && pause.expiresAt > Date.now());
  }

  isPinned(id: string): boolean {
    return this.localGroupPins.indexOf(id) >= 0 || (this.accountTopics === null ? this.pins : this.accountPins).indexOf(id) >= 0 || [...this.listTopics, ...this.communityTopics]
      .some((topic: TimelineTopic): boolean => topic.id === id);
  }

  followingOrder(): number {
    return this.order;
  }

  setPaused(context: common.Context, id: string, paused: boolean): boolean {
    const previous: TopicPause[] = this.pauses;
    this.pauses = this.pauses.filter((pause: TopicPause): boolean => pause.id !== id && pause.expiresAt > Date.now());
    if (paused) {
      this.pauses.push(new TopicPause(id, Date.now() + PAUSE_DURATION_MS));
    }
    if (this.save(context)) {
      return true;
    }
    this.pauses = previous;
    return false;
  }

  resetPauses(context: common.Context): boolean {
    const previous: TopicPause[] = this.pauses;
    this.pauses = [];
    if (this.save(context)) {
      return true;
    }
    this.pauses = previous;
    return false;
  }

  setPinned(context: common.Context, id: string, pinned: boolean): boolean {
    if (this.isPinned(id) === pinned) {
      return true;
    }
    const previous: string[] = this.pins;
    this.pins = this.pins.filter((pin: string): boolean => pin !== id);
    if (pinned) {
      this.pins.push(id);
    }
    if (this.save(context)) {
      return true;
    }
    this.pins = previous;
    return false;
  }

  setFollowingOrder(context: common.Context, order: number): boolean {
    const previous: number = this.order;
    this.order = order === FOLLOWING_SORT_TRENDING ? FOLLOWING_SORT_TRENDING : FOLLOWING_SORT_LATEST;
    if (this.save(context)) {
      return true;
    }
    this.order = previous;
    return false;
  }

  nextPauseExpiry(): number {
    let next: number = 0;
    for (let i: number = 0; i < this.pauses.length; i++) {
      if (this.pauses[i].expiresAt > Date.now() && (next === 0 || this.pauses[i].expiresAt < next)) {
        next = this.pauses[i].expiresAt;
      }
    }
    return next;
  }

  publish(): void {
    const revision: number = AppStorage.get<number>(STORAGE_KEY_HOME_TIMELINE_REVISION) ?? 0;
    AppStorage.setOrCreate<number>(STORAGE_KEY_HOME_TIMELINE_REVISION, revision + 1);
  }

  present(tweets: Tweet[], forYou: boolean): Tweet[] {
    if (forYou) {
      const matchers: PausedTopicMatcher[] = this.pausedMatchers();
      return matchers.length === 0 ? tweets :
        tweets.filter((tweet: Tweet): boolean => !this.hiddenByTopic(tweet, matchers));
    }
    const ordered: Tweet[] = tweets.slice();
    ordered.sort((left: Tweet, right: Tweet): number => {
      if (this.order === FOLLOWING_SORT_TRENDING) {
        const difference: number = this.engagement(right) - this.engagement(left);
        if (difference !== 0) {
          return difference;
        }
      }
      const difference: number = Date.parse(right.createdAt) - Date.parse(left.createdAt);
      return Number.isFinite(difference) ? difference : 0;
    });
    return ordered;
  }

  private engagement(tweet: Tweet): number {
    return tweet.metrics.likeCount + tweet.metrics.repostCount + tweet.metrics.replyCount;
  }

  private pausedMatchers(): PausedTopicMatcher[] {
    const now: number = Date.now();
    const active: TopicPause[] = this.pauses.filter((pause: TopicPause): boolean => pause.expiresAt > now);
    const key: string = active.map((pause: TopicPause): string => pause.id).join('|');
    if (key === this.matcherKey) { return this.matchers; }
    this.matcherKey = key;
    this.matchers = [];
    for (const pause of active) {
      const topic: TimelineTopic | null = this.topicById(pause.id);
      if (topic !== null) { this.matchers.push(new PausedTopicMatcher(topic)); }
    }
    return this.matchers;
  }

  private hiddenByTopic(tweet: Tweet, matchers: PausedTopicMatcher[]): boolean {
    const text: string = (tweet.text + '\n' + (tweet.quotedTweet?.text ?? '')).toLowerCase();
    for (const matcher of matchers) {
      if (matcher.video && this.hasVideo(tweet)) {
        return true;
      }
      for (const pattern of matcher.patterns) {
        if (pattern.test(text)) { return true; }
      }
      for (const keyword of matcher.keywords) {
        if (text.indexOf(keyword) >= 0) { return true; }
      }
    }
    return false;
  }

  private hasVideo(tweet: Tweet): boolean {
    return (tweet.attachments ?? []).some((attachment: MediaAttachment): boolean => attachment.type === 'video' ||
      attachment.type === 'animated_gif') || (tweet.quotedTweet?.attachments ?? []).some((attachment: MediaAttachment): boolean =>
      attachment.type === 'video' || attachment.type === 'animated_gif');
  }

  private save(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_home_timelines' });
      store.putSync('pauses', this.pauses.map((pause: TopicPause): string =>
        pause.id + ':' + pause.expiresAt.toString()).join(';'));
      store.putSync('pins', this.pins.join(';'));
      store.putSync('order', this.order);
      store.flushSync();
      this.publish();
      return true;
    } catch (error) {
      return false;
    }
  }
}

export const homeTimelineStore: HomeTimelineStore = new HomeTimelineStore();
