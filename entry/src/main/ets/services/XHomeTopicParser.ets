// Home's TagPinnedTimeline is distinct from a search query or a topic landing page.
export class HomeTopicTag {
  tag: string = '';
  name: string = '';
  tabLabel: string = '';
  iconUrl: string = '';
}

interface TagTimelineJson {
  __typename?: string;
  tag?: string;
  name?: string;
  tab_label?: string;
  icon_image_url?: string;
}

interface PinnableTopicsJson { pinnable_timelines?: TagTimelineJson[]; }
interface PinnedTopicsJson { pinned_timelines?: TagTimelineJson[]; }
interface HomeTopicsData {
  pinnable_timelines?: PinnableTopicsJson;
  pinned_timelines?: PinnedTopicsJson;
}
interface HomeTopicsJson { data?: HomeTopicsData; }

export class XHomeTopicParser {
  static validTag(tag: string): boolean {
    return typeof tag === 'string' && tag.trim().length > 0 && tag.length <= 512 && !/[\u0000-\u001f\u007f]/.test(tag);
  }

  static parse(body: string, pinned: boolean): HomeTopicTag[] | null {
    try {
      const json: HomeTopicsJson = JSON.parse(body) as HomeTopicsJson;
      const entries: TagTimelineJson[] | undefined = pinned ? json.data?.pinned_timelines?.pinned_timelines :
        json.data?.pinnable_timelines?.pinnable_timelines;
      // A missing field is a failed read, while an explicit empty directory is valid.
      if (!Array.isArray(entries)) { return null; }
      const rows: HomeTopicTag[] = [];
      for (const entry of entries) {
        if (entry === null || entry.__typename !== 'TagPinnedTimeline' ||
          typeof entry.tag !== 'string' || !XHomeTopicParser.validTag(entry.tag) ||
          typeof entry.name !== 'string' || entry.name.trim().length === 0 ||
          rows.some((row: HomeTopicTag): boolean => row.tag === entry.tag)) { continue; }
        const row: HomeTopicTag = new HomeTopicTag();
        row.tag = entry.tag; row.name = entry.name;
        row.tabLabel = typeof entry.tab_label === 'string' ? entry.tab_label : '';
        row.iconUrl = typeof entry.icon_image_url === 'string' && /^https:\/\//.test(entry.icon_image_url) ? entry.icon_image_url : '';
        rows.push(row);
      }
      return rows;
    } catch (error) { return null; }
  }
}
