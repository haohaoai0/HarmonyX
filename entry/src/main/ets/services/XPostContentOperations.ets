// Operation metadata extracted from the official responsive-web bundle.
export class PostContentOperation {
  name: string = '';
  id: string = '';
  features: Record<string, boolean> = {};
  toggles: Record<string, boolean> = {};
}
export function postContentOperation(name: string): PostContentOperation {
  const operation: PostContentOperation = new PostContentOperation(); operation.name = name;
  if (name === 'TweetResultByRestId') {
    operation.id = 'CxpIrb-Lt2oBpojNjvDatg';
    operation.features = {
      'creator_subscriptions_tweet_preview_api_enabled': true,
      'premium_content_api_read_enabled': true,
      'communities_web_enable_tweet_community_results_fetch': true,
      'c9s_tweet_anatomy_moderator_badge_enabled': true,
      'responsive_web_grok_analyze_button_fetch_trends_enabled': false,
      'responsive_web_grok_analyze_post_followups_enabled': false,
      'rweb_cashtags_composer_attachment_enabled': false,
      'responsive_web_jetfuel_frame': false,
      'rweb_sports_post_context_enabled': true,
      'responsive_web_grok_share_attachment_enabled': false,
      'responsive_web_grok_annotations_enabled': false,
      'articles_preview_enabled': true,
      'responsive_web_edit_tweet_api_enabled': true,
      'rweb_conversational_replies_downvote_enabled': false,
      'graphql_is_translatable_rweb_tweet_is_translatable_enabled': true,
      'view_counts_everywhere_api_enabled': true,
      'longform_notetweets_consumption_enabled': true,
      'responsive_web_twitter_article_tweet_consumption_enabled': true,
      'content_disclosure_indicator_enabled': true,
      'content_disclosure_ai_generated_indicator_enabled': true,
      'responsive_web_grok_show_grok_translated_post': false,
      'responsive_web_grok_analysis_button_from_backend': false,
      'post_ctas_fetch_enabled': true,
      'rweb_cashtags_enabled': false,
      'freedom_of_speech_not_reach_fetch_enabled': true,
      'standardized_nudges_misinfo': true,
      'tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled': true,
      'longform_notetweets_rich_text_read_enabled': true,
      'longform_notetweets_inline_media_enabled': true,
      'profile_label_improvements_pcf_label_in_post_enabled': true,
      'responsive_web_profile_redirect_enabled': true,
      'rweb_tipjar_consumption_enabled': false,
      'verified_phone_label_enabled': false,
      'responsive_web_nested_quote_preview_enabled': false,
      'responsive_web_grok_image_annotation_enabled': false,
      'responsive_web_grok_imagine_annotation_enabled': false,
      'responsive_web_grok_community_note_auto_translation_is_enabled': false,
      'responsive_web_graphql_timeline_navigation_enabled': true,
    };
    operation.toggles = {
      'withArticleRichContentState': true,
      'withArticlePlainText': false,
      'withArticleSummaryText': false,
      'withArticleVoiceOver': false,
      'withGrokAnalyze': false,
      'withDisallowedReplyControls': false,
      'withPayments': false,
      'withDmBlocks': false,
      'withAuxiliaryUserLabels': false,
    };
  }
  if (name === 'BroadcastQuery') {
    operation.id = 'Qy6WzDo4D56jtlDteWDpGQ';
    operation.features = {
      'creator_subscriptions_tweet_preview_api_enabled': true,
      'premium_content_api_read_enabled': true,
      'communities_web_enable_tweet_community_results_fetch': true,
      'c9s_tweet_anatomy_moderator_badge_enabled': true,
      'responsive_web_grok_analyze_button_fetch_trends_enabled': false,
      'responsive_web_grok_analyze_post_followups_enabled': false,
      'rweb_cashtags_composer_attachment_enabled': false,
      'responsive_web_jetfuel_frame': false,
      'rweb_sports_post_context_enabled': true,
      'responsive_web_grok_share_attachment_enabled': false,
      'responsive_web_grok_annotations_enabled': false,
      'articles_preview_enabled': true,
      'profile_label_improvements_pcf_label_in_post_enabled': true,
      'responsive_web_profile_redirect_enabled': true,
      'rweb_tipjar_consumption_enabled': false,
      'verified_phone_label_enabled': false,
      'responsive_web_edit_tweet_api_enabled': true,
      'rweb_conversational_replies_downvote_enabled': false,
      'graphql_is_translatable_rweb_tweet_is_translatable_enabled': true,
      'view_counts_everywhere_api_enabled': true,
      'longform_notetweets_consumption_enabled': true,
      'responsive_web_twitter_article_tweet_consumption_enabled': true,
      'content_disclosure_indicator_enabled': true,
      'content_disclosure_ai_generated_indicator_enabled': true,
      'responsive_web_grok_show_grok_translated_post': false,
      'responsive_web_grok_analysis_button_from_backend': false,
      'post_ctas_fetch_enabled': true,
      'rweb_cashtags_enabled': false,
      'freedom_of_speech_not_reach_fetch_enabled': true,
      'standardized_nudges_misinfo': true,
      'tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled': true,
      'longform_notetweets_rich_text_read_enabled': true,
      'longform_notetweets_inline_media_enabled': true,
      'responsive_web_nested_quote_preview_enabled': false,
      'responsive_web_grok_image_annotation_enabled': false,
      'responsive_web_grok_imagine_annotation_enabled': false,
      'responsive_web_grok_community_note_auto_translation_is_enabled': false,
      'responsive_web_graphql_timeline_navigation_enabled': true,
    };
    operation.toggles = {
      'withPayments': false,
      'withArticleRichContentState': true,
      'withArticlePlainText': false,
      'withArticleSummaryText': false,
      'withArticleVoiceOver': false,
      'withGrokAnalyze': false,
      'withDisallowedReplyControls': false,
      'withAuxiliaryUserLabels': false,
    };
  }
  if (name === 'BirdwatchFetchOneNote') {
    operation.id = '1lt6XSRik4s93WG0BrEvig';
    operation.features = {
      'responsive_web_birdwatch_media_notes_enabled': true,
      'responsive_web_birdwatch_url_notes_enabled': true,
      'responsive_web_grok_community_note_translation_is_enabled': false,
      'responsive_web_birdwatch_fast_notes_badge_enabled': true,
      'responsive_web_birdwatch_live_note_enabled': true,
      'responsive_web_birdwatch_note_internal_insights_enabled': true,
      'responsive_web_grok_community_note_auto_translation_is_enabled': false,
      'responsive_web_graphql_timeline_navigation_enabled': true,
      'profile_label_improvements_pcf_label_in_post_enabled': true,
      'responsive_web_profile_redirect_enabled': true,
      'rweb_tipjar_consumption_enabled': false,
      'verified_phone_label_enabled': false,
    };
    operation.toggles = {
      'withPayments': false,
      'withAuxiliaryUserLabels': false,
    };
  }
  if (name === 'ArticleEntityResultByRestId') {
    operation.id = 'eUiP53I_YemhBOI2TMCI3A';
    operation.features = {
      'profile_label_improvements_pcf_label_in_post_enabled': true,
      'responsive_web_profile_redirect_enabled': true,
      'rweb_tipjar_consumption_enabled': false,
      'verified_phone_label_enabled': false,
      'responsive_web_graphql_timeline_navigation_enabled': true,
    };
    operation.toggles = {
      'withPayments': false,
      'withDmBlocks': false,
      'withAuxiliaryUserLabels': false,
    };
  }
  if (name === 'BirdwatchFetchAuthenticatedUserProfile') {
    operation.id = 'kD74-qBfrdRT5rO9YOl57g';
    operation.features = {
      'responsive_web_birdwatch_top_contributor_enabled': true,
      'responsive_web_birdwatch_mobile_nav_setting_enabled': true,
      'responsive_web_birdwatch_note_limit_enabled': true,
    };
    operation.toggles = {

    };
  }
  if (name === 'BirdwatchCreateRating') { operation.id = 'gbshFt1Vmddrlio4vHWhhQ'; }
  return operation;
}

