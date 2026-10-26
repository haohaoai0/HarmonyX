import { menuActionsForGroup, MenuActionOption } from './MenuActionCatalog';

// Single navigation catalog for phone, desktop, nested settings and search.
export class SettingsGroup {
  id: string;
  title: Resource;
  constructor(id: string, title: Resource) { this.id = id; this.title = title; }
}

export class SettingsCategory {
  id: string;
  group: string;
  parent: string;
  title: Resource;
  detail: Resource;
  icon: Resource;
  destination: string;
  keywords: Resource[];
  constructor(id: string, group: string, parent: string, title: Resource, detail: Resource,
    icon: Resource, destination: string, keywords: Resource[]) {
    this.id = id; this.group = group; this.parent = parent; this.title = title;
    this.detail = detail; this.icon = icon; this.destination = destination; this.keywords = keywords;
  }
}

export const SETTINGS_GROUPS: SettingsGroup[] = [
  new SettingsGroup('account', $r('app.string.settings_group_account')),
  new SettingsGroup('experience', $r('app.string.settings_group_experience')),
  new SettingsGroup('content', $r('app.string.settings_group_content')),
  new SettingsGroup('data', $r('app.string.settings_group_data')),
  new SettingsGroup('support', $r('app.string.settings_group_support'))
];

export const SETTINGS_CATEGORIES: SettingsCategory[] = [
  new SettingsCategory('account', 'account', '', $r('app.string.settings_account'),
    $r('app.string.settings_account_desc'), $r('sys.symbol.person'), 'AccountPrivacy', [
      $r('app.string.accounts_manage'),
      $r('app.string.accounts_manage_desc')
    ]),
  new SettingsCategory('privacy', 'account', '', $r('app.string.settings_privacy'),
    $r('app.string.settings_privacy_desc'), $r('sys.symbol.lock'), 'AccountPrivacy', [
    ]),
  new SettingsCategory('security', 'account', '', $r('app.string.settings_security'),
    $r('app.string.settings_security_desc'), $r('sys.symbol.lock'), 'AccountPrivacy', [
    ]),
  new SettingsCategory('anti_peep', 'account', '', $r('app.string.settings_anti_peep'),
    $r('app.string.settings_anti_peep_desc'), $r('sys.symbol.lock'), '', [
      $r('app.string.settings_anti_peep_enable'),
      $r('app.string.settings_anti_peep_setup'),
      $r('app.string.settings_anti_peep_permission'),
      $r('app.string.settings_anti_peep_system_off')
    ]),
  new SettingsCategory('blocked', 'account', '', $r('app.string.settings_blocked_accounts'),
    $r('app.string.settings_blocked_accounts_desc'), $r('sys.symbol.person'), 'UserList', [
    ]),
  new SettingsCategory('display', 'experience', '', $r('app.string.settings_category_display'),
    $r('app.string.settings_category_display_desc'), $r('sys.symbol.sun_max'), '', [
    ]),
  new SettingsCategory('scene_modes', 'experience', '', $r('app.string.scene_title'),
    $r('app.string.scene_intro'), $r('sys.symbol.wand_and_stars'), '', [
      $r('app.string.scene_reading'), $r('app.string.scene_saver'), $r('app.string.scene_media'), $r('app.string.scene_restore')
    ]),
  new SettingsCategory('eye_reading', 'experience', '', $r('app.string.eye_reading_title'),
    $r('app.string.eye_reading_intro'), $r('sys.symbol.eye'), '', [
      $r('app.string.eye_reading_enable'), $r('app.string.eye_reading_dwell'),
      $r('app.string.eye_reading_threshold'), $r('app.string.eye_reading_help')
    ]),
  new SettingsCategory('home', 'experience', '', $r('app.string.settings_category_home'),
    $r('app.string.settings_category_home_desc'), $r('sys.symbol.house'), '', [
    ]),
  new SettingsCategory('media', 'experience', '', $r('app.string.settings_category_media'),
    $r('app.string.settings_category_media_desc'), $r('sys.symbol.play_circle'), '', [
    ]),
  new SettingsCategory('chat', 'experience', '', $r('app.string.chat_settings'),
    $r('app.string.settings_chat_desc'), $r('sys.symbol.message'), 'DmSettings', [
      $r('app.string.chat_dm_requests'), $r('app.string.chat_calls'),
      $r('app.string.chat_change_pin'), $r('app.string.chat_auto_download'), $r('app.string.chat_reset')
    ]),
  new SettingsCategory('notifications', 'experience', '', $r('app.string.settings_notifications'),
    $r('app.string.settings_notifications_desc'), $r('sys.symbol.bell'), '', [
    ]),
  new SettingsCategory('accessibility', 'experience', '', $r('app.string.settings_category_accessibility'),
    $r('app.string.settings_category_accessibility_desc'), $r('sys.symbol.hand_point_up_tap_fill_1'), '', [
      $r('app.string.settings_grip_hdstabs'), $r('app.string.settings_grip_hdstabs_desc'),
      $r('app.string.settings_grip_floating'), $r('app.string.settings_grip_video'),
      $r('app.string.settings_grip_reply'), $r('app.string.settings_grip_component_desc'),
      $r('app.string.settings_grip_hand'),
      $r('app.string.settings_grip_hand_desc'),
      $r('app.string.settings_grip_hand_preference'),
      $r('app.string.settings_grip_hand_preference_desc'),
      $r('app.string.settings_grip_hand_right'),
      $r('app.string.settings_grip_hand_left'),
      $r('app.string.settings_link_in_app'),
      $r('app.string.settings_link_in_app_desc'),
      $r('app.string.settings_press_effect'),
      $r('app.string.settings_press_effect_desc'),
      $r('app.string.settings_read_aloud_entry'),
      $r('app.string.settings_read_aloud_entry_desc')
    ]),
  new SettingsCategory('content', 'content', '', $r('app.string.settings_category_content'),
    $r('app.string.settings_category_content_desc'), $r('sys.symbol.line_3_horizontal'), '', [
      $r('app.string.settings_sensitive_media'),
      $r('app.string.settings_sensitive_media_desc'),
      $r('app.string.settings_filter_title'),
      $r('app.string.settings_filter_languages'),
      $r('app.string.settings_filter_languages_desc'),
      $r('app.string.settings_reply_quality'),
      $r('app.string.settings_reply_quality_desc'),
      $r('app.string.reply_quality_whitelist'),
      $r('app.string.reply_quality_whitelist_desc'),
      $r('app.string.settings_filter_desc'),
      $r('app.string.xsettings_local_filter_note'),
      $r('app.string.settings_filter_hide_ads'),
      $r('app.string.settings_filter_hide_ads_desc'),
      $r('app.string.settings_for_you_only_sensitive'), $r('app.string.settings_for_you_only_sensitive_desc'),
      $r('app.string.settings_filter_only_media'),
      $r('app.string.settings_filter_only_media_desc'),
      $r('app.string.settings_filter_hide_reposts'),
      $r('app.string.settings_filter_hide_reposts_desc'),
      $r('app.string.settings_filter_hide_replies'),
      $r('app.string.settings_filter_hide_replies_desc'),
      $r('app.string.settings_filter_keywords'),
      $r('app.string.settings_filter_keywords_desc'),
      $r('app.string.settings_filter_keywords_placeholder'),
      $r('app.string.settings_filter_muted_users'),
      $r('app.string.settings_filter_muted_users_desc'),
      $r('app.string.settings_filter_muted_users_placeholder')
    ]),
  new SettingsCategory('language_tools', 'content', '', $r('app.string.settings_category_language_tools'),
    $r('app.string.settings_category_language_tools_desc'), $r('sys.symbol.translate'), '', [
    ]),
  new SettingsCategory('lists', 'content', '', $r('app.string.settings_lists'),
    $r('app.string.settings_lists_desc'), $r('sys.symbol.list_bullet'), 'Lists', [
    ]),
  new SettingsCategory('proxy', 'data', '', $r('app.string.settings_proxy'),
    $r('app.string.settings_proxy_desc'), $r('sys.symbol.network_acceleration'), 'ProxySettings', [
      $r('app.string.proxy_enable'),
      $r('app.string.proxy_type_http'),
      $r('app.string.proxy_type_socks5'),
      $r('app.string.proxy_video_cdn'),
      $r('app.string.proxy_video_cdn_desc')
    ]),
  new SettingsCategory('dns', 'data', '', $r('app.string.dns_title'),
    $r('app.string.dns_enable_desc'), $r('sys.symbol.network_acceleration'), 'DnsSettings', [
      $r('app.string.dns_enable'), $r('app.string.dns_provider'),
      $r('app.string.dns_endpoint'), $r('app.string.dns_provider_custom')
    ]),
  new SettingsCategory('storage', 'data', '', $r('app.string.storage_title'),
    $r('app.string.storage_settings_desc'), $r('sys.symbol.folder'), 'DataStorage', [
      $r('app.string.download_manager_title'),
      $r('app.string.download_manager_desc'),
      $r('app.string.download_cache_title'),
      $r('app.string.download_cache_desc'),
      $r('app.string.storage_download_path'), $r('app.string.storage_chat_cache'),
      $r('app.string.storage_chat_retention'), $r('app.string.chat_storage')
    ]),
  new SettingsCategory('resources', 'support', '', $r('app.string.settings_resources'),
    $r('app.string.settings_resources_desc'), $r('sys.symbol.questionmark_circle'), '', [
      $r('app.string.side_help'),
      $r('app.string.help_intro'),
      $r('app.string.settings_diagnostics'),
      $r('app.string.diagnostics_desc')
    ]),
  new SettingsCategory('supportauthor', 'support', '', $r('app.string.side_support'),
    $r('app.string.help_support_scan'), $r('sys.symbol.heart_fill'), 'Support', [
      $r('app.string.help_support_wechat'), $r('app.string.help_support_alipay'),
      $r('app.string.supporter_title'), $r('app.string.supporter_redeem')
    ]),
  new SettingsCategory('about', 'support', '', $r('app.string.about_title'),
    $r('app.string.about_tagline'), $r('sys.symbol.info_circle'), 'About', [
      $r('app.string.about_version'), $r('app.string.xxauth_announcements'),
      $r('app.string.xxauth_articles'), $r('app.string.xxauth_versions'), $r('app.string.settings_check_update'),
      $r('app.string.supporter_title'), $r('app.string.supporter_redeem')
    ]),
  new SettingsCategory('theme', 'experience', 'display', $r('app.string.settings_category_theme'),
    $r('app.string.settings_category_theme_desc'), $r('sys.symbol.sun_max'), '', [
      $r('app.string.settings_avatar_tint'),
      $r('app.string.settings_avatar_tint_desc'),
      $r('app.string.settings_display_intro'),
      $r('app.string.settings_theme_system'),
      $r('app.string.settings_theme_light'),
      $r('app.string.settings_theme_dark'),
      $r('app.string.settings_dark_surface_title'),
      $r('app.string.settings_dark_surface_desc'),
      $r('app.string.settings_dark_surface_black'),
      $r('app.string.settings_dark_surface_gentle'),
      $r('app.string.settings_theme_color'),
      $r('app.string.settings_theme_mix'),
      $r('app.string.settings_theme_mix_desc'),
      $r('app.string.settings_theme_mix_candy'),
      $r('app.string.settings_theme_mix_sky'),
      $r('app.string.settings_theme_mix_peach'),
      $r('app.string.settings_theme_mix_lilac'),
      $r('app.string.settings_theme_mix_confetti'),
      $r('app.string.settings_theme_mix_coast'),
      $r('app.string.settings_theme_mix_sunset'),
      $r('app.string.settings_theme_mix_forest'),
      $r('app.string.settings_theme_mix_berry'),
      $r('app.string.settings_theme_mix_morandi'),
      $r('app.string.settings_theme_mix_prism'),
      $r('app.string.settings_theme_system_blue'),
      $r('app.string.settings_theme_x_blue'),
      $r('app.string.settings_theme_yellow'),
      $r('app.string.settings_theme_pink'),
      $r('app.string.settings_theme_purple'),
      $r('app.string.settings_theme_orange'),
      $r('app.string.settings_theme_green'),
      $r('app.string.settings_theme_cat_blue'),
      $r('app.string.settings_theme_huawei_red'),
      $r('app.string.settings_theme_icon_blue'),
      $r('app.string.settings_theme_icon_red'),
      $r('app.string.settings_theme_icon_orange'),
      $r('app.string.settings_theme_icon_yellow'),
      $r('app.string.settings_theme_icon_green'),
      $r('app.string.settings_theme_icon_pink'),
      $r('app.string.settings_theme_icon_cyan'),
      $r('app.string.settings_theme_icon_navy')
    ]),
  new SettingsCategory('pagebackground', 'experience', 'display', $r('app.string.page_background_title'),
    $r('app.string.page_background_description'), $r('sys.symbol.square_grid_2x2'), 'PageBackground', [
      $r('app.string.page_background_base'), $r('app.string.page_background_pattern'),
      $r('app.string.page_background_content_opacity'), $r('app.string.page_background_transparent_posts'),
      $r('app.string.page_background_transparent_inbox'), $r('app.string.page_background_paper'),
      $r('app.string.page_background_kraft'), $r('app.string.page_background_parchment'),
      $r('app.string.page_background_density')
    ]),
  new SettingsCategory('uihdr', 'experience', 'display', $r('app.string.settings_component_hdr_ratio'),
    $r('app.string.settings_component_hdr_desc'), $r('sys.symbol.sun_max'), '', [
      $r('app.string.settings_component_hdr_reset')
    ]),
  new SettingsCategory('motion', 'experience', 'display', $r('app.string.motion_title'),
    $r('app.string.motion_intro'), $r('sys.symbol.wand_and_stars'), '', [
      $r('app.string.startup_animation_title'), $r('app.string.startup_animation_desc'),
      $r('app.string.startup_animation_icon'), $r('app.string.startup_animation_icon_desc'),
      $r('app.string.startup_animation_ios'), $r('app.string.startup_animation_ios_desc'),
      $r('app.string.startup_animation_video'), $r('app.string.startup_animation_video_desc'),
      $r('app.string.startup_animation_none'), $r('app.string.startup_animation_none_desc'),
      $r('app.string.startup_animation_speed'), $r('app.string.startup_animation_speed_desc'),
      $r('app.string.motion_duration'), $r('app.string.motion_amplitude'), $r('app.string.motion_damping'),
      $r('app.string.motion_reduce'), $r('app.string.motion_symbol'), $r('app.string.motion_haptics'),
      $r('app.string.motion_presets'), $r('app.string.motion_preset_quick'),
      $r('app.string.motion_preset_standard'), $r('app.string.motion_preset_spring'), $r('app.string.motion_preset_reduced')
    ]),
  new SettingsCategory('transitions', 'experience', 'display', $r('app.string.settings_page_transition'),
    $r('app.string.settings_page_transition_desc'), $r('sys.symbol.square_and_square'), '', [
      $r('app.string.settings_page_transition_classic'),
      $r('app.string.settings_page_transition_classic_desc'),
      $r('app.string.settings_page_transition_official'),
      $r('app.string.settings_page_transition_official_desc')
    ]),
  new SettingsCategory('fonts', 'experience', 'display', $r('app.string.settings_category_fonts'),
    $r('app.string.settings_category_fonts_desc'), $r('sys.symbol.textformat'), '', [
      $r('app.string.settings_system_emoji'),
      $r('app.string.settings_system_emoji_desc'),
      $r('app.string.settings_font_size'),
      $r('app.string.settings_font_follow_system'),
      $r('app.string.settings_font_app_scale'),
      $r('app.string.settings_font_preview'),
      $r('app.string.settings_font_app_hint'),
      $r('app.string.settings_font_system_hint'),
      $r('app.string.settings_font_system_scale_label'),
      $r('app.string.settings_font_restart_hint'),
      $r('app.string.settings_font_restart_action'),
      $r('app.string.settings_custom_font_title'),
      $r('app.string.settings_custom_font_current'),
      $r('app.string.settings_custom_font_system'),
      $r('app.string.settings_custom_font_sample_large'),
      $r('app.string.settings_custom_font_sample_medium'),
      $r('app.string.settings_custom_font_sample_small'),
      $r('app.string.settings_custom_font_import'),
      $r('app.string.settings_custom_font_import_desc'),
      $r('app.string.settings_custom_font_reset'),
      $r('app.string.settings_content_font_title'),
      $r('app.string.settings_content_font_system'),
      $r('app.string.settings_content_font_serif'),
      $r('app.string.settings_content_font_monospace'),
      $r('app.string.settings_content_font_hint')
    ]),
  new SettingsCategory('materials', 'experience', 'display', $r('app.string.settings_category_materials'),
    $r('app.string.settings_category_materials_desc'), $r('sys.symbol.square_and_square'), '', [
    ]),
  new SettingsCategory('appicon', 'experience', 'display', $r('app.string.settings_app_icon'),
    $r('app.string.settings_app_icon_desc'), $r('sys.symbol.square_grid_2x2'), '', [
      $r('app.string.settings_app_icon_intro'),
      $r('app.string.settings_app_icon_note'),
      $r('app.string.settings_app_icon_unsupported'),
      $r('app.string.settings_app_icon_mid_autumn_note'),
      $r('app.string.settings_app_icon_default'),
      $r('app.string.settings_app_icon_mid_autumn'),
      $r('app.string.settings_app_icon_schedule_title'),
      $r('app.string.settings_app_icon_schedule_desc'),
      $r('app.string.settings_app_icon_schedule_start'),
      $r('app.string.settings_app_icon_schedule_end'),
      $r('app.string.settings_app_icon_schedule_target'),
      $r('app.string.settings_app_icon_classic'),
      $r('app.string.settings_app_icon_spectrum'),
      $r('app.string.settings_app_icon_outline'),
      $r('app.string.settings_app_icon_brush'),
      $r('app.string.settings_app_icon_blossom'),
      $r('app.string.settings_app_icon_blue_bird'),
      $r('app.string.settings_app_icon_twitter_blue'),
      $r('app.string.settings_app_icon_twitter_white'),
      $r('app.string.settings_app_icon_x_black'),
      $r('app.string.settings_app_icon_x_white'),
      $r('app.string.settings_app_icon_frog_white'),
      $r('app.string.settings_app_icon_frog_black'),
      $r('app.string.settings_app_icon_schedule_background_note')
    ]),
  new SettingsCategory('titlebar', 'experience', 'materials', $r('app.string.settings_category_titlebar'),
    $r('app.string.settings_category_titlebar_desc'), $r('sys.symbol.rectangle'), '', [
      $r('app.string.settings_title_bar_logo'),
      $r('app.string.settings_title_bar_logo_desc'),
      $r('app.string.settings_title_bar_logo_auto_contrast'),
      $r('app.string.settings_title_bar_logo_auto_contrast_desc'),
      $r('app.string.settings_compact_switch_style'),
      $r('app.string.settings_compact_switch_style_desc'),
      $r('app.string.settings_compact_switch_tabs'),
      $r('app.string.settings_compact_switch_buttons'),
      $r('app.string.settings_immersive_title_bar_blur'),
      $r('app.string.settings_immersive_title_bar_blur_note'),
      $r('app.string.settings_immersive_title_bar_blur_switch'),
      $r('app.string.settings_title_bar_style_immersive'),
      $r('app.string.settings_title_bar_style_blur'),
      $r('app.string.settings_title_bar_style_glass'),
      $r('app.string.settings_title_bar_glass_blur_off'),
      $r('app.string.settings_title_bar_glass_blur_off_desc'),
      $r('app.string.settings_title_bar_glass_level_label'),
      $r('app.string.settings_title_bar_glass_level_desc'),
      $r('app.string.settings_title_bar_glass_level_ultra_thin'),
      $r('app.string.settings_title_bar_glass_level_thin'),
      $r('app.string.settings_title_bar_glass_level_regular'),
      $r('app.string.settings_title_bar_glass_level_thick'),
      $r('app.string.settings_title_bar_glass_level_ultra_thick')
    ]),
  new SettingsCategory('tabmaterial', 'experience', 'materials', $r('app.string.settings_hds_tabs_material_title'),
    $r('app.string.settings_hds_tabs_material_note'), $r('sys.symbol.rectangle'), '', [
      $r('app.string.settings_hds_tabs_material_title'),
      $r('app.string.settings_hds_tabs_material_note'),
      $r('app.string.settings_hds_tabs_material_label'),
      $r('app.string.settings_hds_tabs_material_exquisite'),
      $r('app.string.settings_hds_tabs_material_gentle'),
      $r('app.string.settings_hds_tabs_material_smooth'),
      $r('app.string.settings_hds_tabs_material_adaptive'),
      $r('app.string.settings_hds_tabs_gradient_mask'),
      $r('app.string.settings_hds_tabs_gradient_mask_desc')
    ]),
  new SettingsCategory('sheetmaterial', 'experience', 'materials', $r('app.string.settings_sheet_material_title'),
    $r('app.string.settings_sheet_material_desc'), $r('sys.symbol.square_and_square'), '', [
      $r('app.string.settings_sheet_material_title'),
      $r('app.string.settings_sheet_material_desc'),
      $r('app.string.settings_sheet_material_unavailable'),
      $r('app.string.settings_sheet_material_level'),
      $r('app.string.settings_title_bar_glass_level_ultra_thin'),
      $r('app.string.settings_title_bar_glass_level_thin'),
      $r('app.string.settings_title_bar_glass_level_regular'),
      $r('app.string.settings_title_bar_glass_level_thick'),
      $r('app.string.settings_title_bar_glass_level_ultra_thick')
    ]),
  new SettingsCategory('sidebarmaterial', 'experience', 'materials', $r('app.string.settings_category_sidebarmaterial'),
    $r('app.string.settings_category_sidebarmaterial_desc'), $r('sys.symbol.rectangle'), '', [
      $r('app.string.sidebar_material_type'),
      $r('app.string.sidebar_material_glass'),
      $r('app.string.sidebar_material_blur'),
      $r('app.string.settings_layout_save_failed'),
      $r('app.string.settings_desktop_rail_material'),
      $r('app.string.settings_desktop_rail_material_desc'),
      $r('app.string.chat_off'),
      $r('app.string.settings_title_bar_glass_level_ultra_thin'),
      $r('app.string.settings_title_bar_glass_level_thin'),
      $r('app.string.settings_title_bar_glass_level_regular'),
      $r('app.string.settings_title_bar_glass_level_thick'),
      $r('app.string.settings_title_bar_glass_level_ultra_thick')
    ]),
  new SettingsCategory('replymaterial', 'experience', 'materials', $r('app.string.settings_category_replymaterial'),
    $r('app.string.settings_category_replymaterial_desc'), $r('sys.symbol.message'), '', [
      $r('app.string.settings_reply_capsule_split'),
      $r('app.string.settings_reply_capsule_split_desc'),
      $r('app.string.settings_reply_capsule_material_level_label'),
      $r('app.string.settings_reply_capsule_material_level_desc'),
      $r('app.string.settings_title_bar_glass_level_ultra_thin'),
      $r('app.string.settings_title_bar_glass_level_thin'),
      $r('app.string.settings_title_bar_glass_level_regular'),
      $r('app.string.settings_title_bar_glass_level_thick'),
      $r('app.string.settings_title_bar_glass_level_ultra_thick'),
      $r('app.string.settings_reply_capsule_button_material'),
      $r('app.string.settings_reply_capsule_button_material_desc')
    ]),
  new SettingsCategory('feed', 'experience', 'home', $r('app.string.settings_default_feed'),
    $r('app.string.settings_default_feed_desc'), $r('sys.symbol.house'), '', [
      $r('app.string.settings_default_feed'),
      $r('app.string.settings_default_feed_desc'),
      $r('app.string.home_for_you'),
      $r('app.string.settings_default_feed_for_you_desc'),
      $r('app.string.home_following'),
      $r('app.string.settings_default_feed_following_desc')
    ]),
  new SettingsCategory('navigation', 'experience', 'home', $r('app.string.settings_category_navigation'),
    $r('app.string.settings_category_navigation_desc'), $r('sys.symbol.rectangle'), '', [
      $r('app.string.settings_navigation_style'),
      $r('app.string.settings_hds_bottom_bar'),
      $r('app.string.settings_split_bottom_bar'),
      $r('app.string.settings_split_bottom_bar_desc'),
      $r('app.string.settings_native_bottom_bar'),
      $r('app.string.settings_native_bottom_bar_desc'),
      $r('app.string.settings_native_navigation_material'),
      $r('app.string.settings_me_floating_action'),
      $r('app.string.settings_me_floating_action_desc'),
      $r('app.string.side_profile'),
      $r('app.string.account_overview_manage'),
      $r('app.string.settings_title'),
      $r('app.string.side_help'),
      $r('app.string.settings_classic_bottom_bar'),
      $r('app.string.settings_classic_bottom_bar_desc'),
      $r('app.string.settings_root_tab_labels'),
      $r('app.string.settings_root_tab_labels_desc'),
      $r('app.string.settings_root_liquid_tab_indicator'),
      $r('app.string.settings_root_liquid_tab_indicator_desc'),
      $r('app.string.settings_compose_button'),
      $r('app.string.settings_compose_button_desc'),
      $r('app.string.settings_bottom_tab_order'),
      $r('app.string.settings_tab_order_desc'),
      $r('app.string.settings_custom_bottom_bar_title'),
      $r('app.string.settings_custom_bottom_bar_desc'),
      $r('app.string.home_title'),
      $r('app.string.settings_custom_bottom_bar_page_desc'),
      $r('app.string.explore_title'),
      $r('app.string.tab_alerts'),
      $r('app.string.messages_title'),
      $r('app.string.tab_me'),
      $r('app.string.settings_auto_hide_title'),
      $r('app.string.settings_auto_hide_note'),
      $r('app.string.settings_auto_hide_title_bar'),
      $r('app.string.settings_auto_hide_title_bar_desc'),
      $r('app.string.settings_home_header_collapse'),
      $r('app.string.settings_home_header_collapse_desc'),
      $r('app.string.settings_auto_hide_tab_bar'),
      $r('app.string.settings_auto_hide_tab_bar_desc'),
      $r('app.string.settings_auto_hide_fab'),
      $r('app.string.settings_auto_hide_fab_desc'),
      $r('app.string.settings_interaction_save_failed'),
      $r('app.string.settings_floating_refresh'),
      $r('app.string.settings_floating_top'),
      $r('app.string.settings_floating_hidden'),
      $r('app.string.settings_floating_compose')
    ]),
  new SettingsCategory('home_interaction', 'experience', 'home', $r('app.string.settings_home_interaction'),
    $r('app.string.settings_category_home_interaction_desc'), $r('sys.symbol.arrow_clockwise'), '', [
      $r('app.string.settings_home_tab_order'),
      $r('app.string.settings_tab_order_desc'),
      $r('app.string.settings_home_interaction'),
      $r('app.string.settings_confirm_app_exit'),
      $r('app.string.settings_confirm_app_exit_desc'),
      $r('app.string.settings_floating_action'),
      $r('app.string.settings_floating_action_desc'),
      $r('app.string.settings_floating_compose_material_tint'),
      $r('app.string.settings_floating_compose_material_tint_desc'),
      $r('app.string.settings_floating_compose'),
      $r('app.string.settings_floating_refresh'),
      $r('app.string.settings_floating_top'),
      $r('app.string.settings_floating_hidden'),
      $r('app.string.settings_refresh_on_foreground'),
      $r('app.string.settings_refresh_on_foreground_desc'),
      $r('app.string.settings_refresh_on_home_tab'),
      $r('app.string.settings_refresh_on_home_tab_desc'),
      $r('app.string.settings_home_double_tap_latest'),
      $r('app.string.settings_home_single_tap_top'),
      $r('app.string.settings_home_single_tap_top_desc'),
      $r('app.string.settings_home_double_tap_latest_desc'),
      $r('app.string.settings_home_pull_refresh_latest'),
      $r('app.string.settings_home_pull_refresh_latest_desc'),
      $r('app.string.settings_home_space_capsule'),
      $r('app.string.settings_home_space_capsule_desc'),
      $r('app.string.spaces_save_failed'),
      $r('app.string.settings_menu_post')
    ].concat(menuActionsForGroup('post_menu').map((option: MenuActionOption): Resource => option.title))),
  new SettingsCategory('layout', 'experience', 'home', $r('app.string.settings_category_layout'),
    $r('app.string.settings_category_layout_desc'), $r('sys.symbol.rectangle'), '', [
      $r('app.string.settings_post_actions'),
      $r('app.string.settings_post_actions_desc'),
      $r('app.string.settings_post_action_counts'),
      $r('app.string.action_reply'), $r('app.string.action_repost'), $r('app.string.action_like'),
      $r('app.string.post_detail_views'), $r('app.string.action_bookmark'), $r('app.string.action_share'), $r('app.string.post_translate'),
      $r('app.string.settings_desktop_layout'),
      $r('app.string.settings_desktop_layout_desc'),
      $r('app.string.settings_layout_current'),
      $r('app.string.settings_layout_desktop'),
      $r('app.string.settings_desktop_video_layout'),
      $r('app.string.settings_desktop_video_layout_desc'),
      $r('app.string.settings_desktop_video_split'),
      $r('app.string.settings_desktop_video_feed'),
      $r('app.string.settings_desktop_aside'),
      $r('app.string.settings_desktop_aside_desc'),
      $r('app.string.settings_layout_save_failed'),
      $r('app.string.settings_desktop_rail_auto_hide'),
      $r('app.string.settings_desktop_rail_auto_hide_desc'),
      $r('app.string.sidebar_swipe'),
      $r('app.string.sidebar_swipe_desc'),
      $r('app.string.sidebar_handle_style'),
      $r('app.string.sidebar_handle_style_desc'),
      $r('app.string.settings_timeline_columns_title'),
      $r('app.string.settings_timeline_columns_desc'),
      $r('app.string.settings_timeline_columns_label'),
      $r('app.string.settings_timeline_columns_auto'),
      $r('app.string.settings_timeline_columns_auto_two'),
      $r('app.string.settings_timeline_columns_one'),
      $r('app.string.settings_timeline_columns_two'),
      $r('app.string.settings_timeline_columns_three')
    ]),
  new SettingsCategory('cards', 'experience', 'home', $r('app.string.card_settings_title'),
    $r('app.string.card_settings_intro'), $r('sys.symbol.square_grid_2x2'), 'CardSettings', [
      $r('app.string.card_settings_refresh'), $r('app.string.card_settings_note')
    ]),
  new SettingsCategory('photos', 'experience', 'media', $r('app.string.settings_category_photos'),
    $r('app.string.settings_category_photos_desc'), $r('sys.symbol.ohos_photo'), '', [
      $r('app.string.settings_photo_fullscreen'),
      $r('app.string.settings_photo_fullscreen_desc'),
      $r('app.string.settings_menu_photo')
    ].concat(menuActionsForGroup('photo_menu').map((option: MenuActionOption): Resource => option.title))),
  new SettingsCategory('playback', 'experience', 'media', $r('app.string.settings_category_playback'),
    $r('app.string.settings_category_playback_desc'), $r('sys.symbol.play_circle'), '', [
      $r('app.string.settings_video_autoplay'),
      $r('app.string.settings_video_autoplay_desc'),
      $r('app.string.settings_video_download_button'), $r('app.string.settings_video_download_button_desc'),
      $r('app.string.settings_video_hdr_enhancement'),
      $r('app.string.settings_video_hdr_enhancement_desc'),
      $r('app.string.settings_home_video_mute'),
      $r('app.string.settings_home_video_mute_desc'),
      $r('app.string.settings_viewer_video_mute'),
      $r('app.string.settings_viewer_video_mute_desc'),
      $r('app.string.video_feed_auto_advance'),
      $r('app.string.settings_video_auto_advance_desc'),
      $r('app.string.settings_video_auto_pip'),
      $r('app.string.settings_video_auto_pip_desc'),
      $r('app.string.settings_video_background'),
      $r('app.string.settings_video_background_intro'),
      $r('app.string.settings_video_background_audio'),
      $r('app.string.settings_video_background_audio_desc'),
      $r('app.string.settings_video_background_pip'),
      $r('app.string.settings_video_background_pip_desc')
    ]),
  new SettingsCategory('video_controls', 'experience', 'media', $r('app.string.settings_category_video_controls'),
    $r('app.string.settings_category_video_controls_desc'), $r('sys.symbol.play_circle'), '', [
      $r('app.string.video_feed_layout'),
      $r('app.string.settings_video_feed_layout_desc'),
      $r('app.string.video_feed_layout_classic'),
      $r('app.string.video_feed_layout_douyin'),
      $r('app.string.video_feed_layout_bilibili'),
      $r('app.string.compact_video_layout'),
      $r('app.string.settings_compact_video_layout_desc'),
      $r('app.string.compact_video_layout_rail'),
      $r('app.string.compact_video_layout_bottom'),
      $r('app.string.video_feed_controls_always_visible'),
      $r('app.string.video_feed_controls_always_visible_desc'),
      $r('app.string.video_feed_subtitles'),
      $r('app.string.settings_video_captions_desc'),
      $r('app.string.settings_video_immersive_fill'),
      $r('app.string.settings_video_immersive_fill_desc'),
      $r('app.string.settings_video_hold_speed'),
      $r('app.string.settings_video_hold_speed_desc'),
      $r('app.string.settings_video_double_tap_seek'),
      $r('app.string.settings_video_double_tap_seek_desc'),
      $r('app.string.settings_video_double_tap_seek_seconds'),
      $r('app.string.settings_video_feed_tap_pause'),
      $r('app.string.settings_video_feed_tap_pause_desc'),
      $r('app.string.video_feed_caption_background'),
      $r('app.string.settings_menu_video')
    ].concat(menuActionsForGroup('video_menu').map((option: MenuActionOption): Resource => option.title))),
  new SettingsCategory('viewer', 'experience', 'media', $r('app.string.settings_category_viewer'),
    $r('app.string.settings_category_viewer_desc'), $r('sys.symbol.message'), '', [
      $r('app.string.settings_media_black_background'),
      $r('app.string.settings_media_black_background_desc'),
      $r('app.string.settings_media_comment_background'),
      $r('app.string.settings_media_comment_background_desc'),
      $r('app.string.settings_video_comment_progress_ring'),
      $r('app.string.settings_video_comment_progress_ring_desc')
    ]),
  new SettingsCategory('quality', 'experience', 'media', $r('app.string.settings_category_quality'),
    $r('app.string.settings_category_quality_desc'), $r('sys.symbol.ohos_photo'), '', [
      $r('app.string.settings_image_quality'),
      $r('app.string.settings_quality_data_saver'),
      $r('app.string.settings_image_quality_data_saver_desc'),
      $r('app.string.settings_quality_high'),
      $r('app.string.settings_image_quality_high_desc'),
      $r('app.string.settings_quality_original'),
      $r('app.string.settings_image_quality_original_desc'),
      $r('app.string.settings_video_quality'),
      $r('app.string.settings_quality_auto'),
      $r('app.string.settings_video_quality_auto_desc'),
      $r('app.string.settings_quality_hd'),
      $r('app.string.settings_video_quality_high_desc'),
      $r('app.string.settings_quality_sd'),
      $r('app.string.settings_video_quality_sd_desc'),
      $r('app.string.settings_quality_ld'),
      $r('app.string.settings_video_quality_ld_desc')
    ]),
  new SettingsCategory('language', 'content', 'language_tools', $r('app.string.settings_language'),
    $r('app.string.settings_language_desc'), $r('sys.symbol.translate'), '', [
      $r('app.string.settings_language_intro'),
      $r('app.string.settings_language_system'),
      $r('app.string.settings_language_system_desc')
    ]),
  new SettingsCategory('translation', 'content', 'language_tools', $r('app.string.settings_translation'),
    $r('app.string.settings_translation_desc'), $r('sys.symbol.translate'), '', [
      $r('app.string.settings_translation_intro'),
      $r('app.string.settings_translation_enable'),
      $r('app.string.settings_translation_enable_desc'),
      $r('app.string.settings_translation_replace_original'),
      $r('app.string.settings_translation_replace_original_desc'),
      $r('app.string.settings_translation_mode'),
      $r('app.string.settings_translation_mode_x'),
      $r('app.string.settings_translation_mode_web'),
      $r('app.string.settings_translation_mode_api'),
      $r('app.string.settings_translation_web_note'),
      $r('app.string.settings_translation_x_note'),
      $r('app.string.settings_translation_provider'),
      $r('app.string.settings_translation_model'),
      $r('app.string.settings_translation_api_key'),
      $r('app.string.settings_translation_api_key_placeholder'),
      $r('app.string.settings_translation_api_key_note'),
      $r('app.string.settings_translation_source'),
      $r('app.string.settings_translation_source_auto'),
      $r('app.string.settings_translation_target'),
      $r('app.string.settings_translation_target_app'),
      $r('app.string.settings_translation_auto_enable'),
      $r('app.string.settings_translation_auto_enable_desc'),
      $r('app.string.settings_translation_auto_exclude'),
      $r('app.string.settings_translation_auto_exclude_desc'),
      $r('app.string.settings_translation_base_url'),
      $r('app.string.settings_translation_base_url_note'),
      $r('app.string.settings_translation_save')
    ]),
  new SettingsCategory('grok', 'content', 'language_tools', $r('app.string.settings_grok'),
    $r('app.string.settings_grok_desc'), $r('sys.symbol.message'), '', [
      $r('app.string.settings_grok_intro'),
      $r('app.string.settings_grok_mode'),
      $r('app.string.settings_grok_mode_web'),
      $r('app.string.settings_grok_mode_api'),
      $r('app.string.settings_grok_mode_web_note'),
      $r('app.string.settings_grok_mode_api_note'),
      $r('app.string.settings_grok_x_session'),
      $r('app.string.settings_grok_x_session_desc'),
      $r('app.string.settings_grok_model'),
      $r('app.string.settings_grok_model_hint'),
      $r('app.string.settings_grok_api_key'),
      $r('app.string.settings_grok_api_key_placeholder'),
      $r('app.string.settings_grok_api_key_note'),
      $r('app.string.settings_grok_base_url'),
      $r('app.string.settings_grok_base_url_hint'),
      $r('app.string.settings_grok_save')
    ]),
  new SettingsCategory('alerts', 'experience', 'notifications', $r('app.string.settings_category_alerts'),
    $r('app.string.settings_category_alerts_desc'), $r('sys.symbol.bell'), '', [
      $r('app.string.settings_push'),
      $r('app.string.settings_push_desc'),
      $r('app.string.chat_notifications'), $r('app.string.chat_only_push'), $r('app.string.chat_only_push_hint'),
      $r('app.string.settings_system_notifications'),
      $r('app.string.settings_system_notifications_desc'),
      $r('app.string.settings_notification_dnd_silent'),
      $r('app.string.settings_notification_dnd_silent_desc'),
      $r('app.string.settings_notification_system_settings'),
      $r('app.string.settings_notification_system_settings_desc')
    ])
];

export function settingsCategory(id: string): SettingsCategory | undefined {
  return SETTINGS_CATEGORIES.find((entry: SettingsCategory): boolean => entry.id === id);
}

export function settingsChildren(parent: string): SettingsCategory[] {
  return SETTINGS_CATEGORIES.filter((entry: SettingsCategory): boolean => entry.parent === parent);
}

export function settingsRoots(group: string): SettingsCategory[] {
  return SETTINGS_CATEGORIES.filter((entry: SettingsCategory): boolean => entry.parent === '' && entry.group === group);
}

export function settingsBreadcrumb(entry: SettingsCategory, text: (resource: Resource) => string): string {
  const parts: string[] = [];
  let parent: SettingsCategory | undefined = settingsCategory(entry.parent);
  while (parent !== undefined) {
    parts.unshift(text(parent.title));
    parent = settingsCategory(parent.parent);
  }
  const group: SettingsGroup | undefined = SETTINGS_GROUPS.find((value: SettingsGroup): boolean => value.id === entry.group);
  if (group !== undefined) { parts.unshift(text(group.title)); }
  return parts.join(' › ') + ' · ' + text(entry.detail);
}

export function searchSettings(query: string, text: (resource: Resource) => string): SettingsCategory[] {
  const normalized: string = query.trim().toLowerCase();
  if (normalized.length === 0) { return []; }
  return SETTINGS_CATEGORIES.filter((entry: SettingsCategory): boolean => {
    // Only return the destination containing the controls, rather than every ancestor.
    if (settingsChildren(entry.id).length > 0) { return false; }
    const terms: Resource[] = [entry.title, entry.detail, ...entry.keywords];
    let parent: SettingsCategory | undefined = settingsCategory(entry.parent);
    while (parent !== undefined) {
      terms.push(parent.title);
      parent = settingsCategory(parent.parent);
    }
    return terms.some((resource: Resource): boolean => text(resource).toLowerCase().includes(normalized));
  });
}
