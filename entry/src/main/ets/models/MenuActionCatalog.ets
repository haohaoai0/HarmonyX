export class MenuActionOption {
  id: string;
  group: string;
  title: Resource;

  constructor(id: string, group: string, title: Resource) {
    this.id = id;
    this.group = group;
    this.title = title;
  }
}

// Stable identifiers are shared by Settings and every rendering surface.
// Visibility is a preference; content/ownership/API availability still applies.
export const MENU_ACTION_OPTIONS: MenuActionOption[] = [
  new MenuActionOption('post.not_interested', 'post_menu', $r('app.string.video_feed_not_interested')),
  new MenuActionOption('post.follow', 'post_menu', $r('app.string.profile_detail_follow')),
  new MenuActionOption('post.lists', 'post_menu', $r('app.string.post_menu_lists')),
  new MenuActionOption('post.mute', 'post_menu', $r('app.string.post_menu_mute')),
  new MenuActionOption('post.block', 'post_menu', $r('app.string.post_menu_block')),
  new MenuActionOption('post.report', 'post_menu', $r('app.string.video_feed_report_post')),
  new MenuActionOption('post.note', 'post_menu', $r('app.string.post_menu_request_note')),
  new MenuActionOption('post.interactions', 'post_menu', $r('app.string.post_interactions_title')),
  new MenuActionOption('post.hidden_replies', 'post_menu', $r('app.string.post_menu_hidden_replies')),
  new MenuActionOption('photo.publish', 'photo_menu', $r('app.string.post_photo_publish')),
  new MenuActionOption('photo.copy', 'photo_menu', $r('app.string.post_photo_copy')),
  new MenuActionOption('photo.save', 'photo_menu', $r('app.string.post_photo_save_original')),
  new MenuActionOption('photo.background', 'photo_menu', $r('app.string.post_photo_save_background')),
  new MenuActionOption('photo.share', 'photo_menu', $r('app.string.action_share')),
  new MenuActionOption('photo.original', 'photo_menu', $r('app.string.media_view_original')),
  new MenuActionOption('photo.post', 'photo_menu', $r('app.string.video_feed_go_to_post')),
  new MenuActionOption('photo.report', 'photo_menu', $r('app.string.video_feed_report_post')),
  new MenuActionOption('photo.save_all', 'photo_menu', $r('app.string.media_download_all_originals')),
  new MenuActionOption('photo.ocr', 'photo_menu', $r('app.string.photo_ocr_action')),
  new MenuActionOption('photo.subject', 'photo_menu', $r('app.string.photo_subject_action')),
  new MenuActionOption('video.not_interested', 'video_menu', $r('app.string.video_feed_not_interested')),
  new MenuActionOption('video.cast', 'video_menu', $r('app.string.video_feed_cast')),
  new MenuActionOption('video.captions', 'video_menu', $r('app.string.video_feed_subtitles')),
  new MenuActionOption('video.caption_opacity', 'video_menu', $r('app.string.video_feed_caption_background')),
  new MenuActionOption('video.layout', 'video_menu', $r('app.string.video_feed_layout')),
  new MenuActionOption('video.tap', 'video_menu', $r('app.string.video_feed_tap_action')),
  new MenuActionOption('video.fill', 'video_menu', $r('app.string.settings_video_immersive_fill')),
  new MenuActionOption('video.controls', 'video_menu', $r('app.string.video_feed_controls_always_visible')),
  new MenuActionOption('video.quality', 'video_menu', $r('app.string.video_feed_quality')),
  new MenuActionOption('video.advance', 'video_menu', $r('app.string.video_feed_auto_advance')),
  new MenuActionOption('video.post', 'video_menu', $r('app.string.video_feed_go_to_post')),
  new MenuActionOption('video.download', 'video_menu', $r('app.string.video_feed_add_offline')),
  new MenuActionOption('video.share', 'video_menu', $r('app.string.action_share')),
  new MenuActionOption('video.report', 'video_menu', $r('app.string.video_feed_report_post'))
];

export function menuActionsForGroup(group: string): MenuActionOption[] {
  return MENU_ACTION_OPTIONS.filter((option: MenuActionOption): boolean => option.group === group);
}

export function menuActionVisible(hidden: string, id: string): boolean {
  return hidden.split(',').indexOf(id) < 0;
}

export function normalizeHiddenMenuActions(hidden: string): string {
  const ids: string[] = hidden.split(',');
  return MENU_ACTION_OPTIONS.filter((option: MenuActionOption): boolean => ids.indexOf(option.id) >= 0)
    .map((option: MenuActionOption): string => option.id).join(',');
}
