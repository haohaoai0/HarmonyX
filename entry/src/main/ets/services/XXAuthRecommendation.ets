import { XXAuthAnnouncement } from '../models/XXAuth';

export enum RecommendationMode {
  NORMAL = 'normal',
  FORCE = 'force',
  CLOSED = 'closed'
}

export interface RecommendationInfo {
  name: string;
  subtitle: string;
  description: string;
}

export interface RecommendationDescriptionSegment {
  text: string;
  highlighted: boolean;
}

// 仅成对的 // 标记生效，未闭合的标记按普通文字保留。
export function parseRecommendationDescription(content: string): RecommendationDescriptionSegment[] {
  const segments: RecommendationDescriptionSegment[] = [];
  const marker: string = '//';
  let cursor: number = 0;
  while (cursor < content.length) {
    const start: number = content.indexOf(marker, cursor);
    const end: number = start >= 0 ? content.indexOf(marker, start + marker.length) : -1;
    if (end < 0) {
      segments.push({ text: content.substring(cursor), highlighted: false });
      break;
    }
    if (start > cursor) {
      segments.push({ text: content.substring(cursor, start), highlighted: false });
    }
    if (end > start + marker.length) {
      segments.push({ text: content.substring(start + marker.length, end), highlighted: true });
    }
    cursor = end + marker.length;
  }
  return segments;
}

export interface RecommendationConfig extends RecommendationInfo {
  mode: RecommendationMode;
  iconUrl: string;
  storeUrl: string;
}

export interface RecommendationSnoozePrompt {
  title: string;
  message: string;
  storeUrl: string;
}


// 优先读取“当前为//不强制”这样的明确选择，前面可以保留指令说明。
export function parseRecommendationMode(content: string): RecommendationMode {
  const explicit: RegExpMatchArray | null = content.match(/当前(?:为|模式)?\s*[:：=]?\s*\/\/(强制提醒|强制关闭|不强制)/);
  if (explicit !== null) {
    return modeFromMarker(explicit[1]);
  }
  // 单独配置指令时关闭优先；未知配置不自动弹出。
  if (content.indexOf('//强制关闭') >= 0) {
    return RecommendationMode.CLOSED;
  }
  if (content.indexOf('//强制提醒') >= 0) {
    return RecommendationMode.FORCE;
  }
  return content.indexOf('//不强制') >= 0 ? RecommendationMode.NORMAL : RecommendationMode.CLOSED;
}

function modeFromMarker(marker: string): RecommendationMode {
  if (marker === '强制提醒') {
    return RecommendationMode.FORCE;
  }
  return marker === '不强制' ? RecommendationMode.NORMAL : RecommendationMode.CLOSED;
}

export function parseRecommendationInfo(content: string): RecommendationInfo {
  let name: string = '';
  let subtitle: string = '';
  let description: string = '';
  let section: string = '';
  const lines: string[] = content.replace(/\r\n?/g, '\n').split('\n');
  for (let i: number = 0; i < lines.length; i++) {
    const line: string = lines[i];
    const field: RegExpMatchArray | null = line.trim().match(/^(应用名称|应用小注释|应用多行注释)\s*[:：]\s*(.*)$/);
    if (field !== null) {
      section = field[1];
      if (section === '应用名称') {
        name = field[2].trim();
      } else if (section === '应用小注释') {
        subtitle = field[2].trim();
      } else {
        description = field[2];
      }
    } else if (section === '应用多行注释') {
      description += '\n' + line;
    } else if (section === '应用小注释' && line.trim().length > 0) {
      subtitle += '\n' + line.trim();
    }
  }
  return { name: name, subtitle: subtitle, description: description.trim() };
}

function findLatest(items: XXAuthAnnouncement[], priority: number): XXAuthAnnouncement | null {
  let selected: XXAuthAnnouncement | null = null;
  for (let i: number = 0; i < items.length; i++) {
    const item: XXAuthAnnouncement = items[i];
    if (!item || item.priority !== priority || (item.status !== undefined && item.status !== 1) ||
      typeof item.content !== 'string' || item.content.trim().length === 0) {
      continue;
    }
    const timestamp: number = Date.parse(item.updated_at || item.created_at || '') || 0;
    const selectedTimestamp: number = selected ? (Date.parse(selected.updated_at || selected.created_at || '') || 0) : -1;
    if (selected === null || timestamp > selectedTimestamp) {
      selected = item;
    }
  }
  return selected;
}

export function isRecommendationWebUrl(url: string): boolean {
  return /^https?:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/.test(url);
}

export function isRecommendationStoreUrl(url: string): boolean {
  return isRecommendationWebUrl(url) || /^store:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/.test(url);
}

export function parseRecommendationSnoozePrompt(items: XXAuthAnnouncement[]): RecommendationSnoozePrompt | null {
  const promptItem: XXAuthAnnouncement | null = findLatest(items, 14);
  const storeItem: XXAuthAnnouncement | null = findLatest(items, 13);
  if (!promptItem || !storeItem || !isRecommendationStoreUrl(storeItem.content.trim())) {
    return null;
  }
  return {
    title: typeof promptItem.title === 'string' && promptItem.title.trim().length > 0 ?
      promptItem.title.trim() : '请您再考虑一下',
    message: promptItem.content.trim(),
    storeUrl: storeItem.content.trim()
  };
}

export function parseRecommendationConfig(items: XXAuthAnnouncement[]): RecommendationConfig | null {
  const modeItem: XXAuthAnnouncement | null = findLatest(items, 10);
  const infoItem: XXAuthAnnouncement | null = findLatest(items, 11);
  const iconItem: XXAuthAnnouncement | null = findLatest(items, 12);
  const storeItem: XXAuthAnnouncement | null = findLatest(items, 13);
  if (!modeItem || !infoItem || !iconItem || !storeItem) {
    return null;
  }
  const info: RecommendationInfo = parseRecommendationInfo(infoItem.content);
  const iconUrl: string = iconItem.content.trim();
  const storeUrl: string = storeItem.content.trim();
  if (!info.name || !isRecommendationWebUrl(iconUrl) || !isRecommendationStoreUrl(storeUrl)) {
    return null;
  }
  return {
    mode: parseRecommendationMode(modeItem.content),
    name: info.name,
    subtitle: info.subtitle,
    description: info.description,
    iconUrl: iconUrl,
    storeUrl: storeUrl
  };
}

export function shouldPresentRecommendation(mode: RecommendationMode, snoozeUntil: number,
  now: number, manuallyRequested: boolean = false): boolean {
  if (mode === RecommendationMode.CLOSED) {
    return false;
  }
  if (manuallyRequested) {
    return true;
  }
  return mode === RecommendationMode.FORCE || snoozeUntil <= now;
}
