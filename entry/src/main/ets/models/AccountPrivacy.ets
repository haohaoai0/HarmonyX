// Wire fields confirmed from X's account/settings and official settings bundles.
// Optional fields remain unavailable until X actually supplies them.
export interface XAccountPrivacySettings {
  screen_name?: string;
  protected?: boolean;
  allow_media_tagging?: string;
  nsfw_user?: boolean;
  nsfw_admin?: boolean;
  display_sensitive_media?: boolean;
  geo_enabled?: boolean;
  allow_ads_personalization?: boolean;
  allow_logged_out_device_personalization?: boolean;
  allow_location_history_personalization?: boolean;
  allow_sharing_data_for_third_party_personalization?: boolean;
  use_cookie_personalization?: boolean;
}

export interface XBusinessCountryPreference {
  country_code?: string;
  country_name?: string;
  region_name?: string;
}

export interface XAboutAccountPreferences {
  business_country_code_preferences?: XBusinessCountryPreference[];
  selected_business_country_code?: string;
}

export interface XUserPrivacyPreferences {
  allow_video_downloads?: boolean;
  allow_xai_data_sharing?: boolean;
  allow_xai_personalization?: boolean;
  allow_grok_memory?: boolean;
  allow_for_you_recommendations?: boolean;
  inferred_location_resolution_preference?: string;
  about_this_account_user_preferences?: XAboutAccountPreferences;
}

export interface XLoginSession {
  token?: string;
  hashed_token?: string;
  name?: string;
  device_name?: string;
  summary?: string;
  device_summary?: string;
  location?: string;
  is_current_session?: boolean;
  last_seen_time_ms?: string;
  last_seen_at?: string;
}

export interface XConnectedApplication {
  app_id?: string;
  name?: string;
  app_name?: string;
  description?: string;
  permissions?: string;
  token?: string;
  token_hash?: string;
  revoked?: boolean;
}

export interface XToxicReplyFilter {
  enabled?: boolean;
}

export interface XSettingsUser {
  rest_id?: string;
  sessions_list?: XLoginSession[];
  toxic_reply_filter_setting?: XToxicReplyFilter;
}

export interface XSettingsUserResults { result?: XSettingsUser; }
export interface XSettingsViewer {
  user_results?: XSettingsUserResults;
  user?: XSettingsUser;
}

export interface XPrivacyData {
  user_preferences?: XUserPrivacyPreferences;
  user_preferences_put?: boolean;
  user_toxic_reply_filter_setting_put?: boolean;
  viewer?: XSettingsViewer;
  viewer_v2?: XSettingsViewer;
}

export interface XPrivacyEnvelope {
  data?: XPrivacyData;
  applications?: XConnectedApplication[];
  sessions?: XLoginSession[];
}

export class AccountPrivacySnapshot {
  generation: number = -1;
  incomplete: boolean = false;
  account: XAccountPrivacySettings | null = null;
  preferences: XUserPrivacyPreferences | null = null;
  sessions: XLoginSession[] = [];
  applications: XConnectedApplication[] = [];
  replyFilter: boolean | undefined = undefined;
}

export interface AccountPrivacyRouteParam { section: string; }

export interface AccountManagementItem {
  id: string;
  title: Resource;
  detail: Resource;
  action: string;
  target: string;
  field: string;
}

export interface AccountPrivacyChoice {
  value: string;
  label: Resource | string;
}

export interface AccountPrivacyOperation {
  id: string;
  name: string;
  method: string;
  features?: string[];
}

// IDs, method and variable names come from the downloaded official bundles,
// recorded in docs/account-privacy-alignment.md. No guessed registry entries.
export const ACCOUNT_PRIVACY_OPERATIONS: AccountPrivacyOperation[] = [
  { id: 'FWApxg844rupV7YVWzHNug', name: 'AudienceAndTaggingQuery', method: 'GET' },
  { id: 'oe9_UzzuQUeSU4qYVtMwQg', name: 'AudienceAndTaggingAllowVideoDownloadsMutation', method: 'POST' },
  { id: 'teCat2yuEC6e9oilkVKCgw', name: 'GrokSettingsScreenQuery', method: 'GET' },
  { id: 'KEfCyU0XXJQ8AZOxiMWuSQ', name: 'XaiDataSharingSettingsMutation', method: 'POST' },
  { id: 'JbFOnszPZQclTK-4UHDjvw', name: 'XaiPersonalizationSettingsMutation', method: 'POST' },
  { id: 'LiRRkGlfd-47HI98W4kVeQ', name: 'XaiMemoryMutation', method: 'POST' },
  { id: '1wWQtc4uVeqzNFm6vYg8ag', name: 'UserPreferencesQuery', method: 'GET' },
  { id: 'tO4CwZF3SX49GsTvF_kf_Q', name: 'UserPreferencesMutation', method: 'POST' },
  { id: 'kmAhocLFK1cbzXxGq5Boow', name: 'RepliesGetUserToxicReplyFilterSettingQuery', method: 'GET' },
  { id: '2DSpolLNDpVL7KDJ-UWHSg', name: 'useToggleToxicReplyFilterSettingMutation', method: 'POST' },
  { id: 'vJ-XatpmQSG8bDch8-t9Jw', name: 'UserSessionsList', method: 'GET' }
  , { id: 'FO_KX1o77E3vYL14rATn9Q', name: 'AdsCategoriesQuery', method: 'GET' }
  , { id: 'eRWyTnzFgPgv9D4W8ujf6A', name: 'AdsCategoriesMutation', method: 'POST' }
  , { id: 'v5QRfeK5uuWULVGXyMLwyA', name: 'AccountParodyScreenImplV2ParodyLabelSettingQuery', method: 'GET' }
  , { id: '73OvlPaHKjWcU21X1w9SKA', name: 'AccountParodyScreenImplV2ParodyLabelMutation', method: 'POST' }
  , { id: '8fWHnipHAqfhgFo-rAXk5w', name: 'PasskeyManagement_Query', method: 'GET' }
  , { id: '5h0kNbk3ii97rmfY6CdgAA', name: 'SharingAudiospacesListeningDataWithFollowersUpdate', method: 'POST' }
  , { id: 'rD5gLxVmMvtdtYU1UHWlFQ', name: 'UserAccountLabel', method: 'GET' }
  , { id: '_ckHEj05gan2VfNHG6thBA', name: 'DisableUserAccountLabel', method: 'POST' }
  , { id: '9Hyh5D4-WXLnExZkONSkZg', name: 'GrokHistory', method: 'GET' }
  , { id: '83Gg0lfI-47Z3-ZOxyUjiQ', name: 'ClearGrokConversations', method: 'POST' }
  , { id: '3Wx7dsynDTSI0LO52L8L8A', name: 'IDVerificationQuery', method: 'GET', features: ['identity_verification_hide_verified_label_settings_enabled'] }
  , { id: 'lqIzyQL1p3XCZg77zekzZA', name: 'IDVerificationUpdateHideLabelMutation', method: 'POST' }
  , { id: 'GhQlWgEZ8wKf_JimVEG-Yw', name: 'DelegateQuery', method: 'GET' }
  , { id: 'ZMvC7MPK1tvdjiLZScRoig', name: 'GroupsDelegateQuery', method: 'GET' }
  , { id: 'p4xnIqj6x0e3DhHr-e4sWw', name: 'MembersDelegateQuery', method: 'GET', features: ['responsive_web_graphql_timeline_navigation_enabled'] }
  , { id: '2HD9lnvauHCbl4wRw2P_QQ', name: 'useDelegateMutation_settings_Mutation', method: 'POST' }
  , { id: 'i2EKR2188nR4j0xHIkhoiw', name: 'useAddMemberModalMutation_add_Mutation', method: 'POST' }
  , { id: 'bt_mUik7_sqXKofZmEBzAw', name: 'useChangeMemberRoleModalMutation_change_Mutation', method: 'POST' }
  , { id: 'QSkmmm7WG94DG9AfV2QHkg', name: 'useMemberMenuMutation_cancel_invite_Mutation', method: 'POST' }
  , { id: 'R8K9DRNeWen33po2wpZhZw', name: 'useMemberMenuMutation_remove_Mutation', method: 'POST' }
  , { id: '35IlHo3PPoKCgjGN9PyBEQ', name: 'GroupMenuMutation', method: 'POST' }
  , { id: 'QLNN5GVLRMe93lHnX3Um2w', name: 'InviteMenu_reject_Mutation', method: 'POST' }
  , { id: 'DpdMDix7rAjl6SVAs3SNSQ', name: 'InviteMenu_accept_Mutation', method: 'POST' }
  , { id: 'ft92vAsha0RhDxwgq_ojWQ', name: 'SensitiveMediaSettingsQuery', method: 'GET' }
  , { id: 'YWGRWrle16Fb6JvAjvjoTQ', name: 'useEditSensitiveMediaSettingsMutation', method: 'POST' }
  , { id: 'ElqSLWFmsPL4NlZI5e1Grg', name: 'TopicFollow', method: 'POST', features: [] }
  , { id: 'cPCFdDAaqRjlMRYInZzoDA', name: 'TopicNotInterested', method: 'POST', features: [] }
  , { id: '4OUZZOonV2h60I0wdlQb_w', name: 'TopicByRestId', method: 'GET', features: [] }
  , { id: 'kSr8il8DLKUNpXLEDCPbfQ', name: 'TopicToFollowSidebar', method: 'GET', features: ['rweb_video_screen_enabled','rweb_cashtags_enabled','profile_label_improvements_pcf_label_in_post_enabled','responsive_web_profile_redirect_enabled','rweb_tipjar_consumption_enabled','verified_phone_label_enabled','creator_subscriptions_tweet_preview_api_enabled','responsive_web_graphql_timeline_navigation_enabled','premium_content_api_read_enabled','communities_web_enable_tweet_community_results_fetch','c9s_tweet_anatomy_moderator_badge_enabled','responsive_web_grok_analyze_button_fetch_trends_enabled','responsive_web_grok_analyze_post_followups_enabled','rweb_cashtags_composer_attachment_enabled','responsive_web_jetfuel_frame','rweb_sports_post_context_enabled','responsive_web_grok_share_attachment_enabled','responsive_web_grok_annotations_enabled','articles_preview_enabled','responsive_web_edit_tweet_api_enabled','rweb_conversational_replies_downvote_enabled','graphql_is_translatable_rweb_tweet_is_translatable_enabled','view_counts_everywhere_api_enabled','longform_notetweets_consumption_enabled','responsive_web_twitter_article_tweet_consumption_enabled','content_disclosure_indicator_enabled','content_disclosure_ai_generated_indicator_enabled','responsive_web_grok_show_grok_translated_post','responsive_web_grok_analysis_button_from_backend','post_ctas_fetch_enabled','freedom_of_speech_not_reach_fetch_enabled','standardized_nudges_misinfo','tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled','longform_notetweets_rich_text_read_enabled','longform_notetweets_inline_media_enabled','responsive_web_nested_quote_preview_enabled','responsive_web_grok_image_annotation_enabled','responsive_web_grok_imagine_annotation_enabled','responsive_web_grok_community_note_auto_translation_is_enabled','responsive_web_enhance_cards_enabled'] }
  , { id: '4tVnt6FoSxaX8L-mDDJo4Q', name: 'TopicUndoNotInterested', method: 'POST', features: [] }
  , { id: 'srwjU6JM_ZKTj_QMfUGNcw', name: 'TopicUnfollow', method: 'POST', features: [] }
];
