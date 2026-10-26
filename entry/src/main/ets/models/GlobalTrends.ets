import type { Tweet } from './Tweet';

export class GlobalTrendCategory {
  id: string = '';
  title: string = '';
  imageUrl: string = '';
  path: string = '';
  topicId: string = '';
}

export class GlobalTrendTopic {
  id: string = '';
  title: string = '';
  path: string = '';
  query: string = '';
}

export class GlobalTrendCountry {
  code: string = '';
  name: string = '';
  flag: string = '';
  path: string = '';
  tagPath: string = '';
  timelinePath: string = '';
}

export class GlobalTrendsPage {
  categories: GlobalTrendCategory[] = [];
  topics: GlobalTrendTopic[] = [];
  countries: GlobalTrendCountry[] = [];
  tweets: Tweet[] = [];
  nextPath: string = '';
  timelineId: string = '';
  topicBrowserPath: string = '';
  tagBrowserPath: string = '';
  timelineBrowserPath: string = '';
}
