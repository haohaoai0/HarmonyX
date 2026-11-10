import { orderedTabIds } from './TabOrder';

export const DEFAULT_SIDEBAR_HIDDEN: string = 'home,explore,messages';

export const SIDEBAR_ITEM_IDS: string[] = ['home', 'explore', 'messages', 'profile',
  'notifications', 'follow', 'premium', 'communities', 'bookmarks', 'history', 'lists', 'spaces',
  'grok', 'groups', 'studio', 'support', 'help'];

export function sidebarOrderedIds(order: string): string[] {
  const main: string[] = orderedTabIds(order, SIDEBAR_ITEM_IDS)
    .filter((id: string): boolean => !sidebarFooterItem(id));
  return [...main, 'support', 'help'];
}

export function sidebarFooterItem(id: string): boolean {
  return id === 'support' || id === 'help';
}

export function sidebarMainIds(order: string, hidden: string): string[] {
  return sidebarVisibleIds(order, hidden).filter((id: string): boolean => !sidebarFooterItem(id));
}

export function sidebarVisibleIds(order: string, hidden: string): string[] {
  const hiddenIds: string[] = hidden.split(',');
  return sidebarOrderedIds(order).filter((id: string): boolean => hiddenIds.indexOf(id) < 0);
}

export function sidebarItemLabel(id: string): Resource {
  if (id === 'home') { return $r('app.string.home_title'); }
  if (id === 'explore') { return $r('app.string.explore_title'); }
  if (id === 'messages') { return $r('app.string.messages_title'); }
  if (id === 'profile') { return $r('app.string.side_profile'); }
  if (id === 'notifications') { return $r('app.string.side_notifications'); }
  if (id === 'follow') { return $r('app.string.follow_add_button'); }
  if (id === 'premium') { return $r('app.string.side_premium'); }
  if (id === 'communities') { return $r('app.string.side_communities'); }
  if (id === 'bookmarks') { return $r('app.string.side_bookmarks'); }
  if (id === 'history') { return $r('app.string.browsing_history_title'); }
  if (id === 'lists') { return $r('app.string.side_lists'); }
  if (id === 'spaces') { return $r('app.string.side_spaces'); }
  if (id === 'grok') { return $r('app.string.grok_title'); }
  if (id === 'groups') { return $r('app.string.account_groups_title'); }
  if (id === 'studio') { return $r('app.string.side_creator_studio'); }
  if (id === 'support') { return $r('app.string.side_support'); }
  return $r('app.string.side_help');
}

export function sidebarItemIcon(id: string): Resource {
  if (id === 'home') { return $r('sys.symbol.house'); }
  if (id === 'explore') { return $r('sys.symbol.magnifyingglass'); }
  if (id === 'messages') { return $r('sys.symbol.message'); }
  if (id === 'profile') { return $r('sys.symbol.person'); }
  if (id === 'notifications') { return $r('sys.symbol.bell'); }
  if (id === 'follow') { return $r('sys.symbol.person_badge_plus'); }
  if (id === 'premium') { return $r('sys.symbol.star_rosette'); }
  if (id === 'communities') { return $r('sys.symbol.person_2'); }
  if (id === 'bookmarks') { return $r('sys.symbol.bookmark'); }
  if (id === 'history') { return $r('sys.symbol.clock'); }
  if (id === 'lists') { return $r('sys.symbol.list_bullet'); }
  if (id === 'spaces') { return $r('sys.symbol.waveform'); }
  if (id === 'grok') { return $r('sys.symbol.wand_and_stars'); }
  if (id === 'groups') { return $r('sys.symbol.person_2'); }
  if (id === 'studio') { return $r('sys.symbol.rectangle_3_group'); }
  if (id === 'support') { return $r('sys.symbol.heart_fill'); }
  return $r('sys.symbol.questionmark_circle');
}
