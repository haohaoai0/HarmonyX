// GENERATED FILE - do not edit by hand.
// Source: data/x-operations.json (396 operations).
// Regenerate with: npm run gen

export const FEATURE_SETS = Object.freeze({
  "A": [
    "grok_translations_timeline_user_bio_auto_translation_is_enabled",
    "unified_cards_ad_metadata_container_dynamic_card_content_query_enabled",
    "unified_cards_destination_url_params_enabled",
    "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled",
    "creator_subscriptions_tweet_preview_api_enabled",
    "immersive_video_status_linkable_timestamps",
    "profile_label_improvements_pcf_label_in_post_enabled",
    "blue_business_profile_image_shape_enabled",
    "super_follow_user_api_enabled",
    "super_follow_badge_privacy_enabled",
    "super_follow_exclusive_tweet_notifications_enabled",
    "profile_label_improvements_pcf_label_in_profile_enabled",
    "subscriptions_verification_info_enabled",
    "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled",
    "freedom_of_speech_not_reach_fetch_enabled",
    "tweetypie_unmention_optimization_enabled",
    "super_follow_tweet_api_enabled",
    "premium_content_api_read_enabled",
    "longform_notetweets_consumption_enabled",
    "articles_api_enabled",
    "grok_android_analyze_trend_fetch_enabled",
    "grok_translations_post_auto_translation_is_enabled",
    "grok_translations_community_note_auto_translation_is_enabled",
    "grok_translations_community_note_translation_is_enabled",
    "grok_translations_community_note_auto_translation_is_enabled",
    "longform_notetweets_rich_text_read_enabled",
    "longform_notetweets_inline_media_enabled"
  ],
  "B": [
    "blue_business_profile_image_shape_enabled",
    "super_follow_user_api_enabled",
    "super_follow_badge_privacy_enabled",
    "super_follow_exclusive_tweet_notifications_enabled",
    "subscriptions_verification_info_enabled",
    "immersive_video_status_linkable_timestamps",
    "profile_label_improvements_pcf_label_in_profile_enabled",
    "profile_label_improvements_pcf_label_in_post_enabled"
  ],
  "C": [
    "rweb_video_screen_enabled",
    "profile_label_improvements_pcf_label_in_post_enabled",
    "responsive_web_profile_redirect_enabled",
    "rweb_tipjar_consumption_enabled",
    "verified_phone_label_enabled",
    "creator_subscriptions_tweet_preview_api_enabled",
    "responsive_web_graphql_timeline_navigation_enabled",
    "responsive_web_graphql_skip_user_profile_image_extensions_enabled",
    "premium_content_api_read_enabled",
    "communities_web_enable_tweet_community_results_fetch",
    "c9s_tweet_anatomy_moderator_badge_enabled",
    "responsive_web_grok_analyze_button_fetch_trends_enabled",
    "responsive_web_grok_analyze_post_followups_enabled",
    "responsive_web_jetfuel_frame",
    "responsive_web_grok_share_attachment_enabled",
    "responsive_web_grok_annotations_enabled",
    "articles_preview_enabled",
    "responsive_web_edit_tweet_api_enabled",
    "graphql_is_translatable_rweb_tweet_is_translatable_enabled",
    "view_counts_everywhere_api_enabled",
    "longform_notetweets_consumption_enabled",
    "responsive_web_twitter_article_tweet_consumption_enabled",
    "content_disclosure_indicator_enabled",
    "content_disclosure_ai_generated_indicator_enabled",
    "responsive_web_grok_show_grok_translated_post",
    "responsive_web_grok_analysis_button_from_backend",
    "post_ctas_fetch_enabled",
    "freedom_of_speech_not_reach_fetch_enabled",
    "standardized_nudges_misinfo",
    "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled",
    "longform_notetweets_rich_text_read_enabled",
    "longform_notetweets_inline_media_enabled",
    "responsive_web_grok_image_annotation_enabled",
    "responsive_web_grok_imagine_annotation_enabled",
    "responsive_web_grok_community_note_auto_translation_is_enabled",
    "responsive_web_enhance_cards_enabled",
    "rweb_cashtags_enabled",
    "rweb_cashtags_composer_attachment_enabled",
    "rweb_conversational_replies_downvote_enabled"
  ]
});

export const OPERATIONS_BY_ENDPOINT = Object.freeze({
  "about_account_query": {
    "endpoint": "about_account_query",
    "operation": "AboutAccountQuery",
    "queryId": "zUnx-DLN9dkwOkNhTLySjg",
    "http": "GET",
    "features": ""
  },
  "about_profile_by_screen_name_query": {
    "endpoint": "about_profile_by_screen_name_query",
    "operation": "AboutProfileByScreenNameQuery",
    "queryId": "62UN8S7bK4WOniJg24qAGQ",
    "http": "GET",
    "features": [
      "subscriptions_verification_info_enabled"
    ]
  },
  "about_profile_query": {
    "endpoint": "about_profile_query",
    "operation": "AboutProfileQuery",
    "queryId": "u0L8vZ3R4Qa9TK6i9AlD8Q",
    "http": "GET",
    "features": [
      "subscriptions_verification_info_enabled"
    ]
  },
  "": {
    "endpoint": "",
    "operation": "XChatSendGrokMessagePlaintextMutation",
    "queryId": "qm71_NDegIBh5UY73hBXaQ",
    "http": "POST",
    "features": ""
  },
  "add_content_disclosure": {
    "endpoint": "add_content_disclosure",
    "operation": "AddContentDisclosure",
    "queryId": "3Ek07V45SX5LHFwA66gMRA",
    "http": "POST",
    "features": ""
  },
  "add_remove_user_from_list": {
    "endpoint": "add_remove_user_from_list",
    "operation": "AddRemoveUserFromList",
    "queryId": "uEKWWNM47dPfVj-G6Jm1iw",
    "http": "GET",
    "features": "A"
  },
  "add_super_follow_privacy": {
    "endpoint": "add_super_follow_privacy",
    "operation": "AddSuperFollowPrivacy",
    "queryId": "xIZJPQBK0Zz62_BDLNLHKw",
    "http": "POST",
    "features": ""
  },
  "all_subscribed_lists_timeline": {
    "endpoint": "all_subscribed_lists_timeline",
    "operation": "AllSubscribedListsTimeline",
    "queryId": "tbyr4x_yStp9gs5-r2Bmng",
    "http": "GET",
    "features": "A"
  },
  "article_tweets_timeline": {
    "endpoint": "article_tweets_timeline",
    "operation": "ArticleTweetsTimeline",
    "queryId": "9i4cwvYa25tJ1fLn0YmSxQ",
    "http": "GET",
    "features": "A"
  },
  "audiospace_add_sharing": {
    "endpoint": "audiospace_add_sharing",
    "operation": "AudiospaceAddSharing",
    "queryId": "kC8rCTUS8KQsEWu8rNgb2Q",
    "http": "POST",
    "features": "A"
  },
  "audiospace_browse_space_topics_query": {
    "endpoint": "audiospace_browse_space_topics_query",
    "operation": "AudiospaceBrowseSpaceTopicsQuery",
    "queryId": "IZ1drq74xph2Gym7gGgtRw",
    "http": "GET",
    "features": ""
  },
  "audiospace_by_rest_id": {
    "endpoint": "audiospace_by_rest_id",
    "operation": "AudiospaceByRestId",
    "queryId": "yBMgJyfQwePA6c1Eml6Ccg",
    "http": "GET",
    "features": "A"
  },
  "audiospace_delete_sharing": {
    "endpoint": "audiospace_delete_sharing",
    "operation": "AudiospaceDeleteSharing",
    "queryId": "PTAe3LYPhlCcPJtwpyyx-w",
    "http": "POST",
    "features": ""
  },
  "audiospace_is_subscribed_query": {
    "endpoint": "audiospace_is_subscribed_query",
    "operation": "AudiospaceIsSubscribedQuery",
    "queryId": "g1mB1D5y3z_NkFsN-FwZdA",
    "http": "GET",
    "features": ""
  },
  "audiospace_recommended_topics_query": {
    "endpoint": "audiospace_recommended_topics_query",
    "operation": "AudiospaceRecommendedTopicsQuery",
    "queryId": "olBPzZqwVkD-JeWridv1Ag",
    "http": "GET",
    "features": ""
  },
  "audiospace_sharings_query": {
    "endpoint": "audiospace_sharings_query",
    "operation": "AudiospaceSharingsQuery",
    "queryId": "IDafP-_BzEV626DsBCuO3A",
    "http": "GET",
    "features": "A"
  },
  "birdwatch_home_page_query": {
    "endpoint": "birdwatch_home_page_query",
    "operation": "BirdwatchHomePageQuery",
    "queryId": "EaseXgo3PuOAtCCcPXuukg",
    "http": "GET",
    "features": "A"
  },
  "bonus_follow_timeline": {
    "endpoint": "bonus_follow_timeline",
    "operation": "BonusFollowTimeline",
    "queryId": "Mm6llrZ8l92Zc4UlWqczag",
    "http": "GET",
    "features": "A"
  },
  "bookmark_add": {
    "endpoint": "bookmark_add",
    "operation": "BookmarkAdd",
    "queryId": "-V21wukAaCGXHbUZPZ2wGw",
    "http": "POST",
    "features": ""
  },
  "bookmark_collection_delete": {
    "endpoint": "bookmark_collection_delete",
    "operation": "BookmarkCollectionDelete",
    "queryId": "kPKvx90Yw0QiE57ZDTaSXg",
    "http": "POST",
    "features": ""
  },
  "bookmark_collections_slices": {
    "endpoint": "bookmark_collections_slices",
    "operation": "BookmarkCollectionsSlices",
    "queryId": "2t0nIPPGZMrejvawhKKKoA",
    "http": "GET",
    "features": ""
  },
  "bookmark_collection_timeline": {
    "endpoint": "bookmark_collection_timeline",
    "operation": "BookmarkCollectionTimeline",
    "queryId": "BchEEvsgjQwHR3ykTXTu5A",
    "http": "GET",
    "features": "A"
  },
  "bookmark_collection_tweet_delete": {
    "endpoint": "bookmark_collection_tweet_delete",
    "operation": "BookmarkCollectionTweetDelete",
    "queryId": "8lNl-w60Xiy3Vr_M93MwCw",
    "http": "POST",
    "features": ""
  },
  "bookmark_collection_tweet_put": {
    "endpoint": "bookmark_collection_tweet_put",
    "operation": "BookmarkCollectionTweetPut",
    "queryId": "DVFlV1M7raa019Sazd9gfw",
    "http": "POST",
    "features": ""
  },
  "bookmark_collection_update": {
    "endpoint": "bookmark_collection_update",
    "operation": "BookmarkCollectionUpdate",
    "queryId": "O1cGsRi3D4ULp2AcBRGvEQ",
    "http": "POST",
    "features": ""
  },
  "bookmark_delete": {
    "endpoint": "bookmark_delete",
    "operation": "BookmarkDelete",
    "queryId": "G-V_AGDp-QKivnyTUCtTjA",
    "http": "POST",
    "features": ""
  },
  "bookmark_search_timeline": {
    "endpoint": "bookmark_search_timeline",
    "operation": "BookmarkSearchTimeline",
    "queryId": "NzAqD7b7RxntmSe6r-IF_g",
    "http": "GET",
    "features": "A"
  },
  "bookmark_timeline_v2": {
    "endpoint": "bookmark_timeline_v2",
    "operation": "BookmarkTimelineV2",
    "queryId": "rJ9ld5zrgDFL0HkGKuqbOA",
    "http": "GET",
    "features": "A"
  },
  "broadcast_show": {
    "endpoint": "broadcast_show",
    "operation": "BroadcastShow",
    "queryId": "1q22bHXXPwQ6WhQ0yJFTgg",
    "http": "GET",
    "features": ""
  },
  "carousel_immersive_video_explore_mixer_timeline": {
    "endpoint": "carousel_immersive_video_explore_mixer_timeline",
    "operation": "CarouselImmersiveVideoExploreMixerTimeline",
    "queryId": "WAjmL_GQ-ahMT7mGNbhCkw",
    "http": "GET",
    "features": "A"
  },
  "commerce_catalog_by_rest_id": {
    "endpoint": "commerce_catalog_by_rest_id",
    "operation": "CommerceCatalogByRestId",
    "queryId": "op45JI_mrPT8KZnhvt5Q9w",
    "http": "GET",
    "features": ""
  },
  "commerce_product_result_by_key_and_merchant": {
    "endpoint": "commerce_product_result_by_key_and_merchant",
    "operation": "CommerceProductResultByKeyAndMerchant",
    "queryId": "MsYsJKz9_k2dmWpyyU-Xww",
    "http": "GET",
    "features": ""
  },
  "commerce_product_set_drop_by_rest_id": {
    "endpoint": "commerce_product_set_drop_by_rest_id",
    "operation": "CommerceProductSetDropByRestId",
    "queryId": "S1AswHQxrGM8nC4sQZDUDA",
    "http": "GET",
    "features": ""
  },
  "commerce_user_result_by_id_query": {
    "endpoint": "commerce_user_result_by_id_query",
    "operation": "CommerceUserResultByIdQuery",
    "queryId": "nEId-a30usjl43GF9QGRiA",
    "http": "GET",
    "features": "B"
  },
  "communities_eligible_for_profile_spotlight_slice": {
    "endpoint": "communities_eligible_for_profile_spotlight_slice",
    "operation": "CommunitiesEligibleForProfileSpotlightSlice",
    "queryId": "9iNfj_Itz-Sh-4wqKvwPkw",
    "http": "GET",
    "features": "B"
  },
  "communities_explore_timeline_query": {
    "endpoint": "communities_explore_timeline_query",
    "operation": "CommunitiesExploreTimelineQuery",
    "queryId": "Kzmtz-qrV-gWn1OowsTrkg",
    "http": "GET",
    "features": "A"
  },
  "communities_invite_typeahead_query": {
    "endpoint": "communities_invite_typeahead_query",
    "operation": "CommunitiesInviteTypeaheadQuery",
    "queryId": "cGaVxuY9j1EkBnLbFHFkIQ",
    "http": "GET",
    "features": "B"
  },
  "communities_members_all_query": {
    "endpoint": "communities_members_all_query",
    "operation": "CommunitiesMembersAllQuery",
    "queryId": "I6yQVpfpvXNmc7JCcsAkFQ",
    "http": "GET",
    "features": "A"
  },
  "communities_members_moderators_query": {
    "endpoint": "communities_members_moderators_query",
    "operation": "CommunitiesMembersModeratorsQuery",
    "queryId": "UjnoK9Cn2ijSxXFN53EAew",
    "http": "GET",
    "features": "A"
  },
  "communities_my_query": {
    "endpoint": "communities_my_query",
    "operation": "CommunitiesMyQuery",
    "queryId": "9vLFRLBZf1gAXPWNNXK0bA",
    "http": "GET",
    "features": "A"
  },
  "communities_search_slice": {
    "endpoint": "communities_search_slice",
    "operation": "CommunitiesSearchSlice",
    "queryId": "Irxn8IdeoUqcgaR7cH-vQw",
    "http": "GET",
    "features": "B"
  },
  "communities_timeline_query": {
    "endpoint": "communities_timeline_query",
    "operation": "CommunitiesTimelineQuery",
    "queryId": "ArVwiwYbRMahViraOZ7L1Q",
    "http": "GET",
    "features": "A"
  },
  "community_create_mutation": {
    "endpoint": "community_create_mutation",
    "operation": "CommunityCreateMutation",
    "queryId": "oHcA4UQluHCZgtq3qrxdYQ",
    "http": "POST",
    "features": "B"
  },
  "community_create_rule_mutation": {
    "endpoint": "community_create_rule_mutation",
    "operation": "CommunityCreateRuleMutation",
    "queryId": "xOCFa41vTCDsYqqd__NxOg",
    "http": "POST",
    "features": "B"
  },
  "community_delete_custom_banner_media_mutation": {
    "endpoint": "community_delete_custom_banner_media_mutation",
    "operation": "CommunityDeleteCustomBannerMediaMutation",
    "queryId": "VWY_ZzVIHSHR9uH_z57TpA",
    "http": "POST",
    "features": "B"
  },
  "community_delete_mutation": {
    "endpoint": "community_delete_mutation",
    "operation": "CommunityDeleteMutation",
    "queryId": "JlDBft63PFjLWoTxIlZdqw",
    "http": "POST",
    "features": ""
  },
  "community_description_put_mutation": {
    "endpoint": "community_description_put_mutation",
    "operation": "CommunityDescriptionPutMutation",
    "queryId": "QXzsLtkfLJGlhQfNoXDhyw",
    "http": "POST",
    "features": "B"
  },
  "community_discovery_timeline_query": {
    "endpoint": "community_discovery_timeline_query",
    "operation": "CommunityDiscoveryTimelineQuery",
    "queryId": "VVZDlhiD2HW2rG5gQMHEyA",
    "http": "GET",
    "features": "A"
  },
  "community_hashtag_search_query": {
    "endpoint": "community_hashtag_search_query",
    "operation": "CommunityHashtagSearchQuery",
    "queryId": "zdU7yQ5zkqd4nx4pg2dwbg",
    "http": "GET",
    "features": "A"
  },
  "community_info_query": {
    "endpoint": "community_info_query",
    "operation": "CommunityInfoQuery",
    "queryId": "bEHr0jP--kVelB1LdmsLvA",
    "http": "GET",
    "features": "B"
  },
  "community_is_nsfw_put_mutation": {
    "endpoint": "community_is_nsfw_put_mutation",
    "operation": "CommunityIsNsfwPutMutation",
    "queryId": "Ol9sO7-KpKQBNAHj8IVTpA",
    "http": "POST",
    "features": "B"
  },
  "community_join_query": {
    "endpoint": "community_join_query",
    "operation": "CommunityJoinQuery",
    "queryId": "rSwKIJyfLBlfpIfToNEOuA",
    "http": "POST",
    "features": "B"
  },
  "community_join_request_create": {
    "endpoint": "community_join_request_create",
    "operation": "CommunityJoinRequestCreate",
    "queryId": "NqQpLMROrEo2i_4UVZh_iQ",
    "http": "POST",
    "features": "B"
  },
  "community_leave_query": {
    "endpoint": "community_leave_query",
    "operation": "CommunityLeaveQuery",
    "queryId": "FiTgUFDLVIRbuAzOJx1KdQ",
    "http": "POST",
    "features": "B"
  },
  "community_media_timeline_query": {
    "endpoint": "community_media_timeline_query",
    "operation": "CommunityMediaTimelineQuery",
    "queryId": "rROnU2LtaF__xVSssdA68A",
    "http": "GET",
    "features": "A"
  },
  "community_member_requests": {
    "endpoint": "community_member_requests",
    "operation": "CommunityMemberRequests",
    "queryId": "TBrVaJlYqHqw5DkamL4Wog",
    "http": "GET",
    "features": "B"
  },
  "community_membership_settings_put": {
    "endpoint": "community_membership_settings_put",
    "operation": "CommunityMembershipSettingsPut",
    "queryId": "xfHYqyoN3RJNujUUi1dq1Q",
    "http": "POST",
    "features": ""
  },
  "community_memberships_slice": {
    "endpoint": "community_memberships_slice",
    "operation": "CommunityMembershipsSlice",
    "queryId": "RABbw6Lt2zgSplZAyZc9yQ",
    "http": "GET",
    "features": "B"
  },
  "community_members_search": {
    "endpoint": "community_members_search",
    "operation": "CommunityMembersSearch",
    "queryId": "Sy_t002IJ_VE3dAG_V3DlA",
    "http": "GET",
    "features": "B"
  },
  "community_members_slice": {
    "endpoint": "community_members_slice",
    "operation": "CommunityMembersSlice",
    "queryId": "R16X9FjpZaWAj1SWtcviPA",
    "http": "GET",
    "features": "B"
  },
  "community_moderation_keep_tweet_mutation": {
    "endpoint": "community_moderation_keep_tweet_mutation",
    "operation": "CommunityModerationKeepTweetMutation",
    "queryId": "k7C4ATBAOav_BMHaARnifw",
    "http": "POST",
    "features": "B"
  },
  "community_moderation_tweet_case_reports_slice": {
    "endpoint": "community_moderation_tweet_case_reports_slice",
    "operation": "CommunityModerationTweetCaseReportsSlice",
    "queryId": "BsmV5mNM90xhHEur02gcdQ",
    "http": "GET",
    "features": "B"
  },
  "community_moderation_tweet_cases_slice": {
    "endpoint": "community_moderation_tweet_cases_slice",
    "operation": "CommunityModerationTweetCasesSlice",
    "queryId": "gCE2Tbb9jVaeVlUAiyzvfQ",
    "http": "GET",
    "features": "A"
  },
  "community_moderator_approve_request_rtj": {
    "endpoint": "community_moderator_approve_request_rtj",
    "operation": "CommunityModeratorApproveRequestRtj",
    "queryId": "kx20yeony6OEU-3Ywu2kJQ",
    "http": "POST",
    "features": "B"
  },
  "community_moderator_deny_request_rtj": {
    "endpoint": "community_moderator_deny_request_rtj",
    "operation": "CommunityModeratorDenyRequestRtj",
    "queryId": "EppyHLVkgrv7otVwQ1PllA",
    "http": "POST",
    "features": "B"
  },
  "community_moderators_slice": {
    "endpoint": "community_moderators_slice",
    "operation": "CommunityModeratorsSlice",
    "queryId": "WMO95InkVJUuUxHInFfyrA",
    "http": "GET",
    "features": "B"
  },
  "community_name_put_mutation": {
    "endpoint": "community_name_put_mutation",
    "operation": "CommunityNamePutMutation",
    "queryId": "uN4YI5IzzNu7GCmChaP9dg",
    "http": "POST",
    "features": "B"
  },
  "community_notification_settings_put": {
    "endpoint": "community_notification_settings_put",
    "operation": "CommunityNotificationSettingsPut",
    "queryId": "p63ohfUyKiuNkjoFNitdpw",
    "http": "POST",
    "features": "B"
  },
  "community_put_access_mutation": {
    "endpoint": "community_put_access_mutation",
    "operation": "CommunityPutAccessMutation",
    "queryId": "MmpsbUxs9rWu7bIwvPu5iw",
    "http": "POST",
    "features": "B"
  },
  "community_put_custom_banner_media_mutation": {
    "endpoint": "community_put_custom_banner_media_mutation",
    "operation": "CommunityPutCustomBannerMediaMutation",
    "queryId": "vyj86DZS6bHE_8ng7JK1oQ",
    "http": "POST",
    "features": "B"
  },
  "community_put_role_mutation": {
    "endpoint": "community_put_role_mutation",
    "operation": "CommunityPutRoleMutation",
    "queryId": "XJdcD4nIy4gtjdgzbrhWxg",
    "http": "POST",
    "features": "B"
  },
  "community_put_theme_mutation": {
    "endpoint": "community_put_theme_mutation",
    "operation": "CommunityPutThemeMutation",
    "queryId": "pVcjdirmdoOA_LrmI8OiPQ",
    "http": "POST",
    "features": "B"
  },
  "community_question_put_mutation": {
    "endpoint": "community_question_put_mutation",
    "operation": "CommunityQuestionPutMutation",
    "queryId": "zdwUkzBoW_QDNZgUuyukfw",
    "http": "POST",
    "features": "B"
  },
  "community_ranked_timeline_query": {
    "endpoint": "community_ranked_timeline_query",
    "operation": "CommunityRankedTimelineQuery",
    "queryId": "IbzoC9dQCnsObZT2hux3Wg",
    "http": "GET",
    "features": "A"
  },
  "community_remove_rule_mutation": {
    "endpoint": "community_remove_rule_mutation",
    "operation": "CommunityRemoveRuleMutation",
    "queryId": "SWQAUTwDnKld8PmuI_qHqQ",
    "http": "POST",
    "features": "B"
  },
  "community_reorder_rules_mutation": {
    "endpoint": "community_reorder_rules_mutation",
    "operation": "CommunityReorderRulesMutation",
    "queryId": "yYZYyj9qNpcp7fUA7qiWHw",
    "http": "POST",
    "features": "B"
  },
  "community_topic_put_mutation": {
    "endpoint": "community_topic_put_mutation",
    "operation": "CommunityTopicPutMutation",
    "queryId": "rtZELWQjbanMtC7MiQhaQA",
    "http": "POST",
    "features": "B"
  },
  "community_tweet_pin_mutation": {
    "endpoint": "community_tweet_pin_mutation",
    "operation": "CommunityTweetPinMutation",
    "queryId": "RjSIAwLZ8xuLNFiso5CuoQ",
    "http": "POST",
    "features": ""
  },
  "community_tweet_unpin_mutation": {
    "endpoint": "community_tweet_unpin_mutation",
    "operation": "CommunityTweetUnpinMutation",
    "queryId": "TK-NHiG8XZeS3eb08BxVhw",
    "http": "POST",
    "features": ""
  },
  "community_update_hashtag_mutation": {
    "endpoint": "community_update_hashtag_mutation",
    "operation": "CommunityUpdateHashtagMutation",
    "queryId": "FwxmeuTYsnuCQq5MUxpj2g",
    "http": "POST",
    "features": "B"
  },
  "community_update_rule_mutation": {
    "endpoint": "community_update_rule_mutation",
    "operation": "CommunityUpdateRuleMutation",
    "queryId": "NKP_gS_p3iOu3X6vJnmz0w",
    "http": "POST",
    "features": "B"
  },
  "community_update_search_tags_mutation": {
    "endpoint": "community_update_search_tags_mutation",
    "operation": "CommunityUpdateSearchTagsMutation",
    "queryId": "u1AVfRfzvsB17ONypzZQaQ",
    "http": "POST",
    "features": "B"
  },
  "connect_tab": {
    "endpoint": "connect_tab",
    "operation": "ConnectTab",
    "queryId": "RTJc0G9YcNe8TWuewkngkA",
    "http": "GET",
    "features": "A"
  },
  "conversation_timeline_v2": {
    "endpoint": "conversation_timeline_v2",
    "operation": "ConversationTimelineV2",
    "queryId": "ynuAOEJ9yj3sUrd0OQb2eQ",
    "http": "GET",
    "features": "A"
  },
  "create_commerce_product_set": {
    "endpoint": "create_commerce_product_set",
    "operation": "CreateCommerceProductSet",
    "queryId": "5_Qxn8NnKGtMPxQPruYp_g",
    "http": "POST",
    "features": ""
  },
  "create_conversation_pinned_tweet": {
    "endpoint": "create_conversation_pinned_tweet",
    "operation": "CreateConversationPinnedTweet",
    "queryId": "e3H1Np2VoeQV0Q4DM-m-2A",
    "http": "POST",
    "features": ""
  },
  "create_humanization_nudge": {
    "endpoint": "create_humanization_nudge",
    "operation": "CreateHumanizationNudge",
    "queryId": "5rFCYANcz_YmwllYWd8ulA",
    "http": "POST",
    "features": ""
  },
  "create_note_tweet": {
    "endpoint": "create_note_tweet",
    "operation": "CreateNoteTweet",
    "queryId": "O5XC8wy4c9gvHD--ESnFSw",
    "http": "POST",
    "features": "A"
  },
  "create_nudge": {
    "endpoint": "create_nudge",
    "operation": "CreateNudge",
    "queryId": "wFmywMJdr-hzxtC6yG5ZuA",
    "http": "POST",
    "features": ""
  },
  "create_retweet": {
    "endpoint": "create_retweet",
    "operation": "CreateRetweet",
    "queryId": "mbRO74GrOvSfRcJnlMapnQ",
    "http": "POST",
    "features": "A"
  },
  "create_tweet": {
    "endpoint": "create_tweet",
    "operation": "CreateTweet",
    "queryId": "GYdIGqVWfZNho79bQ2XDoA",
    "http": "POST",
    "features": "A"
  },
  "create_tweet_with_undo": {
    "endpoint": "create_tweet_with_undo",
    "operation": "CreateTweetWithUndo",
    "queryId": "kc9IvxKXLkIvY3ldZukHDg",
    "http": "POST",
    "features": ""
  },
  "creator_subscriptions_timeline_query": {
    "endpoint": "creator_subscriptions_timeline_query",
    "operation": "CreatorSubscriptionsTimelineQuery",
    "queryId": "MkuUVjfQX61A4xH4mSxN5A",
    "http": "GET",
    "features": "A"
  },
  "delegate_list_delegation_groups_query": {
    "endpoint": "delegate_list_delegation_groups_query",
    "operation": "DelegateListDelegationGroupsQuery",
    "queryId": "3zACe70xDse-DL5ZzC_FJA",
    "http": "GET",
    "features": "B"
  },
  "delete_content_disclosure": {
    "endpoint": "delete_content_disclosure",
    "operation": "DeleteContentDisclosure",
    "queryId": "4bn0nJkcKya0sixErE_ixw",
    "http": "POST",
    "features": ""
  },
  "delete_conversation_pinned_tweet": {
    "endpoint": "delete_conversation_pinned_tweet",
    "operation": "DeleteConversationPinnedTweet",
    "queryId": "AIoKJbPhwO-7lCdZz4ivdw",
    "http": "POST",
    "features": ""
  },
  "delete_draft_tweet": {
    "endpoint": "delete_draft_tweet",
    "operation": "DeleteDraftTweet",
    "queryId": "N9XszeuKTQsVfwsjaC69WQ",
    "http": "POST",
    "features": ""
  },
  "delete_retweet": {
    "endpoint": "delete_retweet",
    "operation": "DeleteRetweet",
    "queryId": "ZyZigVsNiFO6v1dEks1eWg",
    "http": "POST",
    "features": ""
  },
  "delete_tweet": {
    "endpoint": "delete_tweet",
    "operation": "DeleteTweet",
    "queryId": "nxpZCY2K-I6QoFHAHeojFQ",
    "http": "POST",
    "features": ""
  },
  "disable_user_account_label": {
    "endpoint": "disable_user_account_label",
    "operation": "DisableUserAccountLabel",
    "queryId": "_ckHEj05gan2VfNHG6thBA",
    "http": "POST",
    "features": ""
  },
  "disable_verified_phone_label": {
    "endpoint": "disable_verified_phone_label",
    "operation": "DisableVerifiedPhoneLabel",
    "queryId": "GgA_lP_kCppRoBKvrdnefw",
    "http": "POST",
    "features": ""
  },
  "dm_client_add_conversation_label_mutation": {
    "endpoint": "dm_client_add_conversation_label_mutation",
    "operation": "DmClientAddConversationLabelMutation",
    "queryId": "wresodBLD4xXZgtUreymOQ",
    "http": "POST",
    "features": ""
  },
  "dm_client_conversation_labels_query": {
    "endpoint": "dm_client_conversation_labels_query",
    "operation": "DmClientConversationLabelsQuery",
    "queryId": "q4LiIZ0HjhzLLoKUwQLUJA",
    "http": "GET",
    "features": ""
  },
  "dm_client_delete_conversation_label_mutation": {
    "endpoint": "dm_client_delete_conversation_label_mutation",
    "operation": "DmClientDeleteConversationLabelMutation",
    "queryId": "JoRjWtplNLRVEwL3GlXo3g",
    "http": "POST",
    "features": ""
  },
  "dm_client_education_flags_query": {
    "endpoint": "dm_client_education_flags_query",
    "operation": "DmClientEducationFlagsQuery",
    "queryId": "PjbVlSKO16LqZMMXPbZRww",
    "http": "GET",
    "features": ""
  },
  "dm_client_education_flags_update": {
    "endpoint": "dm_client_education_flags_update",
    "operation": "DmClientEducationFlagsUpdate",
    "queryId": "RCi-0mNWwT3z1kOlStYmeg",
    "http": "POST",
    "features": ""
  },
  "dm_client_modular_search_query_all": {
    "endpoint": "dm_client_modular_search_query_all",
    "operation": "DmClientModularSearchQueryAll",
    "queryId": "-Cx-v10mNXJYwJpcwpehoA",
    "http": "GET",
    "features": "A"
  },
  "dm_muted_users_timeline_query": {
    "endpoint": "dm_muted_users_timeline_query",
    "operation": "DmMutedUsersTimelineQuery",
    "queryId": "EEovcHXJXFJtBHnKHANOgw",
    "http": "GET",
    "features": "A"
  },
  "edit_draft_tweet": {
    "endpoint": "edit_draft_tweet",
    "operation": "EditDraftTweet",
    "queryId": "twf753nZ7krWNelKcm4Pww",
    "http": "POST",
    "features": ""
  },
  "edit_history_timeline": {
    "endpoint": "edit_history_timeline",
    "operation": "EditHistoryTimeline",
    "queryId": "yTjoiI4_lZO3FwiUSoFsCQ",
    "http": "GET",
    "features": "A"
  },
  "exclusive_tweet_follow": {
    "endpoint": "exclusive_tweet_follow",
    "operation": "ExclusiveTweetFollow",
    "queryId": "HpKeTQhHvXJRlyIfpCfI-w",
    "http": "POST",
    "features": ""
  },
  "exclusive_tweet_unfollow": {
    "endpoint": "exclusive_tweet_unfollow",
    "operation": "ExclusiveTweetUnfollow",
    "queryId": "xzwqNvWt_NYHS2imizbZHQ",
    "http": "POST",
    "features": ""
  },
  "explore": {
    "endpoint": "explore",
    "operation": "Explore",
    "queryId": "Zj8saoqORjPaB8FKXwaYPg",
    "http": "GET",
    "features": "A"
  },
  "favoriters_timeline": {
    "endpoint": "favoriters_timeline",
    "operation": "FavoritersTimeline",
    "queryId": "BK7iAo3fXG0bjpwEKWa74Q",
    "http": "GET",
    "features": "A"
  },
  "favorites_by_time_timeline_v2": {
    "endpoint": "favorites_by_time_timeline_v2",
    "operation": "FavoritesByTimeTimelineV2",
    "queryId": "dsnvKsvXlO8lZAVXMPuAQQ",
    "http": "GET",
    "features": "A"
  },
  "favorite_tweet": {
    "endpoint": "favorite_tweet",
    "operation": "FavoriteTweet",
    "queryId": "lI07N6Otwv1PhnEgXILM7A",
    "http": "POST",
    "features": ""
  },
  "feature_settings_update": {
    "endpoint": "feature_settings_update",
    "operation": "FeatureSettingsUpdate",
    "queryId": "-btar_vkBwWA7s3YWfp_9g",
    "http": "POST",
    "features": ""
  },
  "fetch_popular_communities": {
    "endpoint": "fetch_popular_communities",
    "operation": "FetchPopularCommunities",
    "queryId": "EiMwFEG2PzOn979HpG23Pw",
    "http": "GET",
    "features": "B"
  },
  "fetch_user_community_topics": {
    "endpoint": "fetch_user_community_topics",
    "operation": "FetchUserCommunityTopics",
    "queryId": "cB8JuuBREn4Myv74lL_hYg",
    "http": "GET",
    "features": ""
  },
  "fleets_stickers_search": {
    "endpoint": "fleets_stickers_search",
    "operation": "FleetsStickersSearch",
    "queryId": "K53PIWlaebqBe1CNf0pVhg",
    "http": "GET",
    "features": ""
  },
  "fleets_stickers_suggestion": {
    "endpoint": "fleets_stickers_suggestion",
    "operation": "FleetsStickersSuggestion",
    "queryId": "TdmKeqM35mQR7e9MueyYMw",
    "http": "GET",
    "features": ""
  },
  "generate_maps_url_from_address": {
    "endpoint": "generate_maps_url_from_address",
    "operation": "GenerateMapsUrlFromAddress",
    "queryId": "hr7n-QUOy6nTRhWIaZKdhg",
    "http": "GET",
    "features": ""
  },
  "get_conversation_control_settings": {
    "endpoint": "get_conversation_control_settings",
    "operation": "GetConversationControlSettings",
    "queryId": "uSS1UZnreGvtXo8463kSxQ",
    "http": "GET",
    "features": ""
  },
  "get_draft_tweets": {
    "endpoint": "get_draft_tweets",
    "operation": "GetDraftTweets",
    "queryId": "HaOsXLTy8FkNUD58u-RfZg",
    "http": "GET",
    "features": ""
  },
  "get_username_availability_and_suggestions": {
    "endpoint": "get_username_availability_and_suggestions",
    "operation": "GetUsernameAvailabilityAndSuggestions",
    "queryId": "zmlkjCoEDEMzTCuLlOKPAA",
    "http": "POST",
    "features": ""
  },
  "global_communities_latest_post_search_timeline": {
    "endpoint": "global_communities_latest_post_search_timeline",
    "operation": "GlobalCommunitiesLatestPostSearchTimeline",
    "queryId": "Fae3b6-iWlKR2xnc2V-fiw",
    "http": "GET",
    "features": "C"
  },
  "global_communities_post_search_timeline": {
    "endpoint": "global_communities_post_search_timeline",
    "operation": "GlobalCommunitiesPostSearchTimeline",
    "queryId": "flrmikCoPPiQobzbRlBizg",
    "http": "GET",
    "features": "C"
  },
  "global_mention_settings_put": {
    "endpoint": "global_mention_settings_put",
    "operation": "GlobalMentionSettingsPut",
    "queryId": "mHn0VT8f-v4qtt12DeZIEQ",
    "http": "POST",
    "features": ""
  },
  "grok_auto_translation_toggle_mutation": {
    "endpoint": "grok_auto_translation_toggle_mutation",
    "operation": "GrokAutoTranslationToggleMutation",
    "queryId": "3f9Qr6WPCh76-ip7h2r-tA",
    "http": "POST",
    "features": ""
  },
  "grok_auto_translation_toggle_query": {
    "endpoint": "grok_auto_translation_toggle_query",
    "operation": "GrokAutoTranslationToggleQuery",
    "queryId": "J0iibs_CtTMRvj1R7Iykmg",
    "http": "GET",
    "features": ""
  },
  "home_timeline": {
    "endpoint": "home_timeline",
    "operation": "HomeTimeline",
    "queryId": "ob5uGlwVI-iAKKFx9YXoqg",
    "http": "GET",
    "features": "A"
  },
  "home_timeline_latest": {
    "endpoint": "home_timeline_latest",
    "operation": "HomeTimelineLatest",
    "queryId": "GQ6KFu0SWm7PFm62aMik5Q",
    "http": "GET",
    "features": "A"
  },
  "home_timeline_subscriptions": {
    "endpoint": "home_timeline_subscriptions",
    "operation": "HomeTimelineSubscriptions",
    "queryId": "QoCcCX98Vugy3DwpJf5pnw",
    "http": "GET",
    "features": "A"
  },
  "immersive_viewer_explore_mixer_timeline": {
    "endpoint": "immersive_viewer_explore_mixer_timeline",
    "operation": "ImmersiveViewerExploreMixerTimeline",
    "queryId": "UsztxIRwP6dxXKuVoQTIRw",
    "http": "GET",
    "features": "A"
  },
  "is_identity_verified_label_hidden_put": {
    "endpoint": "is_identity_verified_label_hidden_put",
    "operation": "IsIdentityVerifiedLabelHiddenPut",
    "queryId": "KmEBnm_9O0-m_eRYZ6yqUA",
    "http": "POST",
    "features": ""
  },
  "list_by_id_query": {
    "endpoint": "list_by_id_query",
    "operation": "ListByIdQuery",
    "queryId": "yJMGpM1RdI_3phPHH__0yQ",
    "http": "GET",
    "features": "B"
  },
  "list_create": {
    "endpoint": "list_create",
    "operation": "ListCreate",
    "queryId": "KMsf_KtiCWe5Rm0mAGSc4w",
    "http": "POST",
    "features": "B"
  },
  "list_create_recommended_users_timeline": {
    "endpoint": "list_create_recommended_users_timeline",
    "operation": "ListCreateRecommendedUsersTimeline",
    "queryId": "ReCJYeLHY2VGcSxFNtsZhA",
    "http": "GET",
    "features": "A"
  },
  "list_delete": {
    "endpoint": "list_delete",
    "operation": "ListDelete",
    "queryId": "GaNPVF9EcFNrK01zcocfjQ",
    "http": "POST",
    "features": ""
  },
  "list_delete_banner_media": {
    "endpoint": "list_delete_banner_media",
    "operation": "ListDeleteBannerMedia",
    "queryId": "07FMxdyHNUu22qrMlFAk_A",
    "http": "POST",
    "features": "B"
  },
  "list_edit_recommended_users_timeline": {
    "endpoint": "list_edit_recommended_users_timeline",
    "operation": "ListEditRecommendedUsersTimeline",
    "queryId": "3swSgnFQkNtBhhi2hSa0Vw",
    "http": "GET",
    "features": "A"
  },
  "list_member_add": {
    "endpoint": "list_member_add",
    "operation": "ListMemberAdd",
    "queryId": "RbKnkhWtKALMS6HHfiZoZg",
    "http": "POST",
    "features": "B"
  },
  "list_member_remove": {
    "endpoint": "list_member_remove",
    "operation": "ListMemberRemove",
    "queryId": "U-6aeEPiVJGzvDDTrsvBmw",
    "http": "POST",
    "features": "B"
  },
  "list_membership": {
    "endpoint": "list_membership",
    "operation": "ListMembership",
    "queryId": "9iZQVKdMyngPnty1C1nRcw",
    "http": "GET",
    "features": "A"
  },
  "list_membership_by_screen_name": {
    "endpoint": "list_membership_by_screen_name",
    "operation": "ListMembershipByScreenName",
    "queryId": "QxyJEqANLHiOv5zPm0InJQ",
    "http": "GET",
    "features": "A"
  },
  "list_members_timeline_query": {
    "endpoint": "list_members_timeline_query",
    "operation": "ListMembersTimelineQuery",
    "queryId": "vGLgs46I2qul03193HUbBg",
    "http": "GET",
    "features": "A"
  },
  "list_put_banner_media": {
    "endpoint": "list_put_banner_media",
    "operation": "ListPutBannerMedia",
    "queryId": "NBHhKRCbMLaTHKhaqmTFyg",
    "http": "POST",
    "features": "B"
  },
  "list_subscribers_timeline_query": {
    "endpoint": "list_subscribers_timeline_query",
    "operation": "ListSubscribersTimelineQuery",
    "queryId": "kvpzagUdyPrnbHrqbEgSOA",
    "http": "GET",
    "features": "A"
  },
  "list_timeline": {
    "endpoint": "list_timeline",
    "operation": "ListTimeline",
    "queryId": "wpHYCmyAIJMeqCtrol-8iQ",
    "http": "GET",
    "features": "A"
  },
  "list_update": {
    "endpoint": "list_update",
    "operation": "ListUpdate",
    "queryId": "K_kCz0uS1FtS9evq19N5vg",
    "http": "POST",
    "features": "B"
  },
  "logged_out_mr_by_id": {
    "endpoint": "logged_out_mr_by_id",
    "operation": "LoggedOutMrById",
    "queryId": "3FLq_70RtztZLCNkjDYkKQ",
    "http": "GET",
    "features": ""
  },
  "media_timeline_v2": {
    "endpoint": "media_timeline_v2",
    "operation": "MediaTimelineV2",
    "queryId": "gegyTdW8YAo0uCX9eVFk3Q",
    "http": "GET",
    "features": "A"
  },
  "moderated_timeline": {
    "endpoint": "moderated_timeline",
    "operation": "ModeratedTimeline",
    "queryId": "th7flEwW9aU2-Rj9Xr8Jbg",
    "http": "GET",
    "features": "A"
  },
  "mutation_subscribe_to_drop": {
    "endpoint": "mutation_subscribe_to_drop",
    "operation": "MutationSubscribeToDrop",
    "queryId": "BoGso1y83zrtRP9CRpdRkA",
    "http": "POST",
    "features": ""
  },
  "mutation_unsubscribe_from_drop": {
    "endpoint": "mutation_unsubscribe_from_drop",
    "operation": "MutationUnsubscribeFromDrop",
    "queryId": "PPQmv0KgHVZ0gpDOfkEb8Q",
    "http": "POST",
    "features": ""
  },
  "mutation_upload_commerce_products": {
    "endpoint": "mutation_upload_commerce_products",
    "operation": "MutationUploadCommerceProducts",
    "queryId": "txQwI4tQ8RfQxEN3SCeAkw",
    "http": "POST",
    "features": ""
  },
  "nux_user_recommendations_page_query": {
    "endpoint": "nux_user_recommendations_page_query",
    "operation": "NuxUserRecommendationsPageQuery",
    "queryId": "07zfHSr1oANh296kxa28rA",
    "http": "GET",
    "features": "A"
  },
  "parody_commentary_fan_label_settings_get": {
    "endpoint": "parody_commentary_fan_label_settings_get",
    "operation": "ParodyCommentaryFanLabelSettingsGet",
    "queryId": "6i5XbW86EwI3LNXabguB-A",
    "http": "GET",
    "features": ""
  },
  "passkey_auth_settings_get": {
    "endpoint": "passkey_auth_settings_get",
    "operation": "PasskeyAuthSettingsGet",
    "queryId": "D3o7y2ySvNMRD-oq0gDIEA",
    "http": "GET",
    "features": ""
  },
  "pinnable_timelines_query": {
    "endpoint": "pinnable_timelines_query",
    "operation": "PinnableTimelinesQuery",
    "queryId": "Sg42AEtZXoyqTMraDD1vJw",
    "http": "GET",
    "features": ""
  },
  "pinned_timelines_query": {
    "endpoint": "pinned_timelines_query",
    "operation": "PinnedTimelinesQuery",
    "queryId": "MbRPLB5QUm99vtmz5tMM8w",
    "http": "GET",
    "features": "B"
  },
  "pin_timeline": {
    "endpoint": "pin_timeline",
    "operation": "PinTimeline",
    "queryId": "lrEwaoucVKgfBcVHzEetMQ",
    "http": "POST",
    "features": "B"
  },
  "pin_tweet": {
    "endpoint": "pin_tweet",
    "operation": "PinTweet",
    "queryId": "ztf5duPxJV_QJOO6s-Pkzg",
    "http": "POST",
    "features": ""
  },
  "play_sotre_subscription_purchase_token": {
    "endpoint": "play_sotre_subscription_purchase_token",
    "operation": "PlaySotreSubscriptionPurchaseToken",
    "queryId": "kQJWXMdGvfAZ_4aFR2OEcA",
    "http": "GET",
    "features": ""
  },
  "product_catalog": {
    "endpoint": "product_catalog",
    "operation": "ProductCatalog",
    "queryId": "AwqAW3ilnprnFohpWIB84g",
    "http": "GET",
    "features": ""
  },
  "profile_viewer_explore_mixer_timeline": {
    "endpoint": "profile_viewer_explore_mixer_timeline",
    "operation": "ProfileViewerExploreMixerTimeline",
    "queryId": "dhvOtFrHu44e4d6--U9faQ",
    "http": "GET",
    "features": "A"
  },
  "query_shop_by_rest_id_v2": {
    "endpoint": "query_shop_by_rest_id_v2",
    "operation": "QueryShopByRestIdV2",
    "queryId": "Nln5InUoZ33JoGz3aV1CqA",
    "http": "GET",
    "features": ""
  },
  "query_shop_core_data_v2": {
    "endpoint": "query_shop_core_data_v2",
    "operation": "QueryShopCoreDataV2",
    "queryId": "ZLJuehSCkqOJTIffu4SIyg",
    "http": "GET",
    "features": "B"
  },
  "ranked_communities_timeline_query": {
    "endpoint": "ranked_communities_timeline_query",
    "operation": "RankedCommunitiesTimelineQuery",
    "queryId": "o-sMgpcyEj7C-h7hTmCkGg",
    "http": "GET",
    "features": "A"
  },
  "record_nudge_action": {
    "endpoint": "record_nudge_action",
    "operation": "RecordNudgeAction",
    "queryId": "qr2AAR3Lx10iac0BXsmo0Q",
    "http": "POST",
    "features": ""
  },
  "record_nudge_result": {
    "endpoint": "record_nudge_result",
    "operation": "RecordNudgeResult",
    "queryId": "OxPPZHeXYtxTVRhXomfxNA",
    "http": "POST",
    "features": ""
  },
  "remove_follower": {
    "endpoint": "remove_follower",
    "operation": "RemoveFollower",
    "queryId": "QpNfg0kpPRfjROQ_9eOLXA",
    "http": "POST",
    "features": ""
  },
  "remove_super_follow_privacy": {
    "endpoint": "remove_super_follow_privacy",
    "operation": "RemoveSuperFollowPrivacy",
    "queryId": "sV7dnzS0EjSctagwg4kcaA",
    "http": "POST",
    "features": ""
  },
  "report_detail_query": {
    "endpoint": "report_detail_query",
    "operation": "ReportDetailQuery",
    "queryId": "jvTvzl6_BeSqaKx4EPn2hw",
    "http": "GET",
    "features": ""
  },
  "retweeters_timeline": {
    "endpoint": "retweeters_timeline",
    "operation": "RetweetersTimeline",
    "queryId": "8Bev736i73fHjdOAHWchHA",
    "http": "GET",
    "features": "A"
  },
  "safety_mode_dismiss_suggested_action": {
    "endpoint": "safety_mode_dismiss_suggested_action",
    "operation": "SafetyModeDismissSuggestedAction",
    "queryId": "VCzyC1OiUFidTNokWUIDkg",
    "http": "POST",
    "features": ""
  },
  "safety_mode_face_pile": {
    "endpoint": "safety_mode_face_pile",
    "operation": "SafetyModeFacePile",
    "queryId": "L5GGgGxgm-3vJOrPu9EknA",
    "http": "GET",
    "features": ""
  },
  "safety_mode_settings": {
    "endpoint": "safety_mode_settings",
    "operation": "SafetyModeSettings",
    "queryId": "UBSi0yYDfd2SMtQrLPoD7A",
    "http": "GET",
    "features": ""
  },
  "safety_mode_settings_put": {
    "endpoint": "safety_mode_settings_put",
    "operation": "SafetyModeSettingsPut",
    "queryId": "d0lIMKMFYnyrGw39i_w5cw",
    "http": "POST",
    "features": ""
  },
  "scheduled_space_subscriber_delete": {
    "endpoint": "scheduled_space_subscriber_delete",
    "operation": "ScheduledSpaceSubscriberDelete",
    "queryId": "okZ9Xy4CQvnG4pNezfOPjg",
    "http": "POST",
    "features": ""
  },
  "search_check_subscribing": {
    "endpoint": "search_check_subscribing",
    "operation": "SearchCheckSubscribing",
    "queryId": "4SXaNZqATwxQ2a1JOfE1xA",
    "http": "GET",
    "features": ""
  },
  "search_timeline_web": {
    "endpoint": "search_timeline_web",
    "operation": "SearchTimeline",
    "queryId": "-TFXKoMnMTKdEXcCn-eahw",
    "http": "GET",
    "features": "C"
  },
  "search_unsubscribe": {
    "endpoint": "search_unsubscribe",
    "operation": "SearchUnsubscribe",
    "queryId": "z8P6pVy7VZ1HX-ohx3mX9w",
    "http": "POST",
    "features": ""
  },
  "sensitive_media_settings_put": {
    "endpoint": "sensitive_media_settings_put",
    "operation": "SensitiveMediaSettingsPut",
    "queryId": "8y2QEhYV5k3CKt08dik2xg",
    "http": "POST",
    "features": ""
  },
  "smart_tag_query": {
    "endpoint": "smart_tag_query",
    "operation": "SmartTagQuery",
    "queryId": "5Yz8cmVvNqZqff3VpB8tyw",
    "http": "GET",
    "features": ""
  },
  "start_identity_verification": {
    "endpoint": "start_identity_verification",
    "operation": "StartIdentityVerification",
    "queryId": "Th45ocZ_zx4020KUriETEg",
    "http": "GET",
    "features": ""
  },
  "subscription_product_features_fetch": {
    "endpoint": "subscription_product_features_fetch",
    "operation": "SubscriptionProductFeaturesFetch",
    "queryId": "Se5DRn5kQaZREBSyGOU7VA",
    "http": "GET",
    "features": ""
  },
  "super_follow_products": {
    "endpoint": "super_follow_products",
    "operation": "SuperFollowProducts",
    "queryId": "FEELRJqfigRmUKIHWGjUKg",
    "http": "GET",
    "features": ""
  },
  "switch_professional_account_type": {
    "endpoint": "switch_professional_account_type",
    "operation": "SwitchProfessionalAccountType",
    "queryId": "wlCsIYN0kTO35cpIRhnBVQ",
    "http": "POST",
    "features": "B"
  },
  "switch_to_non_professional": {
    "endpoint": "switch_to_non_professional",
    "operation": "SwitchToNonProfessional",
    "queryId": "zB4TO_AlZK8HFbk0VwOGAQ",
    "http": "POST",
    "features": "B"
  },
  "timeline_by_id_query": {
    "endpoint": "timeline_by_id_query",
    "operation": "TimelineByIdQuery",
    "queryId": "dmSFtR6IyzsK3F_Y77yBZQ",
    "http": "GET",
    "features": "A"
  },
  "tipjar_disable_all": {
    "endpoint": "tipjar_disable_all",
    "operation": "TipjarDisableAll",
    "queryId": "bOfyDg0mcmcKBIfAM8wAeA",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_bandcamp": {
    "endpoint": "tipjar_update_bandcamp",
    "operation": "TipjarUpdateBandcamp",
    "queryId": "c00UJFiEVx30KnYNIqLvHQ",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_bitcoin": {
    "endpoint": "tipjar_update_bitcoin",
    "operation": "TipjarUpdateBitcoin",
    "queryId": "0BEwxrrUaTXkE-0pz2jkEA",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_cashapp": {
    "endpoint": "tipjar_update_cashapp",
    "operation": "TipjarUpdateCashapp",
    "queryId": "scO5jbvhTG5vhFEtpOgKZA",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_chipper": {
    "endpoint": "tipjar_update_chipper",
    "operation": "TipjarUpdateChipper",
    "queryId": "RFsFCzgHx2qU5zjgfoze0g",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_enabled": {
    "endpoint": "tipjar_update_enabled",
    "operation": "TipjarUpdateEnabled",
    "queryId": "5zLqCpUnH7SJPBN5FhRk3A",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_ethereum": {
    "endpoint": "tipjar_update_ethereum",
    "operation": "TipjarUpdateEthereum",
    "queryId": "FKOz-6SA3f-JTSE-vYVqcA",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_gofundme": {
    "endpoint": "tipjar_update_gofundme",
    "operation": "TipjarUpdateGofundme",
    "queryId": "y8l94dOu2zAgDU0vQuX2gw",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_kakaopay": {
    "endpoint": "tipjar_update_kakaopay",
    "operation": "TipjarUpdateKakaopay",
    "queryId": "WjLRHusB0lradOUlUg6eeQ",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_paga": {
    "endpoint": "tipjar_update_paga",
    "operation": "TipjarUpdatePaga",
    "queryId": "Khq-pQ-1FBv1a7EtdmUTWA",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_patreon": {
    "endpoint": "tipjar_update_patreon",
    "operation": "TipjarUpdatePatreon",
    "queryId": "ycZIphvbJx3oVA0Uzu7o0Q",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_paypal": {
    "endpoint": "tipjar_update_paypal",
    "operation": "TipjarUpdatePaypal",
    "queryId": "aerFfP78IoulpfVLEogsPw",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_paytm": {
    "endpoint": "tipjar_update_paytm",
    "operation": "TipjarUpdatePaytm",
    "queryId": "P9V1PMwL5UrlFq6naU7Q0A",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_picpay": {
    "endpoint": "tipjar_update_picpay",
    "operation": "TipjarUpdatePicpay",
    "queryId": "GZJt2p-xXT78gPUWvt8tJw",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_razorpay": {
    "endpoint": "tipjar_update_razorpay",
    "operation": "TipjarUpdateRazorpay",
    "queryId": "jqQ1HajRO3K8KSDDggNuXg",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_strike": {
    "endpoint": "tipjar_update_strike",
    "operation": "TipjarUpdateStrike",
    "queryId": "aZis6gjbxCm6QH3TlALNPw",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_venmo": {
    "endpoint": "tipjar_update_venmo",
    "operation": "TipjarUpdateVenmo",
    "queryId": "GyB44tX86TuNkMlY8b8RZw",
    "http": "POST",
    "features": ""
  },
  "tipjar_update_wealthsimple": {
    "endpoint": "tipjar_update_wealthsimple",
    "operation": "TipjarUpdateWealthsimple",
    "queryId": "tDIm6F3XyBWEG4cZ22WD1w",
    "http": "POST",
    "features": ""
  },
  "top_articles_timeline": {
    "endpoint": "top_articles_timeline",
    "operation": "TopArticlesTimeline",
    "queryId": "ncR-SqV6cggFi7Ui1KnnMQ",
    "http": "GET",
    "features": "A"
  },
  "topic_page_by_rest_id_no_body_query": {
    "endpoint": "topic_page_by_rest_id_no_body_query",
    "operation": "TopicPageByRestIdNoBodyQuery",
    "queryId": "oxoWpwFeEGqV9mffKHxKsg",
    "http": "GET",
    "features": "B"
  },
  "topic_page_by_rest_id_query": {
    "endpoint": "topic_page_by_rest_id_query",
    "operation": "TopicPageByRestIdQuery",
    "queryId": "P14QLPx5dUEyp4jfz6I9yg",
    "http": "GET",
    "features": "A"
  },
  "translate_profile_query": {
    "endpoint": "translate_profile_query",
    "operation": "TranslateProfileQuery",
    "queryId": "3j6Kad20h4vaJeld3QI8qg",
    "http": "GET",
    "features": ""
  },
  "translate_tweet_feedback": {
    "endpoint": "translate_tweet_feedback",
    "operation": "TranslateTweetFeedback",
    "queryId": "Ieo99xS0aO4M53LWqbqKdA",
    "http": "POST",
    "features": ""
  },
  "translate_tweet_query": {
    "endpoint": "translate_tweet_query",
    "operation": "TranslateTweetQuery",
    "queryId": "WwIm9qup5zy3ttf7R4Apxw",
    "http": "GET",
    "features": ""
  },
  "trusted_friends_list_member_add": {
    "endpoint": "trusted_friends_list_member_add",
    "operation": "TrustedFriendsListMemberAdd",
    "queryId": "Tp2OYiWFbwEf1YcRbXSI7A",
    "http": "POST",
    "features": "B"
  },
  "trusted_friends_list_member_remove": {
    "endpoint": "trusted_friends_list_member_remove",
    "operation": "TrustedFriendsListMemberRemove",
    "queryId": "Ixx2P5eU4RYM7qUHGHujNw",
    "http": "POST",
    "features": "B"
  },
  "trusted_friends_list_query_by_id": {
    "endpoint": "trusted_friends_list_query_by_id",
    "operation": "TrustedFriendsListQueryById",
    "queryId": "-FGFGdlNiYhqsFQ5btxmuA",
    "http": "GET",
    "features": ""
  },
  "trusted_friends_list_query_recommended_members_by_rest_id": {
    "endpoint": "trusted_friends_list_query_recommended_members_by_rest_id",
    "operation": "TrustedFriendsListQueryRecommendedMembersByRestId",
    "queryId": "MOB-Il1nCZ3Q6RXqLJx1Kw",
    "http": "GET",
    "features": "B"
  },
  "tweet_conversation_control_delete": {
    "endpoint": "tweet_conversation_control_delete",
    "operation": "TweetConversationControlDelete",
    "queryId": "IkdET3_iUY5aPtz7Xn-8rA",
    "http": "POST",
    "features": ""
  },
  "tweet_conversation_control_put": {
    "endpoint": "tweet_conversation_control_put",
    "operation": "TweetConversationControlPut",
    "queryId": "DL0R5KGQ3SvA-ziP-MQl6A",
    "http": "POST",
    "features": ""
  },
  "tweet_detail": {
    "endpoint": "tweet_detail",
    "operation": "TweetDetail",
    "queryId": "6uCvnic3m5reVuehkvHa3w",
    "http": "GET",
    "features": "C"
  },
  "tweet_moderate_update": {
    "endpoint": "tweet_moderate_update",
    "operation": "TweetModerateUpdate",
    "queryId": "slVYoY_EHR7YDRpto6hlQg",
    "http": "POST",
    "features": ""
  },
  "tweet_result_by_id_query": {
    "endpoint": "tweet_result_by_id_query",
    "operation": "TweetResultByIdQuery",
    "queryId": "rtNVfIklvKnpQJgSCudXkQ",
    "http": "GET",
    "features": "A"
  },
  "tweet_results_by_ids_query": {
    "endpoint": "tweet_results_by_ids_query",
    "operation": "TweetResultsByIdsQuery",
    "queryId": "y2q0dRZQxID7nnIcCIE3sg",
    "http": "GET",
    "features": "A"
  },
  "tweet_unmoderate_update": {
    "endpoint": "tweet_unmoderate_update",
    "operation": "TweetUnmoderateUpdate",
    "queryId": "s_Lg336W54DW08H5GDG8cA",
    "http": "POST",
    "features": ""
  },
  "unfavorite_tweet": {
    "endpoint": "unfavorite_tweet",
    "operation": "UnfavoriteTweet",
    "queryId": "ZYKSe-w7KEslx3JhSIk5LA",
    "http": "POST",
    "features": ""
  },
  "unmention_user": {
    "endpoint": "unmention_user",
    "operation": "UnmentionUser",
    "queryId": "OliKoDxqcnL653lUPIeruw",
    "http": "POST",
    "features": ""
  },
  "unpin_timeline": {
    "endpoint": "unpin_timeline",
    "operation": "UnpinTimeline",
    "queryId": "gzhKuERhKEsooXFBcLDb8A",
    "http": "POST",
    "features": "B"
  },
  "unpin_tweet": {
    "endpoint": "unpin_tweet",
    "operation": "UnpinTweet",
    "queryId": "TtGd5umk9Cd_nMDQG7JBSw",
    "http": "POST",
    "features": ""
  },
  "update_pinned_timelines": {
    "endpoint": "update_pinned_timelines",
    "operation": "UpdatePinnedTimelines",
    "queryId": "Ia57eakdNOqtfr8Ul7-FCQ",
    "http": "POST",
    "features": "B"
  },
  "update_tweet_voice_info": {
    "endpoint": "update_tweet_voice_info",
    "operation": "UpdateTweetVoiceInfo",
    "queryId": "ypmjbNda88Co1H-2Denpyw",
    "http": "POST",
    "features": ""
  },
  "user_about_timeline_query": {
    "endpoint": "user_about_timeline_query",
    "operation": "UserAboutTimelineQuery",
    "queryId": "kbZS5ZH3Sex8Z2E35bOFrg",
    "http": "GET",
    "features": "A"
  },
  "user_affiliated_users": {
    "endpoint": "user_affiliated_users",
    "operation": "UserAffiliatedUsers",
    "queryId": "fluvXY3yJTKutMsYW_kEtQ",
    "http": "GET",
    "features": "A"
  },
  "user_av_call_settings_put": {
    "endpoint": "user_av_call_settings_put",
    "operation": "UserAvCallSettingsPut",
    "queryId": "umUeiLvtyldLVdCAzDO27g",
    "http": "POST",
    "features": ""
  },
  "user_by_rest_id": {
    "endpoint": "user_by_rest_id",
    "operation": "UserByRestId",
    "queryId": "QdS5LJDl99iL_KUzckdfNQ",
    "http": "GET",
    "features": [
      "hidden_profile_likes_enabled",
      "hidden_profile_subscriptions_enabled",
      "profile_label_improvements_pcf_label_in_post_enabled",
      "verified_phone_label_enabled",
      "highlights_tweets_tab_ui_enabled",
      "responsive_web_twitter_article_notes_tab_enabled",
      "creator_subscriptions_tweet_preview_api_enabled",
      "responsive_web_graphql_exclude_directive_enabled",
      "responsive_web_graphql_timeline_navigation_enabled",
      "responsive_web_graphql_skip_user_profile_image_extensions_enabled"
    ]
  },
  "user_by_screen_name": {
    "endpoint": "user_by_screen_name",
    "operation": "UserByScreenName",
    "queryId": "IGgvgiOx4QZndDHuD3x9TQ",
    "http": "GET",
    "features": [
      "hidden_profile_subscriptions_enabled",
      "profile_label_improvements_pcf_label_in_post_enabled",
      "responsive_web_profile_redirect_enabled",
      "rweb_tipjar_consumption_enabled",
      "verified_phone_label_enabled",
      "subscriptions_verification_info_is_identity_verified_enabled",
      "subscriptions_verification_info_verified_since_enabled",
      "highlights_tweets_tab_ui_enabled",
      "responsive_web_twitter_article_notes_tab_enabled",
      "subscriptions_feature_can_gift_premium",
      "creator_subscriptions_tweet_preview_api_enabled",
      "responsive_web_graphql_skip_user_profile_image_extensions_enabled",
      "responsive_web_graphql_timeline_navigation_enabled"
    ]
  },
  "user_community_invite_mutation": {
    "endpoint": "user_community_invite_mutation",
    "operation": "UserCommunityInviteMutation",
    "queryId": "DSbmt8ctjvcG7EqJKqQ25Q",
    "http": "POST",
    "features": "B"
  },
  "user_create_about_module_from_venue": {
    "endpoint": "user_create_about_module_from_venue",
    "operation": "UserCreateAboutModuleFromVenue",
    "queryId": "_mseS6R1pjYdYMGNmub-bw",
    "http": "POST",
    "features": "B"
  },
  "user_create_app_module": {
    "endpoint": "user_create_app_module",
    "operation": "UserCreateAppModule",
    "queryId": "Ob3WXKB4F1cjr-zHJnHW1w",
    "http": "POST",
    "features": "B"
  },
  "user_create_communities_module_mutation": {
    "endpoint": "user_create_communities_module_mutation",
    "operation": "UserCreateCommunitiesModuleMutation",
    "queryId": "fSpw5Izp8EtEhIbrrEel1w",
    "http": "POST",
    "features": "B"
  },
  "user_create_link_module": {
    "endpoint": "user_create_link_module",
    "operation": "UserCreateLinkModule",
    "queryId": "W3KSmCM22RPst81ZBRKYjA",
    "http": "POST",
    "features": "B"
  },
  "user_delete_about_module_and_venue": {
    "endpoint": "user_delete_about_module_and_venue",
    "operation": "UserDeleteAboutModuleAndVenue",
    "queryId": "75bdkdTykLMX9nXD52uoHw",
    "http": "POST",
    "features": "B"
  },
  "user_delete_app_module": {
    "endpoint": "user_delete_app_module",
    "operation": "UserDeleteAppModule",
    "queryId": "E7LrRvILgHl_z9-xGY9kJw",
    "http": "POST",
    "features": "B"
  },
  "user_delete_communities_module_mutation": {
    "endpoint": "user_delete_communities_module_mutation",
    "operation": "UserDeleteCommunitiesModuleMutation",
    "queryId": "oidlSSrrOQf2yVA8KAR2bw",
    "http": "POST",
    "features": "B"
  },
  "user_delete_link_module": {
    "endpoint": "user_delete_link_module",
    "operation": "UserDeleteLinkModule",
    "queryId": "LzcStkGMhPS2vHf6sO532Q",
    "http": "POST",
    "features": "B"
  },
  "user_dm_nsfw_filter_settings_update": {
    "endpoint": "user_dm_nsfw_filter_settings_update",
    "operation": "UserDmNsfwFilterSettingsUpdate",
    "queryId": "Zx2AzSs6KfU15AkXxpa0YQ",
    "http": "POST",
    "features": ""
  },
  "user_editable_profile_modules_query": {
    "endpoint": "user_editable_profile_modules_query",
    "operation": "UserEditableProfileModulesQuery",
    "queryId": "VEob2BUpEy0R7YCS0EftSA",
    "http": "GET",
    "features": "B"
  },
  "user_email_notifications_settings_update": {
    "endpoint": "user_email_notifications_settings_update",
    "operation": "UserEmailNotificationsSettingsUpdate",
    "queryId": "G_1gf5jOsfFLCIYu0bPiig",
    "http": "POST",
    "features": ""
  },
  "user_followers_timeline_query": {
    "endpoint": "user_followers_timeline_query",
    "operation": "UserFollowersTimelineQuery",
    "queryId": "XMLXqm9EMMVO1w71XJWeCQ",
    "http": "GET",
    "features": "A"
  },
  "user_following_timeline_query": {
    "endpoint": "user_following_timeline_query",
    "operation": "UserFollowingTimelineQuery",
    "queryId": "bNPayvtkxorTHM4JGod1lw",
    "http": "GET",
    "features": "A"
  },
  "user_friends_following_timeline_query": {
    "endpoint": "user_friends_following_timeline_query",
    "operation": "UserFriendsFollowingTimelineQuery",
    "queryId": "I4VgTq0DHf01VqcR4D8-Bg",
    "http": "GET",
    "features": "A"
  },
  "user_incoming_friendships_timeline_query": {
    "endpoint": "user_incoming_friendships_timeline_query",
    "operation": "UserIncomingFriendshipsTimelineQuery",
    "queryId": "bGaAXthJZhzdN2NnfYIvUw",
    "http": "GET",
    "features": "A"
  },
  "user_list_mute": {
    "endpoint": "user_list_mute",
    "operation": "UserListMute",
    "queryId": "706Hnj2UKNqAJOZJXT0ZqQ",
    "http": "POST",
    "features": ""
  },
  "user_list_subscribe": {
    "endpoint": "user_list_subscribe",
    "operation": "UserListSubscribe",
    "queryId": "uKER2Ur0iQTVXkqUEUg-Kg",
    "http": "POST",
    "features": "B"
  },
  "user_list_unmute": {
    "endpoint": "user_list_unmute",
    "operation": "UserListUnmute",
    "queryId": "bS5Ku2wVQGyKU2rhr_B8fg",
    "http": "POST",
    "features": ""
  },
  "user_list_unsubscribe": {
    "endpoint": "user_list_unsubscribe",
    "operation": "UserListUnsubscribe",
    "queryId": "MFR5-RSk4A5F6zDoJ-FDEw",
    "http": "POST",
    "features": "B"
  },
  "user_preferences_get": {
    "endpoint": "user_preferences_get",
    "operation": "UserPreferencesGet",
    "queryId": "UIjeD7AZKF-P4hfT2EONQg",
    "http": "GET",
    "features": ""
  },
  "user_preferences_grok_delete_data": {
    "endpoint": "user_preferences_grok_delete_data",
    "operation": "UserPreferencesGrokDeleteData",
    "queryId": "28CM05OHbQfDWO4b1n90sg",
    "http": "POST",
    "features": ""
  },
  "user_preferences_update_allow_for_you_recommendations": {
    "endpoint": "user_preferences_update_allow_for_you_recommendations",
    "operation": "UserPreferencesUpdateAllowForYouRecommendations",
    "queryId": "uJ0iXR1R-jxu9CzKXXQjEQ",
    "http": "POST",
    "features": ""
  },
  "user_preferences_update_allow_gambling_ads": {
    "endpoint": "user_preferences_update_allow_gambling_ads",
    "operation": "UserPreferencesUpdateAllowGamblingAds",
    "queryId": "yx6aK4P8kSffBXm-dbq70A",
    "http": "POST",
    "features": ""
  },
  "user_preferences_update_allow_video_downloads": {
    "endpoint": "user_preferences_update_allow_video_downloads",
    "operation": "UserPreferencesUpdateAllowVideoDownloads",
    "queryId": "srtPWSpugzh1H1YdXtuofg",
    "http": "POST",
    "features": ""
  },
  "user_preferences_update_grok_data_sharing": {
    "endpoint": "user_preferences_update_grok_data_sharing",
    "operation": "UserPreferencesUpdateGrokDataSharing",
    "queryId": "NMSYSeV5KQobnorDwPFvtQ",
    "http": "POST",
    "features": ""
  },
  "user_preferences_update_grok_memory": {
    "endpoint": "user_preferences_update_grok_memory",
    "operation": "UserPreferencesUpdateGrokMemory",
    "queryId": "9D0ZHGY-DNs7-SBWCiWJNQ",
    "http": "POST",
    "features": ""
  },
  "user_preferences_update_grok_personalization": {
    "endpoint": "user_preferences_update_grok_personalization",
    "operation": "UserPreferencesUpdateGrokPersonalization",
    "queryId": "d8Dsepig7V9mmKuIY2g21Q",
    "http": "POST",
    "features": ""
  },
  "user_preferences_update_hide_subscriptions": {
    "endpoint": "user_preferences_update_hide_subscriptions",
    "operation": "UserPreferencesUpdateHideSubscriptions",
    "queryId": "ltjtmRyBlAwQosK-3NdjBQ",
    "http": "POST",
    "features": ""
  },
  "user_preferences_update_inferred_location_resolution_preference": {
    "endpoint": "user_preferences_update_inferred_location_resolution_preference",
    "operation": "UserPreferencesUpdateInferredLocationResolutionPreference",
    "queryId": "ZIiHWIz5tOMpZe-M958Muw",
    "http": "POST",
    "features": ""
  },
  "user_profile_articles_timeline_query": {
    "endpoint": "user_profile_articles_timeline_query",
    "operation": "UserProfileArticlesTimelineQuery",
    "queryId": "VUJhHsUKgD7kxd0pTb571w",
    "http": "GET",
    "features": "A"
  },
  "user_profile_modules_query": {
    "endpoint": "user_profile_modules_query",
    "operation": "UserProfileModulesQuery",
    "queryId": "Pj60UkDRUFuQINySSdD-LQ",
    "http": "GET",
    "features": "B"
  },
  "user_profile_reposts_timeline_query": {
    "endpoint": "user_profile_reposts_timeline_query",
    "operation": "UserProfileRepostsTimelineQuery",
    "queryId": "5Gp4Cy4U13LBpmTBYnwCig",
    "http": "GET",
    "features": [
      "android_home_timeline_status_injections_facepile_enabled",
      "grok_translations_post_auto_translation_is_enabled",
      "reply_dislike_android_enabled",
      "x_lite_quick_promote_analytics_banner_enabled"
    ]
  },
  "user_result_by_id_query": {
    "endpoint": "user_result_by_id_query",
    "operation": "UserResultByIdQuery",
    "queryId": "-DAaa9jPxPswYeI2fZ9rug",
    "http": "GET",
    "features": "B"
  },
  "user_result_by_screen_name_query": {
    "endpoint": "user_result_by_screen_name_query",
    "operation": "UserResultByScreenNameQuery",
    "queryId": "-ZzAG_Bckx16LMbEvHC3lg",
    "http": "GET",
    "features": "B"
  },
  "user_sharing_listening_data_with_followers_settings_update": {
    "endpoint": "user_sharing_listening_data_with_followers_settings_update",
    "operation": "UserSharingListeningDataWithFollowersSettingsUpdate",
    "queryId": "znFz69bnfZ3GA86FMkAM8w",
    "http": "POST",
    "features": ""
  },
  "user_super_followers_timeline_query": {
    "endpoint": "user_super_followers_timeline_query",
    "operation": "UserSuperFollowersTimelineQuery",
    "queryId": "DX9jUPO9exxy0aqBIHVvug",
    "http": "GET",
    "features": "A"
  },
  "profile_tweets_and_replies_query": {
    "endpoint": "profile_tweets_and_replies_query",
    "operation": "UserTweetsAndReplies",
    "queryId": "EqtpEwt0CoQXmDfq5DKH0A",
    "http": "GET",
    "features": "C"
  },
  "user_update_about_module_from_venue": {
    "endpoint": "user_update_about_module_from_venue",
    "operation": "UserUpdateAboutModuleFromVenue",
    "queryId": "hhb6N8z6qwrqxrRCzN3yyA",
    "http": "POST",
    "features": "B"
  },
  "user_update_app_module": {
    "endpoint": "user_update_app_module",
    "operation": "UserUpdateAppModule",
    "queryId": "WnB2cARj2tJGXl9D5ZVnPg",
    "http": "POST",
    "features": "B"
  },
  "user_update_communities_module_mutation": {
    "endpoint": "user_update_communities_module_mutation",
    "operation": "UserUpdateCommunitiesModuleMutation",
    "queryId": "3jh0bCSsMLKkAP3Xi5Uerg",
    "http": "POST",
    "features": "B"
  },
  "user_update_link_module": {
    "endpoint": "user_update_link_module",
    "operation": "UserUpdateLinkModule",
    "queryId": "RQUkzX3oNZA6YuW8tKYr6g",
    "http": "POST",
    "features": "B"
  },
  "user_update_module_visibility": {
    "endpoint": "user_update_module_visibility",
    "operation": "UserUpdateModuleVisibility",
    "queryId": "7ZTYrhErufhdk2-it4APUg",
    "http": "POST",
    "features": "B"
  },
  "user_update_professional_category_display": {
    "endpoint": "user_update_professional_category_display",
    "operation": "UserUpdateProfessionalCategoryDisplay",
    "queryId": "Wxve9Btx3tHIwkAdF1vZ0A",
    "http": "POST",
    "features": "B"
  },
  "user_verified_reason_query": {
    "endpoint": "user_verified_reason_query",
    "operation": "UserVerifiedReasonQuery",
    "queryId": "zRXYMcGAF6LiKr7dow6CVQ",
    "http": "GET",
    "features": ""
  },
  "user_vit_followers_timeline_query": {
    "endpoint": "user_vit_followers_timeline_query",
    "operation": "UserVitFollowersTimelineQuery",
    "queryId": "D6gamO3p6hNhYPacLmHKWA",
    "http": "GET",
    "features": "A"
  },
  "user_with_profile_highlights_timeline_query": {
    "endpoint": "user_with_profile_highlights_timeline_query",
    "operation": "UserWithProfileHighlightsTimelineQuery",
    "queryId": "O4NgjliT3TF-GTEra4Nr3g",
    "http": "GET",
    "features": "A"
  },
  "user_with_profile_reply_device_follow": {
    "endpoint": "user_with_profile_reply_device_follow",
    "operation": "UserWithProfileReplyDeviceFollow",
    "queryId": "0iCEMO6QzSVi3CUZjvuiBA",
    "http": "POST",
    "features": ""
  },
  "user_with_profile_reply_device_unfollow": {
    "endpoint": "user_with_profile_reply_device_unfollow",
    "operation": "UserWithProfileReplyDeviceUnfollow",
    "queryId": "qQrGirsSX8f-CVBT8-Ue3Q",
    "http": "POST",
    "features": ""
  },
  "user_with_profile_super_follow_tweets_query": {
    "endpoint": "user_with_profile_super_follow_tweets_query",
    "operation": "UserWithProfileSuperFollowTweetsQuery",
    "queryId": "1viCRDLHXmw-rPwwZeS3eg",
    "http": "GET",
    "features": "A"
  },
  "user_with_profile_tweets_and_replies_query_v2": {
    "endpoint": "user_with_profile_tweets_and_replies_query_v2",
    "operation": "UserWithProfileTweetsAndRepliesQueryV2",
    "queryId": "AcYHjc_YAx-9_rKWdMsKvA",
    "http": "GET",
    "features": "A"
  },
  "user_with_profile_tweets_query_v2": {
    "endpoint": "user_with_profile_tweets_query_v2",
    "operation": "UserWithProfileTweetsQueryV2",
    "queryId": "B2UkbYOGwyE4DX_2WNIySw",
    "http": "GET",
    "features": "A"
  },
  "user_with_rito_actioned_tweets_timeline_query": {
    "endpoint": "user_with_rito_actioned_tweets_timeline_query",
    "operation": "UserWithRitoActionedTweetsTimelineQuery",
    "queryId": "WG9NCVqjVUQkLabIgEWzMQ",
    "http": "GET",
    "features": "A"
  },
  "user_with_rito_flagged_tweets_timeline_query": {
    "endpoint": "user_with_rito_flagged_tweets_timeline_query",
    "operation": "UserWithRitoFlaggedTweetsTimelineQuery",
    "queryId": "B7HIMpjzPGE4dsqDy5N5LQ",
    "http": "GET",
    "features": "A"
  },
  "viewer_blocking_timeline_query": {
    "endpoint": "viewer_blocking_timeline_query",
    "operation": "ViewerBlockingTimelineQuery",
    "queryId": "MQhlNOS3gxEAUAtzgAWz7w",
    "http": "GET",
    "features": "A"
  },
  "viewer_channels_discovery_timeline_query": {
    "endpoint": "viewer_channels_discovery_timeline_query",
    "operation": "ViewerChannelsDiscoveryTimelineQuery",
    "queryId": "PG9fEJDJg1_dy7W3F5yk3A",
    "http": "GET",
    "features": "A"
  },
  "viewer_flagged_accounts_timeline_query": {
    "endpoint": "viewer_flagged_accounts_timeline_query",
    "operation": "ViewerFlaggedAccountsTimelineQuery",
    "queryId": "4PCekDmhLepadVT9-HdELQ",
    "http": "GET",
    "features": "A"
  },
  "viewer_imported_blocking_timeline_query": {
    "endpoint": "viewer_imported_blocking_timeline_query",
    "operation": "ViewerImportedBlockingTimelineQuery",
    "queryId": "myQFy3Y8lbe9hlPUQHta1w",
    "http": "GET",
    "features": "A"
  },
  "viewer_list_management_timeline": {
    "endpoint": "viewer_list_management_timeline",
    "operation": "ViewerListManagementTimeline",
    "queryId": "xJ_-IOX85VVK5-DwsfoZ4A",
    "http": "GET",
    "features": "A"
  },
  "viewer_muting_timeline_query": {
    "endpoint": "viewer_muting_timeline_query",
    "operation": "ViewerMutingTimelineQuery",
    "queryId": "_zWu96VQwhY6TgNEepteRQ",
    "http": "GET",
    "features": "A"
  },
  "viewer_smart_blocking_timeline_query": {
    "endpoint": "viewer_smart_blocking_timeline_query",
    "operation": "ViewerSmartBlockingTimelineQuery",
    "queryId": "Ui6pSpwJEqjT82QjYZ7yuQ",
    "http": "GET",
    "features": "A"
  },
  "viewer_urt_fixture_query": {
    "endpoint": "viewer_urt_fixture_query",
    "operation": "ViewerUrtFixtureQuery",
    "queryId": "ss7aBtvi95rgEpV8Jn_aPA",
    "http": "GET",
    "features": "A"
  },
  "viewer_user_query": {
    "endpoint": "viewer_user_query",
    "operation": "ViewerUserQuery",
    "queryId": "_ccRJ_8nuJ1-RzBDtk-9Xg",
    "http": "GET",
    "features": "B"
  }
});

export const OPERATIONS_BY_NAME = Object.freeze({
  "AboutAccountQuery": {
    "endpoint": "about_account_query",
    "operation": "AboutAccountQuery",
    "queryId": "zUnx-DLN9dkwOkNhTLySjg",
    "http": "GET",
    "features": ""
  },
  "AboutProfileByScreenNameQuery": {
    "endpoint": "about_profile_by_screen_name_query",
    "operation": "AboutProfileByScreenNameQuery",
    "queryId": "62UN8S7bK4WOniJg24qAGQ",
    "http": "GET",
    "features": [
      "subscriptions_verification_info_enabled"
    ]
  },
  "AboutProfileQuery": {
    "endpoint": "about_profile_query",
    "operation": "AboutProfileQuery",
    "queryId": "u0L8vZ3R4Qa9TK6i9AlD8Q",
    "http": "GET",
    "features": [
      "subscriptions_verification_info_enabled"
    ]
  },
  "AcceptMessageRequestMutation": {
    "endpoint": "",
    "operation": "AcceptMessageRequestMutation",
    "queryId": "4YtAUhUwROL6ejia63Lj6Q",
    "http": "POST",
    "features": ""
  },
  "AddAsAdminMutation": {
    "endpoint": "",
    "operation": "AddAsAdminMutation",
    "queryId": "1RrduaHSFpenZuOQzgSZqA",
    "http": "POST",
    "features": ""
  },
  "AddContentDisclosure": {
    "endpoint": "add_content_disclosure",
    "operation": "AddContentDisclosure",
    "queryId": "3Ek07V45SX5LHFwA66gMRA",
    "http": "POST",
    "features": ""
  },
  "AddEncryptedConversationKeysMutation": {
    "endpoint": "",
    "operation": "AddEncryptedConversationKeysMutation",
    "queryId": "4V1KC8ue2tHHvRuIzeczdg",
    "http": "POST",
    "features": ""
  },
  "AddGroupMembersMutation": {
    "endpoint": "",
    "operation": "AddGroupMembersMutation",
    "queryId": "h_jTCUo4lmIM7UJvzZXZ4w",
    "http": "POST",
    "features": ""
  },
  "AddRemoveUserFromList": {
    "endpoint": "add_remove_user_from_list",
    "operation": "AddRemoveUserFromList",
    "queryId": "uEKWWNM47dPfVj-G6Jm1iw",
    "http": "GET",
    "features": "A"
  },
  "AddSuperFollowPrivacy": {
    "endpoint": "add_super_follow_privacy",
    "operation": "AddSuperFollowPrivacy",
    "queryId": "xIZJPQBK0Zz62_BDLNLHKw",
    "http": "POST",
    "features": ""
  },
  "AddWelcomeMessageToConversationMutation": {
    "endpoint": "",
    "operation": "AddWelcomeMessageToConversationMutation",
    "queryId": "n00JbEbhywS5lGvKrvFmJg",
    "http": "POST",
    "features": ""
  },
  "AddXChatPublicKeyMutation": {
    "endpoint": "",
    "operation": "AddXChatPublicKeyMutation",
    "queryId": "CQsk6GRuWAVabyXqqEG1sA",
    "http": "POST",
    "features": ""
  },
  "AllSubscribedListsTimeline": {
    "endpoint": "all_subscribed_lists_timeline",
    "operation": "AllSubscribedListsTimeline",
    "queryId": "tbyr4x_yStp9gs5-r2Bmng",
    "http": "GET",
    "features": "A"
  },
  "AllSubscribedListsTimelineQuery": {
    "endpoint": "",
    "operation": "AllSubscribedListsTimelineQuery",
    "queryId": "G4UfQ6NnEcwgT0U3grcy8A",
    "http": "POST",
    "features": ""
  },
  "ArticleTweetsTimeline": {
    "endpoint": "article_tweets_timeline",
    "operation": "ArticleTweetsTimeline",
    "queryId": "9i4cwvYa25tJ1fLn0YmSxQ",
    "http": "GET",
    "features": "A"
  },
  "AudiospaceAddSharing": {
    "endpoint": "audiospace_add_sharing",
    "operation": "AudiospaceAddSharing",
    "queryId": "kC8rCTUS8KQsEWu8rNgb2Q",
    "http": "POST",
    "features": "A"
  },
  "AudiospaceBrowseSpaceTopicsQuery": {
    "endpoint": "audiospace_browse_space_topics_query",
    "operation": "AudiospaceBrowseSpaceTopicsQuery",
    "queryId": "IZ1drq74xph2Gym7gGgtRw",
    "http": "GET",
    "features": ""
  },
  "AudiospaceByRestId": {
    "endpoint": "audiospace_by_rest_id",
    "operation": "AudiospaceByRestId",
    "queryId": "yBMgJyfQwePA6c1Eml6Ccg",
    "http": "GET",
    "features": "A"
  },
  "AudiospaceDeleteSharing": {
    "endpoint": "audiospace_delete_sharing",
    "operation": "AudiospaceDeleteSharing",
    "queryId": "PTAe3LYPhlCcPJtwpyyx-w",
    "http": "POST",
    "features": ""
  },
  "AudiospaceIsSubscribedQuery": {
    "endpoint": "audiospace_is_subscribed_query",
    "operation": "AudiospaceIsSubscribedQuery",
    "queryId": "g1mB1D5y3z_NkFsN-FwZdA",
    "http": "GET",
    "features": ""
  },
  "AudiospaceRecommendedTopicsQuery": {
    "endpoint": "audiospace_recommended_topics_query",
    "operation": "AudiospaceRecommendedTopicsQuery",
    "queryId": "olBPzZqwVkD-JeWridv1Ag",
    "http": "GET",
    "features": ""
  },
  "AudiospaceSharingsQuery": {
    "endpoint": "audiospace_sharings_query",
    "operation": "AudiospaceSharingsQuery",
    "queryId": "IDafP-_BzEV626DsBCuO3A",
    "http": "GET",
    "features": "A"
  },
  "BirdwatchHomePageQuery": {
    "endpoint": "birdwatch_home_page_query",
    "operation": "BirdwatchHomePageQuery",
    "queryId": "EaseXgo3PuOAtCCcPXuukg",
    "http": "GET",
    "features": "A"
  },
  "BonusFollowTimeline": {
    "endpoint": "bonus_follow_timeline",
    "operation": "BonusFollowTimeline",
    "queryId": "Mm6llrZ8l92Zc4UlWqczag",
    "http": "GET",
    "features": "A"
  },
  "BookmarkAdd": {
    "endpoint": "bookmark_add",
    "operation": "BookmarkAdd",
    "queryId": "-V21wukAaCGXHbUZPZ2wGw",
    "http": "POST",
    "features": ""
  },
  "BookmarkCollectionDelete": {
    "endpoint": "bookmark_collection_delete",
    "operation": "BookmarkCollectionDelete",
    "queryId": "kPKvx90Yw0QiE57ZDTaSXg",
    "http": "POST",
    "features": ""
  },
  "BookmarkCollectionsSlices": {
    "endpoint": "bookmark_collections_slices",
    "operation": "BookmarkCollectionsSlices",
    "queryId": "2t0nIPPGZMrejvawhKKKoA",
    "http": "GET",
    "features": ""
  },
  "BookmarkCollectionTimeline": {
    "endpoint": "bookmark_collection_timeline",
    "operation": "BookmarkCollectionTimeline",
    "queryId": "BchEEvsgjQwHR3ykTXTu5A",
    "http": "GET",
    "features": "A"
  },
  "BookmarkCollectionTweetDelete": {
    "endpoint": "bookmark_collection_tweet_delete",
    "operation": "BookmarkCollectionTweetDelete",
    "queryId": "8lNl-w60Xiy3Vr_M93MwCw",
    "http": "POST",
    "features": ""
  },
  "BookmarkCollectionTweetPut": {
    "endpoint": "bookmark_collection_tweet_put",
    "operation": "BookmarkCollectionTweetPut",
    "queryId": "DVFlV1M7raa019Sazd9gfw",
    "http": "POST",
    "features": ""
  },
  "BookmarkCollectionUpdate": {
    "endpoint": "bookmark_collection_update",
    "operation": "BookmarkCollectionUpdate",
    "queryId": "O1cGsRi3D4ULp2AcBRGvEQ",
    "http": "POST",
    "features": ""
  },
  "BookmarkDelete": {
    "endpoint": "bookmark_delete",
    "operation": "BookmarkDelete",
    "queryId": "G-V_AGDp-QKivnyTUCtTjA",
    "http": "POST",
    "features": ""
  },
  "BookmarkSearchTimeline": {
    "endpoint": "bookmark_search_timeline",
    "operation": "BookmarkSearchTimeline",
    "queryId": "NzAqD7b7RxntmSe6r-IF_g",
    "http": "GET",
    "features": "A"
  },
  "BookmarksSearchTimelineQuery": {
    "endpoint": "",
    "operation": "BookmarksSearchTimelineQuery",
    "queryId": "TP2IwOXOfBnbq0dI5AOioQ",
    "http": "POST",
    "features": ""
  },
  "BookmarksTimelineQuery": {
    "endpoint": "",
    "operation": "BookmarksTimelineQuery",
    "queryId": "G71T0f4Uf6ZsZB2k7gEiNA",
    "http": "POST",
    "features": ""
  },
  "BookmarkTimelineV2": {
    "endpoint": "bookmark_timeline_v2",
    "operation": "BookmarkTimelineV2",
    "queryId": "rJ9ld5zrgDFL0HkGKuqbOA",
    "http": "GET",
    "features": "A"
  },
  "BroadcastShow": {
    "endpoint": "broadcast_show",
    "operation": "BroadcastShow",
    "queryId": "1q22bHXXPwQ6WhQ0yJFTgg",
    "http": "GET",
    "features": ""
  },
  "CarouselImmersiveVideoExploreMixerTimeline": {
    "endpoint": "carousel_immersive_video_explore_mixer_timeline",
    "operation": "CarouselImmersiveVideoExploreMixerTimeline",
    "queryId": "WAjmL_GQ-ahMT7mGNbhCkw",
    "http": "GET",
    "features": "A"
  },
  "CommerceCatalogByRestId": {
    "endpoint": "commerce_catalog_by_rest_id",
    "operation": "CommerceCatalogByRestId",
    "queryId": "op45JI_mrPT8KZnhvt5Q9w",
    "http": "GET",
    "features": ""
  },
  "CommerceProductResultByKeyAndMerchant": {
    "endpoint": "commerce_product_result_by_key_and_merchant",
    "operation": "CommerceProductResultByKeyAndMerchant",
    "queryId": "MsYsJKz9_k2dmWpyyU-Xww",
    "http": "GET",
    "features": ""
  },
  "CommerceProductSetDropByRestId": {
    "endpoint": "commerce_product_set_drop_by_rest_id",
    "operation": "CommerceProductSetDropByRestId",
    "queryId": "S1AswHQxrGM8nC4sQZDUDA",
    "http": "GET",
    "features": ""
  },
  "CommerceUserResultByIdQuery": {
    "endpoint": "commerce_user_result_by_id_query",
    "operation": "CommerceUserResultByIdQuery",
    "queryId": "nEId-a30usjl43GF9QGRiA",
    "http": "GET",
    "features": "B"
  },
  "CommunitiesEligibleForProfileSpotlightSlice": {
    "endpoint": "communities_eligible_for_profile_spotlight_slice",
    "operation": "CommunitiesEligibleForProfileSpotlightSlice",
    "queryId": "9iNfj_Itz-Sh-4wqKvwPkw",
    "http": "GET",
    "features": "B"
  },
  "CommunitiesExploreTimelineQuery": {
    "endpoint": "communities_explore_timeline_query",
    "operation": "CommunitiesExploreTimelineQuery",
    "queryId": "Kzmtz-qrV-gWn1OowsTrkg",
    "http": "GET",
    "features": "A"
  },
  "CommunitiesInviteTypeaheadQuery": {
    "endpoint": "communities_invite_typeahead_query",
    "operation": "CommunitiesInviteTypeaheadQuery",
    "queryId": "cGaVxuY9j1EkBnLbFHFkIQ",
    "http": "GET",
    "features": "B"
  },
  "CommunitiesMembersAllQuery": {
    "endpoint": "communities_members_all_query",
    "operation": "CommunitiesMembersAllQuery",
    "queryId": "I6yQVpfpvXNmc7JCcsAkFQ",
    "http": "GET",
    "features": "A"
  },
  "CommunitiesMembersModeratorsQuery": {
    "endpoint": "communities_members_moderators_query",
    "operation": "CommunitiesMembersModeratorsQuery",
    "queryId": "UjnoK9Cn2ijSxXFN53EAew",
    "http": "GET",
    "features": "A"
  },
  "CommunitiesMyQuery": {
    "endpoint": "communities_my_query",
    "operation": "CommunitiesMyQuery",
    "queryId": "9vLFRLBZf1gAXPWNNXK0bA",
    "http": "GET",
    "features": "A"
  },
  "CommunitiesSearchSlice": {
    "endpoint": "communities_search_slice",
    "operation": "CommunitiesSearchSlice",
    "queryId": "Irxn8IdeoUqcgaR7cH-vQw",
    "http": "GET",
    "features": "B"
  },
  "CommunitiesTimelineQuery": {
    "endpoint": "communities_timeline_query",
    "operation": "CommunitiesTimelineQuery",
    "queryId": "ArVwiwYbRMahViraOZ7L1Q",
    "http": "GET",
    "features": "A"
  },
  "CommunityCreateMutation": {
    "endpoint": "community_create_mutation",
    "operation": "CommunityCreateMutation",
    "queryId": "oHcA4UQluHCZgtq3qrxdYQ",
    "http": "POST",
    "features": "B"
  },
  "CommunityCreateRuleMutation": {
    "endpoint": "community_create_rule_mutation",
    "operation": "CommunityCreateRuleMutation",
    "queryId": "xOCFa41vTCDsYqqd__NxOg",
    "http": "POST",
    "features": "B"
  },
  "CommunityDeleteCustomBannerMediaMutation": {
    "endpoint": "community_delete_custom_banner_media_mutation",
    "operation": "CommunityDeleteCustomBannerMediaMutation",
    "queryId": "VWY_ZzVIHSHR9uH_z57TpA",
    "http": "POST",
    "features": "B"
  },
  "CommunityDeleteMutation": {
    "endpoint": "community_delete_mutation",
    "operation": "CommunityDeleteMutation",
    "queryId": "JlDBft63PFjLWoTxIlZdqw",
    "http": "POST",
    "features": ""
  },
  "CommunityDescriptionPutMutation": {
    "endpoint": "community_description_put_mutation",
    "operation": "CommunityDescriptionPutMutation",
    "queryId": "QXzsLtkfLJGlhQfNoXDhyw",
    "http": "POST",
    "features": "B"
  },
  "CommunityDetailTimelineQuery": {
    "endpoint": "",
    "operation": "CommunityDetailTimelineQuery",
    "queryId": "FjWCoSvqrNHs-XNLx55WQQ",
    "http": "POST",
    "features": ""
  },
  "CommunityDiscoveryTimelineQuery": {
    "endpoint": "community_discovery_timeline_query",
    "operation": "CommunityDiscoveryTimelineQuery",
    "queryId": "VVZDlhiD2HW2rG5gQMHEyA",
    "http": "GET",
    "features": "A"
  },
  "CommunityHashtagSearchQuery": {
    "endpoint": "community_hashtag_search_query",
    "operation": "CommunityHashtagSearchQuery",
    "queryId": "zdU7yQ5zkqd4nx4pg2dwbg",
    "http": "GET",
    "features": "A"
  },
  "CommunityInfoQuery": {
    "endpoint": "community_info_query",
    "operation": "CommunityInfoQuery",
    "queryId": "bEHr0jP--kVelB1LdmsLvA",
    "http": "GET",
    "features": "B"
  },
  "CommunityIsNsfwPutMutation": {
    "endpoint": "community_is_nsfw_put_mutation",
    "operation": "CommunityIsNsfwPutMutation",
    "queryId": "Ol9sO7-KpKQBNAHj8IVTpA",
    "http": "POST",
    "features": "B"
  },
  "CommunityJoinQuery": {
    "endpoint": "community_join_query",
    "operation": "CommunityJoinQuery",
    "queryId": "rSwKIJyfLBlfpIfToNEOuA",
    "http": "POST",
    "features": "B"
  },
  "CommunityJoinRequestCreate": {
    "endpoint": "community_join_request_create",
    "operation": "CommunityJoinRequestCreate",
    "queryId": "NqQpLMROrEo2i_4UVZh_iQ",
    "http": "POST",
    "features": "B"
  },
  "CommunityLeaveQuery": {
    "endpoint": "community_leave_query",
    "operation": "CommunityLeaveQuery",
    "queryId": "FiTgUFDLVIRbuAzOJx1KdQ",
    "http": "POST",
    "features": "B"
  },
  "CommunityMediaTimelineQuery": {
    "endpoint": "community_media_timeline_query",
    "operation": "CommunityMediaTimelineQuery",
    "queryId": "rROnU2LtaF__xVSssdA68A",
    "http": "GET",
    "features": "A"
  },
  "CommunityMemberRequests": {
    "endpoint": "community_member_requests",
    "operation": "CommunityMemberRequests",
    "queryId": "TBrVaJlYqHqw5DkamL4Wog",
    "http": "GET",
    "features": "B"
  },
  "CommunityMembershipSettingsPut": {
    "endpoint": "community_membership_settings_put",
    "operation": "CommunityMembershipSettingsPut",
    "queryId": "xfHYqyoN3RJNujUUi1dq1Q",
    "http": "POST",
    "features": ""
  },
  "CommunityMembershipsSlice": {
    "endpoint": "community_memberships_slice",
    "operation": "CommunityMembershipsSlice",
    "queryId": "RABbw6Lt2zgSplZAyZc9yQ",
    "http": "GET",
    "features": "B"
  },
  "CommunityMembersSearch": {
    "endpoint": "community_members_search",
    "operation": "CommunityMembersSearch",
    "queryId": "Sy_t002IJ_VE3dAG_V3DlA",
    "http": "GET",
    "features": "B"
  },
  "CommunityMembersSlice": {
    "endpoint": "community_members_slice",
    "operation": "CommunityMembersSlice",
    "queryId": "R16X9FjpZaWAj1SWtcviPA",
    "http": "GET",
    "features": "B"
  },
  "CommunityModerationKeepTweetMutation": {
    "endpoint": "community_moderation_keep_tweet_mutation",
    "operation": "CommunityModerationKeepTweetMutation",
    "queryId": "k7C4ATBAOav_BMHaARnifw",
    "http": "POST",
    "features": "B"
  },
  "CommunityModerationTweetCaseReportsSlice": {
    "endpoint": "community_moderation_tweet_case_reports_slice",
    "operation": "CommunityModerationTweetCaseReportsSlice",
    "queryId": "BsmV5mNM90xhHEur02gcdQ",
    "http": "GET",
    "features": "B"
  },
  "CommunityModerationTweetCasesSlice": {
    "endpoint": "community_moderation_tweet_cases_slice",
    "operation": "CommunityModerationTweetCasesSlice",
    "queryId": "gCE2Tbb9jVaeVlUAiyzvfQ",
    "http": "GET",
    "features": "A"
  },
  "CommunityModeratorApproveRequestRtj": {
    "endpoint": "community_moderator_approve_request_rtj",
    "operation": "CommunityModeratorApproveRequestRtj",
    "queryId": "kx20yeony6OEU-3Ywu2kJQ",
    "http": "POST",
    "features": "B"
  },
  "CommunityModeratorDenyRequestRtj": {
    "endpoint": "community_moderator_deny_request_rtj",
    "operation": "CommunityModeratorDenyRequestRtj",
    "queryId": "EppyHLVkgrv7otVwQ1PllA",
    "http": "POST",
    "features": "B"
  },
  "CommunityModeratorsSlice": {
    "endpoint": "community_moderators_slice",
    "operation": "CommunityModeratorsSlice",
    "queryId": "WMO95InkVJUuUxHInFfyrA",
    "http": "GET",
    "features": "B"
  },
  "CommunityNamePutMutation": {
    "endpoint": "community_name_put_mutation",
    "operation": "CommunityNamePutMutation",
    "queryId": "uN4YI5IzzNu7GCmChaP9dg",
    "http": "POST",
    "features": "B"
  },
  "CommunityNotificationSettingsPut": {
    "endpoint": "community_notification_settings_put",
    "operation": "CommunityNotificationSettingsPut",
    "queryId": "p63ohfUyKiuNkjoFNitdpw",
    "http": "POST",
    "features": "B"
  },
  "CommunityPutAccessMutation": {
    "endpoint": "community_put_access_mutation",
    "operation": "CommunityPutAccessMutation",
    "queryId": "MmpsbUxs9rWu7bIwvPu5iw",
    "http": "POST",
    "features": "B"
  },
  "CommunityPutCustomBannerMediaMutation": {
    "endpoint": "community_put_custom_banner_media_mutation",
    "operation": "CommunityPutCustomBannerMediaMutation",
    "queryId": "vyj86DZS6bHE_8ng7JK1oQ",
    "http": "POST",
    "features": "B"
  },
  "CommunityPutRoleMutation": {
    "endpoint": "community_put_role_mutation",
    "operation": "CommunityPutRoleMutation",
    "queryId": "XJdcD4nIy4gtjdgzbrhWxg",
    "http": "POST",
    "features": "B"
  },
  "CommunityPutThemeMutation": {
    "endpoint": "community_put_theme_mutation",
    "operation": "CommunityPutThemeMutation",
    "queryId": "pVcjdirmdoOA_LrmI8OiPQ",
    "http": "POST",
    "features": "B"
  },
  "CommunityQuestionPutMutation": {
    "endpoint": "community_question_put_mutation",
    "operation": "CommunityQuestionPutMutation",
    "queryId": "zdwUkzBoW_QDNZgUuyukfw",
    "http": "POST",
    "features": "B"
  },
  "CommunityRankedTimelineQuery": {
    "endpoint": "community_ranked_timeline_query",
    "operation": "CommunityRankedTimelineQuery",
    "queryId": "IbzoC9dQCnsObZT2hux3Wg",
    "http": "GET",
    "features": "A"
  },
  "CommunityRemoveRuleMutation": {
    "endpoint": "community_remove_rule_mutation",
    "operation": "CommunityRemoveRuleMutation",
    "queryId": "SWQAUTwDnKld8PmuI_qHqQ",
    "http": "POST",
    "features": "B"
  },
  "CommunityReorderRulesMutation": {
    "endpoint": "community_reorder_rules_mutation",
    "operation": "CommunityReorderRulesMutation",
    "queryId": "yYZYyj9qNpcp7fUA7qiWHw",
    "http": "POST",
    "features": "B"
  },
  "CommunityTopicPutMutation": {
    "endpoint": "community_topic_put_mutation",
    "operation": "CommunityTopicPutMutation",
    "queryId": "rtZELWQjbanMtC7MiQhaQA",
    "http": "POST",
    "features": "B"
  },
  "CommunityTweetPinMutation": {
    "endpoint": "community_tweet_pin_mutation",
    "operation": "CommunityTweetPinMutation",
    "queryId": "RjSIAwLZ8xuLNFiso5CuoQ",
    "http": "POST",
    "features": ""
  },
  "CommunityTweetUnpinMutation": {
    "endpoint": "community_tweet_unpin_mutation",
    "operation": "CommunityTweetUnpinMutation",
    "queryId": "TK-NHiG8XZeS3eb08BxVhw",
    "http": "POST",
    "features": ""
  },
  "CommunityUpdateHashtagMutation": {
    "endpoint": "community_update_hashtag_mutation",
    "operation": "CommunityUpdateHashtagMutation",
    "queryId": "FwxmeuTYsnuCQq5MUxpj2g",
    "http": "POST",
    "features": "B"
  },
  "CommunityUpdateRuleMutation": {
    "endpoint": "community_update_rule_mutation",
    "operation": "CommunityUpdateRuleMutation",
    "queryId": "NKP_gS_p3iOu3X6vJnmz0w",
    "http": "POST",
    "features": "B"
  },
  "CommunityUpdateSearchTagsMutation": {
    "endpoint": "community_update_search_tags_mutation",
    "operation": "CommunityUpdateSearchTagsMutation",
    "queryId": "u1AVfRfzvsB17ONypzZQaQ",
    "http": "POST",
    "features": "B"
  },
  "ConnectTab": {
    "endpoint": "connect_tab",
    "operation": "ConnectTab",
    "queryId": "RTJc0G9YcNe8TWuewkngkA",
    "http": "GET",
    "features": "A"
  },
  "ConversationDeleteMutation": {
    "endpoint": "",
    "operation": "ConversationDeleteMutation",
    "queryId": "YHFgPwrwwnml8gF8H1YhCA",
    "http": "POST",
    "features": ""
  },
  "ConversationTimelineV2": {
    "endpoint": "conversation_timeline_v2",
    "operation": "ConversationTimelineV2",
    "queryId": "ynuAOEJ9yj3sUrd0OQb2eQ",
    "http": "GET",
    "features": "A"
  },
  "CreateCommerceProductSet": {
    "endpoint": "create_commerce_product_set",
    "operation": "CreateCommerceProductSet",
    "queryId": "5_Qxn8NnKGtMPxQPruYp_g",
    "http": "POST",
    "features": ""
  },
  "CreateConversationPinnedTweet": {
    "endpoint": "create_conversation_pinned_tweet",
    "operation": "CreateConversationPinnedTweet",
    "queryId": "e3H1Np2VoeQV0Q4DM-m-2A",
    "http": "POST",
    "features": ""
  },
  "CreateGroupConversationMutation": {
    "endpoint": "",
    "operation": "CreateGroupConversationMutation",
    "queryId": "dKl4aC-sBqQWgRhkQXV2wg",
    "http": "POST",
    "features": ""
  },
  "CreateHumanizationNudge": {
    "endpoint": "create_humanization_nudge",
    "operation": "CreateHumanizationNudge",
    "queryId": "5rFCYANcz_YmwllYWd8ulA",
    "http": "POST",
    "features": ""
  },
  "CreateNoteTweet": {
    "endpoint": "create_note_tweet",
    "operation": "CreateNoteTweet",
    "queryId": "O5XC8wy4c9gvHD--ESnFSw",
    "http": "POST",
    "features": "A"
  },
  "CreateNudge": {
    "endpoint": "create_nudge",
    "operation": "CreateNudge",
    "queryId": "wFmywMJdr-hzxtC6yG5ZuA",
    "http": "POST",
    "features": ""
  },
  "CreateRetweet": {
    "endpoint": "create_retweet",
    "operation": "CreateRetweet",
    "queryId": "mbRO74GrOvSfRcJnlMapnQ",
    "http": "POST",
    "features": "A"
  },
  "CreateTweet": {
    "endpoint": "create_tweet",
    "operation": "CreateTweet",
    "queryId": "GYdIGqVWfZNho79bQ2XDoA",
    "http": "POST",
    "features": "A"
  },
  "CreateTweetWithUndo": {
    "endpoint": "create_tweet_with_undo",
    "operation": "CreateTweetWithUndo",
    "queryId": "kc9IvxKXLkIvY3ldZukHDg",
    "http": "POST",
    "features": ""
  },
  "CreatorSubscriptionsTimelineQuery": {
    "endpoint": "creator_subscriptions_timeline_query",
    "operation": "CreatorSubscriptionsTimelineQuery",
    "queryId": "MkuUVjfQX61A4xH4mSxN5A",
    "http": "GET",
    "features": "A"
  },
  "DelegateListDelegationGroupsQuery": {
    "endpoint": "delegate_list_delegation_groups_query",
    "operation": "DelegateListDelegationGroupsQuery",
    "queryId": "3zACe70xDse-DL5ZzC_FJA",
    "http": "GET",
    "features": "B"
  },
  "DeleteContentDisclosure": {
    "endpoint": "delete_content_disclosure",
    "operation": "DeleteContentDisclosure",
    "queryId": "4bn0nJkcKya0sixErE_ixw",
    "http": "POST",
    "features": ""
  },
  "DeleteConversationPinnedTweet": {
    "endpoint": "delete_conversation_pinned_tweet",
    "operation": "DeleteConversationPinnedTweet",
    "queryId": "AIoKJbPhwO-7lCdZz4ivdw",
    "http": "POST",
    "features": ""
  },
  "DeleteDraftTweet": {
    "endpoint": "delete_draft_tweet",
    "operation": "DeleteDraftTweet",
    "queryId": "N9XszeuKTQsVfwsjaC69WQ",
    "http": "POST",
    "features": ""
  },
  "DeleteMessageMutation": {
    "endpoint": "",
    "operation": "DeleteMessageMutation",
    "queryId": "4gsDQKEmYkOtvsSIpHXdQA",
    "http": "POST",
    "features": ""
  },
  "DeleteMessageRequestInboxMutation": {
    "endpoint": "",
    "operation": "DeleteMessageRequestInboxMutation",
    "queryId": "YnRLd7nyqZHq6ZFBwZqeqw",
    "http": "POST",
    "features": ""
  },
  "DeleteRetweet": {
    "endpoint": "delete_retweet",
    "operation": "DeleteRetweet",
    "queryId": "ZyZigVsNiFO6v1dEks1eWg",
    "http": "POST",
    "features": ""
  },
  "DeleteTweet": {
    "endpoint": "delete_tweet",
    "operation": "DeleteTweet",
    "queryId": "nxpZCY2K-I6QoFHAHeojFQ",
    "http": "POST",
    "features": ""
  },
  "DeleteXChatPublicKeyMutation": {
    "endpoint": "",
    "operation": "DeleteXChatPublicKeyMutation",
    "queryId": "W5iiIL1MVw4vomq-zLPHUQ",
    "http": "POST",
    "features": ""
  },
  "DisableGroupInviteMutation": {
    "endpoint": "",
    "operation": "DisableGroupInviteMutation",
    "queryId": "GIIfeUYJ6NwVK9Deyw2Dqg",
    "http": "POST",
    "features": ""
  },
  "DisableScreenCaptureBlockingMutation": {
    "endpoint": "",
    "operation": "DisableScreenCaptureBlockingMutation",
    "queryId": "qrnlxRj5zx9nYo7QKkJMSw",
    "http": "POST",
    "features": ""
  },
  "DisableUserAccountLabel": {
    "endpoint": "disable_user_account_label",
    "operation": "DisableUserAccountLabel",
    "queryId": "_ckHEj05gan2VfNHG6thBA",
    "http": "POST",
    "features": ""
  },
  "DisableVerifiedPhoneLabel": {
    "endpoint": "disable_verified_phone_label",
    "operation": "DisableVerifiedPhoneLabel",
    "queryId": "GgA_lP_kCppRoBKvrdnefw",
    "http": "POST",
    "features": ""
  },
  "DmAvPermissionsQuery": {
    "endpoint": "",
    "operation": "DmAvPermissionsQuery",
    "queryId": "kfX5AHDKZrivyHwCaz68mQ",
    "http": "POST",
    "features": ""
  },
  "DmBlockMutation": {
    "endpoint": "",
    "operation": "DmBlockMutation",
    "queryId": "8OFwIC6-G-KVg4LCu7V0oQ",
    "http": "POST",
    "features": ""
  },
  "DmClientAddConversationLabelMutation": {
    "endpoint": "dm_client_add_conversation_label_mutation",
    "operation": "DmClientAddConversationLabelMutation",
    "queryId": "wresodBLD4xXZgtUreymOQ",
    "http": "POST",
    "features": ""
  },
  "DmClientConversationLabelsQuery": {
    "endpoint": "dm_client_conversation_labels_query",
    "operation": "DmClientConversationLabelsQuery",
    "queryId": "q4LiIZ0HjhzLLoKUwQLUJA",
    "http": "GET",
    "features": ""
  },
  "DmClientDeleteConversationLabelMutation": {
    "endpoint": "dm_client_delete_conversation_label_mutation",
    "operation": "DmClientDeleteConversationLabelMutation",
    "queryId": "JoRjWtplNLRVEwL3GlXo3g",
    "http": "POST",
    "features": ""
  },
  "DmClientEducationFlagsQuery": {
    "endpoint": "dm_client_education_flags_query",
    "operation": "DmClientEducationFlagsQuery",
    "queryId": "PjbVlSKO16LqZMMXPbZRww",
    "http": "GET",
    "features": ""
  },
  "DmClientEducationFlagsUpdate": {
    "endpoint": "dm_client_education_flags_update",
    "operation": "DmClientEducationFlagsUpdate",
    "queryId": "RCi-0mNWwT3z1kOlStYmeg",
    "http": "POST",
    "features": ""
  },
  "DmClientModularSearchQueryAll": {
    "endpoint": "dm_client_modular_search_query_all",
    "operation": "DmClientModularSearchQueryAll",
    "queryId": "-Cx-v10mNXJYwJpcwpehoA",
    "http": "GET",
    "features": "A"
  },
  "DmMutedUsersTimelineQuery": {
    "endpoint": "dm_muted_users_timeline_query",
    "operation": "DmMutedUsersTimelineQuery",
    "queryId": "EEovcHXJXFJtBHnKHANOgw",
    "http": "GET",
    "features": "A"
  },
  "DmSettingsQuery": {
    "endpoint": "",
    "operation": "DmSettingsQuery",
    "queryId": "jr8PVMRdhyJcEsDlNL87Vg",
    "http": "POST",
    "features": ""
  },
  "DmUnblockMutation": {
    "endpoint": "",
    "operation": "DmUnblockMutation",
    "queryId": "aJgYJD7N7GNauvCBRJy4sg",
    "http": "POST",
    "features": ""
  },
  "EditDraftTweet": {
    "endpoint": "edit_draft_tweet",
    "operation": "EditDraftTweet",
    "queryId": "twf753nZ7krWNelKcm4Pww",
    "http": "POST",
    "features": ""
  },
  "EditGroupConversationMutation": {
    "endpoint": "",
    "operation": "EditGroupConversationMutation",
    "queryId": "BdxAfKRHyLj-dYHpCqu7Ag",
    "http": "POST",
    "features": ""
  },
  "EditHistoryTimeline": {
    "endpoint": "edit_history_timeline",
    "operation": "EditHistoryTimeline",
    "queryId": "yTjoiI4_lZO3FwiUSoFsCQ",
    "http": "GET",
    "features": "A"
  },
  "EnableGroupInviteMutation": {
    "endpoint": "",
    "operation": "EnableGroupInviteMutation",
    "queryId": "WlxTMdzK_uh-miHVHXv15g",
    "http": "POST",
    "features": ""
  },
  "EnableScreenCaptureBlockingMutation": {
    "endpoint": "",
    "operation": "EnableScreenCaptureBlockingMutation",
    "queryId": "8X3jRUeAYXWoQ025G0B73g",
    "http": "POST",
    "features": ""
  },
  "ExclusiveTweetFollow": {
    "endpoint": "exclusive_tweet_follow",
    "operation": "ExclusiveTweetFollow",
    "queryId": "HpKeTQhHvXJRlyIfpCfI-w",
    "http": "POST",
    "features": ""
  },
  "ExclusiveTweetUnfollow": {
    "endpoint": "exclusive_tweet_unfollow",
    "operation": "ExclusiveTweetUnfollow",
    "queryId": "xzwqNvWt_NYHS2imizbZHQ",
    "http": "POST",
    "features": ""
  },
  "Explore": {
    "endpoint": "explore",
    "operation": "Explore",
    "queryId": "Zj8saoqORjPaB8FKXwaYPg",
    "http": "GET",
    "features": "A"
  },
  "ExploreCommunitiesTimelineQuery": {
    "endpoint": "",
    "operation": "ExploreCommunitiesTimelineQuery",
    "queryId": "3ZXzvGpErqZZ5dmM2XPt9w",
    "http": "POST",
    "features": ""
  },
  "FavoritersTimeline": {
    "endpoint": "favoriters_timeline",
    "operation": "FavoritersTimeline",
    "queryId": "BK7iAo3fXG0bjpwEKWa74Q",
    "http": "GET",
    "features": "A"
  },
  "FavoritesByTimeTimelineV2": {
    "endpoint": "favorites_by_time_timeline_v2",
    "operation": "FavoritesByTimeTimelineV2",
    "queryId": "dsnvKsvXlO8lZAVXMPuAQQ",
    "http": "GET",
    "features": "A"
  },
  "FavoriteTweet": {
    "endpoint": "favorite_tweet",
    "operation": "FavoriteTweet",
    "queryId": "lI07N6Otwv1PhnEgXILM7A",
    "http": "POST",
    "features": ""
  },
  "FavouritersTimelineQuery": {
    "endpoint": "",
    "operation": "FavouritersTimelineQuery",
    "queryId": "kCov7kr120K_9fwaz4JA0A",
    "http": "POST",
    "features": ""
  },
  "FeatureSettingsUpdate": {
    "endpoint": "feature_settings_update",
    "operation": "FeatureSettingsUpdate",
    "queryId": "-btar_vkBwWA7s3YWfp_9g",
    "http": "POST",
    "features": ""
  },
  "FetchPopularCommunities": {
    "endpoint": "fetch_popular_communities",
    "operation": "FetchPopularCommunities",
    "queryId": "EiMwFEG2PzOn979HpG23Pw",
    "http": "GET",
    "features": "B"
  },
  "FetchUserCommunityTopics": {
    "endpoint": "fetch_user_community_topics",
    "operation": "FetchUserCommunityTopics",
    "queryId": "cB8JuuBREn4Myv74lL_hYg",
    "http": "GET",
    "features": ""
  },
  "FinalizeXChatMediaUploadMutation": {
    "endpoint": "",
    "operation": "FinalizeXChatMediaUploadMutation",
    "queryId": "P1CLOMdiMe9ii1MdIJbhcQ",
    "http": "POST",
    "features": ""
  },
  "FinanceSearchTags": {
    "endpoint": "",
    "operation": "FinanceSearchTags",
    "queryId": "u1vv2E2q1AWovMU0KwmZ6Q",
    "http": "POST",
    "features": ""
  },
  "FleetsStickersSearch": {
    "endpoint": "fleets_stickers_search",
    "operation": "FleetsStickersSearch",
    "queryId": "K53PIWlaebqBe1CNf0pVhg",
    "http": "GET",
    "features": ""
  },
  "FleetsStickersSuggestion": {
    "endpoint": "fleets_stickers_suggestion",
    "operation": "FleetsStickersSuggestion",
    "queryId": "TdmKeqM35mQR7e9MueyYMw",
    "http": "GET",
    "features": ""
  },
  "GenerateMapsUrlFromAddress": {
    "endpoint": "generate_maps_url_from_address",
    "operation": "GenerateMapsUrlFromAddress",
    "queryId": "hr7n-QUOy6nTRhWIaZKdhg",
    "http": "GET",
    "features": ""
  },
  "GenerateXChatTokenMutation": {
    "endpoint": "",
    "operation": "GenerateXChatTokenMutation",
    "queryId": "Qh3fZRjPPtPoHYR_2sCZsA",
    "http": "POST",
    "features": ""
  },
  "GetAiTrendById": {
    "endpoint": "",
    "operation": "GetAiTrendById",
    "queryId": "m3g_VDR_IupaFw-gQJdumQ",
    "http": "GET",
    "features": ""
  },
  "GetCardPreviewOrJetfuelFromUrlQuery": {
    "endpoint": "",
    "operation": "GetCardPreviewOrJetfuelFromUrlQuery",
    "queryId": "u5pgewGXcOMNzL2wKJhoWg",
    "http": "POST",
    "features": ""
  },
  "GetConversationControlSettings": {
    "endpoint": "get_conversation_control_settings",
    "operation": "GetConversationControlSettings",
    "queryId": "uSS1UZnreGvtXo8463kSxQ",
    "http": "GET",
    "features": ""
  },
  "GetConversationPageQuery": {
    "endpoint": "",
    "operation": "GetConversationPageQuery",
    "queryId": "IVlXls9JTnbgQ1gxsGAfJA",
    "http": "POST",
    "features": ""
  },
  "GetDraftTweets": {
    "endpoint": "get_draft_tweets",
    "operation": "GetDraftTweets",
    "queryId": "HaOsXLTy8FkNUD58u-RfZg",
    "http": "GET",
    "features": ""
  },
  "GetGroupJoinRequestsQuery": {
    "endpoint": "",
    "operation": "GetGroupJoinRequestsQuery",
    "queryId": "zHaHj9LnoXunUykdWf9QIg",
    "http": "POST",
    "features": ""
  },
  "GetInboxPageConversationDataQuery": {
    "endpoint": "",
    "operation": "GetInboxPageConversationDataQuery",
    "queryId": "uSZ-OyrgS_zbJ3S_byhXfQ",
    "http": "POST",
    "features": ""
  },
  "GetInboxPageRequestQuery": {
    "endpoint": "",
    "operation": "GetInboxPageRequestQuery",
    "queryId": "CxDhMZdF2DKEJriMkWIRCw",
    "http": "POST",
    "features": ""
  },
  "GetInitialXChatPageQuery": {
    "endpoint": "",
    "operation": "GetInitialXChatPageQuery",
    "queryId": "XbDtnn4iqMRO13uK4cgqCA",
    "http": "POST",
    "features": ""
  },
  "GetJetfuelAttachmentComposer": {
    "endpoint": "",
    "operation": "GetJetfuelAttachmentComposer",
    "queryId": "sK_rJkDSVO_F7MSoF-Na2Q",
    "http": "POST",
    "features": ""
  },
  "GetJoinedCommunities": {
    "endpoint": "",
    "operation": "GetJoinedCommunities",
    "queryId": "JBOtFRiRxHNfYrkcbwMDTA",
    "http": "POST",
    "features": ""
  },
  "GetMessageEventsBySequenceIdQuery": {
    "endpoint": "",
    "operation": "GetMessageEventsBySequenceIdQuery",
    "queryId": "WU1OOeTQbDQX8sc-HdCk8g",
    "http": "POST",
    "features": ""
  },
  "GetMessageEventsPageQuery": {
    "endpoint": "",
    "operation": "GetMessageEventsPageQuery",
    "queryId": "OaSNyAhxUZ9AaW2z9cC26A",
    "http": "POST",
    "features": ""
  },
  "GetMessageReadTimestampsQuery": {
    "endpoint": "",
    "operation": "GetMessageReadTimestampsQuery",
    "queryId": "AOomju6YIYHWl2XjC55-Cg",
    "http": "POST",
    "features": ""
  },
  "GetMessageRequestsPageQuery": {
    "endpoint": "",
    "operation": "GetMessageRequestsPageQuery",
    "queryId": "tLMyTOvXOXoA3Pi41p7x4Q",
    "http": "POST",
    "features": ""
  },
  "GetPostById": {
    "endpoint": "",
    "operation": "GetPostById",
    "queryId": "UEHajIwFFcBXQOXCt3xvHQ",
    "http": "POST",
    "features": ""
  },
  "GetProfileConnectionPage": {
    "endpoint": "",
    "operation": "GetProfileConnectionPage",
    "queryId": "BV5FQH8cR7yndazEwmKTZg",
    "http": "POST",
    "features": ""
  },
  "GetProfileConnectionPageByScreenName": {
    "endpoint": "",
    "operation": "GetProfileConnectionPageByScreenName",
    "queryId": "qfZu4esl8joPGC4bjRBUJQ",
    "http": "POST",
    "features": ""
  },
  "GetPublicKeys": {
    "endpoint": "",
    "operation": "GetPublicKeys",
    "queryId": "GJQbOZALDO5D3Zp2IZhH6w",
    "http": "POST",
    "features": ""
  },
  "GetTopicPage": {
    "endpoint": "",
    "operation": "GetTopicPage",
    "queryId": "WzRbW8nl9-ZJ2ZBhA0hfNQ",
    "http": "POST",
    "features": ""
  },
  "GetUsernameAvailabilityAndSuggestions": {
    "endpoint": "get_username_availability_and_suggestions",
    "operation": "GetUsernameAvailabilityAndSuggestions",
    "queryId": "zmlkjCoEDEMzTCuLlOKPAA",
    "http": "POST",
    "features": ""
  },
  "GetUsersByIdsForXChat": {
    "endpoint": "",
    "operation": "GetUsersByIdsForXChat",
    "queryId": "2jiOJf7Xr0Lcr3pDxGWp-g",
    "http": "POST",
    "features": ""
  },
  "GifEnumerateCategoryQuery": {
    "endpoint": "",
    "operation": "GifEnumerateCategoryQuery",
    "queryId": "sbJqgmKCeJWPedP7WGe7OQ",
    "http": "POST",
    "features": ""
  },
  "GifSearchQuery": {
    "endpoint": "",
    "operation": "GifSearchQuery",
    "queryId": "ciUL4BnRPKal2uL1fL2aHw",
    "http": "POST",
    "features": ""
  },
  "GlobalCommunitiesLatestPostSearchTimeline": {
    "endpoint": "global_communities_latest_post_search_timeline",
    "operation": "GlobalCommunitiesLatestPostSearchTimeline",
    "queryId": "Fae3b6-iWlKR2xnc2V-fiw",
    "http": "GET",
    "features": "C"
  },
  "GlobalCommunitiesPostSearchTimeline": {
    "endpoint": "global_communities_post_search_timeline",
    "operation": "GlobalCommunitiesPostSearchTimeline",
    "queryId": "flrmikCoPPiQobzbRlBizg",
    "http": "GET",
    "features": "C"
  },
  "GlobalMentionSettingsPut": {
    "endpoint": "global_mention_settings_put",
    "operation": "GlobalMentionSettingsPut",
    "queryId": "mHn0VT8f-v4qtt12DeZIEQ",
    "http": "POST",
    "features": ""
  },
  "GrokAutoTranslationToggleMutation": {
    "endpoint": "grok_auto_translation_toggle_mutation",
    "operation": "GrokAutoTranslationToggleMutation",
    "queryId": "3f9Qr6WPCh76-ip7h2r-tA",
    "http": "POST",
    "features": ""
  },
  "GrokAutoTranslationToggleQuery": {
    "endpoint": "grok_auto_translation_toggle_query",
    "operation": "GrokAutoTranslationToggleQuery",
    "queryId": "J0iibs_CtTMRvj1R7Iykmg",
    "http": "GET",
    "features": ""
  },
  "GroupInviteDetailsQuery": {
    "endpoint": "",
    "operation": "GroupInviteDetailsQuery",
    "queryId": "wubTkA5DWZXuf3ugyqStPg",
    "http": "POST",
    "features": ""
  },
  "HomeTimeline": {
    "endpoint": "home_timeline",
    "operation": "HomeTimeline",
    "queryId": "ob5uGlwVI-iAKKFx9YXoqg",
    "http": "GET",
    "features": "A"
  },
  "HomeTimelineLatest": {
    "endpoint": "home_timeline_latest",
    "operation": "HomeTimelineLatest",
    "queryId": "GQ6KFu0SWm7PFm62aMik5Q",
    "http": "GET",
    "features": "A"
  },
  "HomeTimelineSubscriptions": {
    "endpoint": "home_timeline_subscriptions",
    "operation": "HomeTimelineSubscriptions",
    "queryId": "QoCcCX98Vugy3DwpJf5pnw",
    "http": "GET",
    "features": "A"
  },
  "ImmersiveViewerExploreMixerTimeline": {
    "endpoint": "immersive_viewer_explore_mixer_timeline",
    "operation": "ImmersiveViewerExploreMixerTimeline",
    "queryId": "UsztxIRwP6dxXKuVoQTIRw",
    "http": "GET",
    "features": "A"
  },
  "InitializeGroupConversationMutation": {
    "endpoint": "",
    "operation": "InitializeGroupConversationMutation",
    "queryId": "5zG9k_50ppvLTtPZbOC1NQ",
    "http": "POST",
    "features": ""
  },
  "InitializeXChatMediaUploadMutation": {
    "endpoint": "",
    "operation": "InitializeXChatMediaUploadMutation",
    "queryId": "vTsSDEpF4eVYbR-waSl37g",
    "http": "POST",
    "features": ""
  },
  "IsIdentityVerifiedLabelHiddenPut": {
    "endpoint": "is_identity_verified_label_hidden_put",
    "operation": "IsIdentityVerifiedLabelHiddenPut",
    "queryId": "KmEBnm_9O0-m_eRYZ6yqUA",
    "http": "POST",
    "features": ""
  },
  "ListByIdQuery": {
    "endpoint": "list_by_id_query",
    "operation": "ListByIdQuery",
    "queryId": "yJMGpM1RdI_3phPHH__0yQ",
    "http": "GET",
    "features": "B"
  },
  "ListCreate": {
    "endpoint": "list_create",
    "operation": "ListCreate",
    "queryId": "KMsf_KtiCWe5Rm0mAGSc4w",
    "http": "POST",
    "features": "B"
  },
  "ListCreateRecommendedUsersTimeline": {
    "endpoint": "list_create_recommended_users_timeline",
    "operation": "ListCreateRecommendedUsersTimeline",
    "queryId": "ReCJYeLHY2VGcSxFNtsZhA",
    "http": "GET",
    "features": "A"
  },
  "ListDelete": {
    "endpoint": "list_delete",
    "operation": "ListDelete",
    "queryId": "GaNPVF9EcFNrK01zcocfjQ",
    "http": "POST",
    "features": ""
  },
  "ListDeleteBannerMedia": {
    "endpoint": "list_delete_banner_media",
    "operation": "ListDeleteBannerMedia",
    "queryId": "07FMxdyHNUu22qrMlFAk_A",
    "http": "POST",
    "features": "B"
  },
  "ListEditRecommendedUsersTimeline": {
    "endpoint": "list_edit_recommended_users_timeline",
    "operation": "ListEditRecommendedUsersTimeline",
    "queryId": "3swSgnFQkNtBhhi2hSa0Vw",
    "http": "GET",
    "features": "A"
  },
  "ListManagementTimelineQuery": {
    "endpoint": "",
    "operation": "ListManagementTimelineQuery",
    "queryId": "matXd6ZyjE-rbQdxEecZrQ",
    "http": "POST",
    "features": ""
  },
  "ListMemberAdd": {
    "endpoint": "list_member_add",
    "operation": "ListMemberAdd",
    "queryId": "RbKnkhWtKALMS6HHfiZoZg",
    "http": "POST",
    "features": "B"
  },
  "ListMemberRemove": {
    "endpoint": "list_member_remove",
    "operation": "ListMemberRemove",
    "queryId": "U-6aeEPiVJGzvDDTrsvBmw",
    "http": "POST",
    "features": "B"
  },
  "ListMembership": {
    "endpoint": "list_membership",
    "operation": "ListMembership",
    "queryId": "9iZQVKdMyngPnty1C1nRcw",
    "http": "GET",
    "features": "A"
  },
  "ListMembershipByScreenName": {
    "endpoint": "list_membership_by_screen_name",
    "operation": "ListMembershipByScreenName",
    "queryId": "QxyJEqANLHiOv5zPm0InJQ",
    "http": "GET",
    "features": "A"
  },
  "ListMembershipQuery": {
    "endpoint": "",
    "operation": "ListMembershipQuery",
    "queryId": "Kpc_Mwu3CxzKzWdsiUp--Q",
    "http": "POST",
    "features": ""
  },
  "ListMembersTimelineQuery": {
    "endpoint": "list_members_timeline_query",
    "operation": "ListMembersTimelineQuery",
    "queryId": "vGLgs46I2qul03193HUbBg",
    "http": "GET",
    "features": "A"
  },
  "ListOwnershipsTimelineQuery": {
    "endpoint": "",
    "operation": "ListOwnershipsTimelineQuery",
    "queryId": "2EcVEDNHclRWvi1fvHQ8dA",
    "http": "POST",
    "features": ""
  },
  "ListPutBannerMedia": {
    "endpoint": "list_put_banner_media",
    "operation": "ListPutBannerMedia",
    "queryId": "NBHhKRCbMLaTHKhaqmTFyg",
    "http": "POST",
    "features": "B"
  },
  "ListsTimelineQuery": {
    "endpoint": "",
    "operation": "ListsTimelineQuery",
    "queryId": "-o9MiGu2tUoTvgjG8hodEA",
    "http": "POST",
    "features": ""
  },
  "ListSubscribersTimelineQuery": {
    "endpoint": "list_subscribers_timeline_query",
    "operation": "ListSubscribersTimelineQuery",
    "queryId": "kvpzagUdyPrnbHrqbEgSOA",
    "http": "GET",
    "features": "A"
  },
  "ListTimeline": {
    "endpoint": "list_timeline",
    "operation": "ListTimeline",
    "queryId": "wpHYCmyAIJMeqCtrol-8iQ",
    "http": "GET",
    "features": "A"
  },
  "ListUpdate": {
    "endpoint": "list_update",
    "operation": "ListUpdate",
    "queryId": "K_kCz0uS1FtS9evq19N5vg",
    "http": "POST",
    "features": "B"
  },
  "LoggedOutMrById": {
    "endpoint": "logged_out_mr_by_id",
    "operation": "LoggedOutMrById",
    "queryId": "3FLq_70RtztZLCNkjDYkKQ",
    "http": "GET",
    "features": ""
  },
  "MediaTimelineV2": {
    "endpoint": "media_timeline_v2",
    "operation": "MediaTimelineV2",
    "queryId": "gegyTdW8YAo0uCX9eVFk3Q",
    "http": "GET",
    "features": "A"
  },
  "ModeratedTimeline": {
    "endpoint": "moderated_timeline",
    "operation": "ModeratedTimeline",
    "queryId": "th7flEwW9aU2-Rj9Xr8Jbg",
    "http": "GET",
    "features": "A"
  },
  "ModeratedTweetTimelineQuery": {
    "endpoint": "",
    "operation": "ModeratedTweetTimelineQuery",
    "queryId": "lKT4bcFBoA17jVnElbIbRg",
    "http": "POST",
    "features": ""
  },
  "MutationSubscribeToDrop": {
    "endpoint": "mutation_subscribe_to_drop",
    "operation": "MutationSubscribeToDrop",
    "queryId": "BoGso1y83zrtRP9CRpdRkA",
    "http": "POST",
    "features": ""
  },
  "MutationUnsubscribeFromDrop": {
    "endpoint": "mutation_unsubscribe_from_drop",
    "operation": "MutationUnsubscribeFromDrop",
    "queryId": "PPQmv0KgHVZ0gpDOfkEb8Q",
    "http": "POST",
    "features": ""
  },
  "MutationUploadCommerceProducts": {
    "endpoint": "mutation_upload_commerce_products",
    "operation": "MutationUploadCommerceProducts",
    "queryId": "txQwI4tQ8RfQxEN3SCeAkw",
    "http": "POST",
    "features": ""
  },
  "MuteConversationMutation": {
    "endpoint": "",
    "operation": "MuteConversationMutation",
    "queryId": "6iDsxSkhGLvdiJpqtAtzTQ",
    "http": "POST",
    "features": ""
  },
  "NotificationTimelineQuery": {
    "endpoint": "",
    "operation": "NotificationTimelineQuery",
    "queryId": "5BWBRnlena4_KqkQiWeIaQ",
    "http": "POST",
    "features": ""
  },
  "NuxUserRecommendationsPageQuery": {
    "endpoint": "nux_user_recommendations_page_query",
    "operation": "NuxUserRecommendationsPageQuery",
    "queryId": "07zfHSr1oANh296kxa28rA",
    "http": "GET",
    "features": "A"
  },
  "ParodyCommentaryFanLabelSettingsGet": {
    "endpoint": "parody_commentary_fan_label_settings_get",
    "operation": "ParodyCommentaryFanLabelSettingsGet",
    "queryId": "6i5XbW86EwI3LNXabguB-A",
    "http": "GET",
    "features": ""
  },
  "PasskeyAuthSettingsGet": {
    "endpoint": "passkey_auth_settings_get",
    "operation": "PasskeyAuthSettingsGet",
    "queryId": "D3o7y2ySvNMRD-oq0gDIEA",
    "http": "GET",
    "features": ""
  },
  "PinnableTimelinesQuery": {
    "endpoint": "pinnable_timelines_query",
    "operation": "PinnableTimelinesQuery",
    "queryId": "Sg42AEtZXoyqTMraDD1vJw",
    "http": "GET",
    "features": ""
  },
  "PinnedTimelinesQuery": {
    "endpoint": "pinned_timelines_query",
    "operation": "PinnedTimelinesQuery",
    "queryId": "MbRPLB5QUm99vtmz5tMM8w",
    "http": "GET",
    "features": "B"
  },
  "PinTimeline": {
    "endpoint": "pin_timeline",
    "operation": "PinTimeline",
    "queryId": "lrEwaoucVKgfBcVHzEetMQ",
    "http": "POST",
    "features": "B"
  },
  "PinTweet": {
    "endpoint": "pin_tweet",
    "operation": "PinTweet",
    "queryId": "ztf5duPxJV_QJOO6s-Pkzg",
    "http": "POST",
    "features": ""
  },
  "PlaySotreSubscriptionPurchaseToken": {
    "endpoint": "play_sotre_subscription_purchase_token",
    "operation": "PlaySotreSubscriptionPurchaseToken",
    "queryId": "kQJWXMdGvfAZ_4aFR2OEcA",
    "http": "GET",
    "features": ""
  },
  "ProductCatalog": {
    "endpoint": "product_catalog",
    "operation": "ProductCatalog",
    "queryId": "AwqAW3ilnprnFohpWIB84g",
    "http": "GET",
    "features": ""
  },
  "ProfileViewerExploreMixerTimeline": {
    "endpoint": "profile_viewer_explore_mixer_timeline",
    "operation": "ProfileViewerExploreMixerTimeline",
    "queryId": "dhvOtFrHu44e4d6--U9faQ",
    "http": "GET",
    "features": "A"
  },
  "QueryShopByRestIdV2": {
    "endpoint": "query_shop_by_rest_id_v2",
    "operation": "QueryShopByRestIdV2",
    "queryId": "Nln5InUoZ33JoGz3aV1CqA",
    "http": "GET",
    "features": ""
  },
  "QueryShopCoreDataV2": {
    "endpoint": "query_shop_core_data_v2",
    "operation": "QueryShopCoreDataV2",
    "queryId": "ZLJuehSCkqOJTIffu4SIyg",
    "http": "GET",
    "features": "B"
  },
  "RankedCommunitiesTimelineQuery": {
    "endpoint": "ranked_communities_timeline_query",
    "operation": "RankedCommunitiesTimelineQuery",
    "queryId": "o-sMgpcyEj7C-h7hTmCkGg",
    "http": "GET",
    "features": "A"
  },
  "RecordNudgeAction": {
    "endpoint": "record_nudge_action",
    "operation": "RecordNudgeAction",
    "queryId": "qr2AAR3Lx10iac0BXsmo0Q",
    "http": "POST",
    "features": ""
  },
  "RecordNudgeResult": {
    "endpoint": "record_nudge_result",
    "operation": "RecordNudgeResult",
    "queryId": "OxPPZHeXYtxTVRhXomfxNA",
    "http": "POST",
    "features": ""
  },
  "RejectJoinGroupMutation": {
    "endpoint": "",
    "operation": "RejectJoinGroupMutation",
    "queryId": "Y4VSHGC2pgQEc09Ek1pgZA",
    "http": "POST",
    "features": ""
  },
  "RemoveAsAdminMutation": {
    "endpoint": "",
    "operation": "RemoveAsAdminMutation",
    "queryId": "i3RDeN7PE4lDpu7dpPjbZw",
    "http": "POST",
    "features": ""
  },
  "RemoveConversationTTLMutation": {
    "endpoint": "",
    "operation": "RemoveConversationTTLMutation",
    "queryId": "EqSXvxskUyw99ARuIbhYlg",
    "http": "POST",
    "features": ""
  },
  "RemoveFollower": {
    "endpoint": "remove_follower",
    "operation": "RemoveFollower",
    "queryId": "QpNfg0kpPRfjROQ_9eOLXA",
    "http": "POST",
    "features": ""
  },
  "RemoveFromGroupMutation": {
    "endpoint": "",
    "operation": "RemoveFromGroupMutation",
    "queryId": "ZAg00_bioEzpvPesmrNPHg",
    "http": "POST",
    "features": ""
  },
  "RemoveSuperFollowPrivacy": {
    "endpoint": "remove_super_follow_privacy",
    "operation": "RemoveSuperFollowPrivacy",
    "queryId": "sV7dnzS0EjSctagwg4kcaA",
    "http": "POST",
    "features": ""
  },
  "ReportDetailQuery": {
    "endpoint": "report_detail_query",
    "operation": "ReportDetailQuery",
    "queryId": "jvTvzl6_BeSqaKx4EPn2hw",
    "http": "GET",
    "features": ""
  },
  "RepostersTimelineQuery": {
    "endpoint": "",
    "operation": "RepostersTimelineQuery",
    "queryId": "kX8xZ7osckoBKOBQtoDC5Q",
    "http": "POST",
    "features": ""
  },
  "RequestToJoinGroupMutation": {
    "endpoint": "",
    "operation": "RequestToJoinGroupMutation",
    "queryId": "cV0VjzT5UDJW3cbcvALYOg",
    "http": "POST",
    "features": ""
  },
  "ResetPasscodeMutation": {
    "endpoint": "",
    "operation": "ResetPasscodeMutation",
    "queryId": "tmN0Hq8qLWhk3OEKHbpekA",
    "http": "POST",
    "features": ""
  },
  "RetweetersTimeline": {
    "endpoint": "retweeters_timeline",
    "operation": "RetweetersTimeline",
    "queryId": "8Bev736i73fHjdOAHWchHA",
    "http": "GET",
    "features": "A"
  },
  "SafetyModeDismissSuggestedAction": {
    "endpoint": "safety_mode_dismiss_suggested_action",
    "operation": "SafetyModeDismissSuggestedAction",
    "queryId": "VCzyC1OiUFidTNokWUIDkg",
    "http": "POST",
    "features": ""
  },
  "SafetyModeFacePile": {
    "endpoint": "safety_mode_face_pile",
    "operation": "SafetyModeFacePile",
    "queryId": "L5GGgGxgm-3vJOrPu9EknA",
    "http": "GET",
    "features": ""
  },
  "SafetyModeSettings": {
    "endpoint": "safety_mode_settings",
    "operation": "SafetyModeSettings",
    "queryId": "UBSi0yYDfd2SMtQrLPoD7A",
    "http": "GET",
    "features": ""
  },
  "SafetyModeSettingsPut": {
    "endpoint": "safety_mode_settings_put",
    "operation": "SafetyModeSettingsPut",
    "queryId": "d0lIMKMFYnyrGw39i_w5cw",
    "http": "POST",
    "features": ""
  },
  "ScheduledSpaceSubscriberDelete": {
    "endpoint": "scheduled_space_subscriber_delete",
    "operation": "ScheduledSpaceSubscriberDelete",
    "queryId": "okZ9Xy4CQvnG4pNezfOPjg",
    "http": "POST",
    "features": ""
  },
  "SearchCheckSubscribing": {
    "endpoint": "search_check_subscribing",
    "operation": "SearchCheckSubscribing",
    "queryId": "4SXaNZqATwxQ2a1JOfE1xA",
    "http": "GET",
    "features": ""
  },
  "SearchTimeline": {
    "endpoint": "search_timeline_web",
    "operation": "SearchTimeline",
    "queryId": "-TFXKoMnMTKdEXcCn-eahw",
    "http": "GET",
    "features": "C"
  },
  "SearchTimelineQuery": {
    "endpoint": "",
    "operation": "SearchTimelineQuery",
    "queryId": "WO0XY-EH2A4GEXdLtSTFgg",
    "http": "POST",
    "features": ""
  },
  "SearchUnsubscribe": {
    "endpoint": "search_unsubscribe",
    "operation": "SearchUnsubscribe",
    "queryId": "z8P6pVy7VZ1HX-ohx3mX9w",
    "http": "POST",
    "features": ""
  },
  "SendMessageCreateMutation": {
    "endpoint": "",
    "operation": "SendMessageCreateMutation",
    "queryId": "TWRPP7gnKwV_R8-tE-Dd3Q",
    "http": "POST",
    "features": ""
  },
  "SendMessageEventMutation": {
    "endpoint": "",
    "operation": "SendMessageEventMutation",
    "queryId": "G7WwJGKvTBVb-BXhZNSVMw",
    "http": "POST",
    "features": ""
  },
  "SensitiveMediaSettingsPut": {
    "endpoint": "sensitive_media_settings_put",
    "operation": "SensitiveMediaSettingsPut",
    "queryId": "8y2QEhYV5k3CKt08dik2xg",
    "http": "POST",
    "features": ""
  },
  "SetNotificationLastSeenCursor": {
    "endpoint": "",
    "operation": "SetNotificationLastSeenCursor",
    "queryId": "_XO56PQttE4SghAtv2ZgMQ",
    "http": "POST",
    "features": ""
  },
  "SmartTagQuery": {
    "endpoint": "smart_tag_query",
    "operation": "SmartTagQuery",
    "queryId": "5Yz8cmVvNqZqff3VpB8tyw",
    "http": "GET",
    "features": ""
  },
  "StartIdentityVerification": {
    "endpoint": "start_identity_verification",
    "operation": "StartIdentityVerification",
    "queryId": "Th45ocZ_zx4020KUriETEg",
    "http": "GET",
    "features": ""
  },
  "SubscriptionProductFeaturesFetch": {
    "endpoint": "subscription_product_features_fetch",
    "operation": "SubscriptionProductFeaturesFetch",
    "queryId": "Se5DRn5kQaZREBSyGOU7VA",
    "http": "GET",
    "features": ""
  },
  "SuperFollowProducts": {
    "endpoint": "super_follow_products",
    "operation": "SuperFollowProducts",
    "queryId": "FEELRJqfigRmUKIHWGjUKg",
    "http": "GET",
    "features": ""
  },
  "SwitchProfessionalAccountType": {
    "endpoint": "switch_professional_account_type",
    "operation": "SwitchProfessionalAccountType",
    "queryId": "wlCsIYN0kTO35cpIRhnBVQ",
    "http": "POST",
    "features": "B"
  },
  "SwitchToNonProfessional": {
    "endpoint": "switch_to_non_professional",
    "operation": "SwitchToNonProfessional",
    "queryId": "zB4TO_AlZK8HFbk0VwOGAQ",
    "http": "POST",
    "features": "B"
  },
  "TimelineByIdQuery": {
    "endpoint": "timeline_by_id_query",
    "operation": "TimelineByIdQuery",
    "queryId": "dmSFtR6IyzsK3F_Y77yBZQ",
    "http": "GET",
    "features": "A"
  },
  "TipjarDisableAll": {
    "endpoint": "tipjar_disable_all",
    "operation": "TipjarDisableAll",
    "queryId": "bOfyDg0mcmcKBIfAM8wAeA",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateBandcamp": {
    "endpoint": "tipjar_update_bandcamp",
    "operation": "TipjarUpdateBandcamp",
    "queryId": "c00UJFiEVx30KnYNIqLvHQ",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateBitcoin": {
    "endpoint": "tipjar_update_bitcoin",
    "operation": "TipjarUpdateBitcoin",
    "queryId": "0BEwxrrUaTXkE-0pz2jkEA",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateCashapp": {
    "endpoint": "tipjar_update_cashapp",
    "operation": "TipjarUpdateCashapp",
    "queryId": "scO5jbvhTG5vhFEtpOgKZA",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateChipper": {
    "endpoint": "tipjar_update_chipper",
    "operation": "TipjarUpdateChipper",
    "queryId": "RFsFCzgHx2qU5zjgfoze0g",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateEnabled": {
    "endpoint": "tipjar_update_enabled",
    "operation": "TipjarUpdateEnabled",
    "queryId": "5zLqCpUnH7SJPBN5FhRk3A",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateEthereum": {
    "endpoint": "tipjar_update_ethereum",
    "operation": "TipjarUpdateEthereum",
    "queryId": "FKOz-6SA3f-JTSE-vYVqcA",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateGofundme": {
    "endpoint": "tipjar_update_gofundme",
    "operation": "TipjarUpdateGofundme",
    "queryId": "y8l94dOu2zAgDU0vQuX2gw",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateKakaopay": {
    "endpoint": "tipjar_update_kakaopay",
    "operation": "TipjarUpdateKakaopay",
    "queryId": "WjLRHusB0lradOUlUg6eeQ",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdatePaga": {
    "endpoint": "tipjar_update_paga",
    "operation": "TipjarUpdatePaga",
    "queryId": "Khq-pQ-1FBv1a7EtdmUTWA",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdatePatreon": {
    "endpoint": "tipjar_update_patreon",
    "operation": "TipjarUpdatePatreon",
    "queryId": "ycZIphvbJx3oVA0Uzu7o0Q",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdatePaypal": {
    "endpoint": "tipjar_update_paypal",
    "operation": "TipjarUpdatePaypal",
    "queryId": "aerFfP78IoulpfVLEogsPw",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdatePaytm": {
    "endpoint": "tipjar_update_paytm",
    "operation": "TipjarUpdatePaytm",
    "queryId": "P9V1PMwL5UrlFq6naU7Q0A",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdatePicpay": {
    "endpoint": "tipjar_update_picpay",
    "operation": "TipjarUpdatePicpay",
    "queryId": "GZJt2p-xXT78gPUWvt8tJw",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateRazorpay": {
    "endpoint": "tipjar_update_razorpay",
    "operation": "TipjarUpdateRazorpay",
    "queryId": "jqQ1HajRO3K8KSDDggNuXg",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateStrike": {
    "endpoint": "tipjar_update_strike",
    "operation": "TipjarUpdateStrike",
    "queryId": "aZis6gjbxCm6QH3TlALNPw",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateVenmo": {
    "endpoint": "tipjar_update_venmo",
    "operation": "TipjarUpdateVenmo",
    "queryId": "GyB44tX86TuNkMlY8b8RZw",
    "http": "POST",
    "features": ""
  },
  "TipjarUpdateWealthsimple": {
    "endpoint": "tipjar_update_wealthsimple",
    "operation": "TipjarUpdateWealthsimple",
    "queryId": "tDIm6F3XyBWEG4cZ22WD1w",
    "http": "POST",
    "features": ""
  },
  "TopArticlesTimeline": {
    "endpoint": "top_articles_timeline",
    "operation": "TopArticlesTimeline",
    "queryId": "ncR-SqV6cggFi7Ui1KnnMQ",
    "http": "GET",
    "features": "A"
  },
  "TopicPageByRestIdNoBodyQuery": {
    "endpoint": "topic_page_by_rest_id_no_body_query",
    "operation": "TopicPageByRestIdNoBodyQuery",
    "queryId": "oxoWpwFeEGqV9mffKHxKsg",
    "http": "GET",
    "features": "B"
  },
  "TopicPageByRestIdQuery": {
    "endpoint": "topic_page_by_rest_id_query",
    "operation": "TopicPageByRestIdQuery",
    "queryId": "P14QLPx5dUEyp4jfz6I9yg",
    "http": "GET",
    "features": "A"
  },
  "TranslateProfileQuery": {
    "endpoint": "translate_profile_query",
    "operation": "TranslateProfileQuery",
    "queryId": "3j6Kad20h4vaJeld3QI8qg",
    "http": "GET",
    "features": ""
  },
  "TranslateTweetFeedback": {
    "endpoint": "translate_tweet_feedback",
    "operation": "TranslateTweetFeedback",
    "queryId": "Ieo99xS0aO4M53LWqbqKdA",
    "http": "POST",
    "features": ""
  },
  "TranslateTweetQuery": {
    "endpoint": "translate_tweet_query",
    "operation": "TranslateTweetQuery",
    "queryId": "WwIm9qup5zy3ttf7R4Apxw",
    "http": "GET",
    "features": ""
  },
  "TrustedFriendsListMemberAdd": {
    "endpoint": "trusted_friends_list_member_add",
    "operation": "TrustedFriendsListMemberAdd",
    "queryId": "Tp2OYiWFbwEf1YcRbXSI7A",
    "http": "POST",
    "features": "B"
  },
  "TrustedFriendsListMemberRemove": {
    "endpoint": "trusted_friends_list_member_remove",
    "operation": "TrustedFriendsListMemberRemove",
    "queryId": "Ixx2P5eU4RYM7qUHGHujNw",
    "http": "POST",
    "features": "B"
  },
  "TrustedFriendsListQueryById": {
    "endpoint": "trusted_friends_list_query_by_id",
    "operation": "TrustedFriendsListQueryById",
    "queryId": "-FGFGdlNiYhqsFQ5btxmuA",
    "http": "GET",
    "features": ""
  },
  "TrustedFriendsListQueryRecommendedMembersByRestId": {
    "endpoint": "trusted_friends_list_query_recommended_members_by_rest_id",
    "operation": "TrustedFriendsListQueryRecommendedMembersByRestId",
    "queryId": "MOB-Il1nCZ3Q6RXqLJx1Kw",
    "http": "GET",
    "features": "B"
  },
  "TweetConversationControlDelete": {
    "endpoint": "tweet_conversation_control_delete",
    "operation": "TweetConversationControlDelete",
    "queryId": "IkdET3_iUY5aPtz7Xn-8rA",
    "http": "POST",
    "features": ""
  },
  "TweetConversationControlPut": {
    "endpoint": "tweet_conversation_control_put",
    "operation": "TweetConversationControlPut",
    "queryId": "DL0R5KGQ3SvA-ziP-MQl6A",
    "http": "POST",
    "features": ""
  },
  "TweetDetail": {
    "endpoint": "tweet_detail",
    "operation": "TweetDetail",
    "queryId": "6uCvnic3m5reVuehkvHa3w",
    "http": "GET",
    "features": "C"
  },
  "TweetModerateUpdate": {
    "endpoint": "tweet_moderate_update",
    "operation": "TweetModerateUpdate",
    "queryId": "slVYoY_EHR7YDRpto6hlQg",
    "http": "POST",
    "features": ""
  },
  "TweetResultByIdQuery": {
    "endpoint": "tweet_result_by_id_query",
    "operation": "TweetResultByIdQuery",
    "queryId": "rtNVfIklvKnpQJgSCudXkQ",
    "http": "GET",
    "features": "A"
  },
  "TweetResultsByIdsQuery": {
    "endpoint": "tweet_results_by_ids_query",
    "operation": "TweetResultsByIdsQuery",
    "queryId": "y2q0dRZQxID7nnIcCIE3sg",
    "http": "GET",
    "features": "A"
  },
  "TweetUnmoderateUpdate": {
    "endpoint": "tweet_unmoderate_update",
    "operation": "TweetUnmoderateUpdate",
    "queryId": "s_Lg336W54DW08H5GDG8cA",
    "http": "POST",
    "features": ""
  },
  "TypeaheadXChatQuery": {
    "endpoint": "",
    "operation": "TypeaheadXChatQuery",
    "queryId": "I4OSnuMmvD5x-N8PfpDDyA",
    "http": "POST",
    "features": ""
  },
  "UnfavoriteTweet": {
    "endpoint": "unfavorite_tweet",
    "operation": "UnfavoriteTweet",
    "queryId": "ZYKSe-w7KEslx3JhSIk5LA",
    "http": "POST",
    "features": ""
  },
  "UnmentionUser": {
    "endpoint": "unmention_user",
    "operation": "UnmentionUser",
    "queryId": "OliKoDxqcnL653lUPIeruw",
    "http": "POST",
    "features": ""
  },
  "UnmuteConversationMutation": {
    "endpoint": "",
    "operation": "UnmuteConversationMutation",
    "queryId": "_f8wd8RlQCCysv8yMKeiaw",
    "http": "POST",
    "features": ""
  },
  "UnpinTimeline": {
    "endpoint": "unpin_timeline",
    "operation": "UnpinTimeline",
    "queryId": "gzhKuERhKEsooXFBcLDb8A",
    "http": "POST",
    "features": "B"
  },
  "UnpinTweet": {
    "endpoint": "unpin_tweet",
    "operation": "UnpinTweet",
    "queryId": "TtGd5umk9Cd_nMDQG7JBSw",
    "http": "POST",
    "features": ""
  },
  "UpdateConversationTTLMutation": {
    "endpoint": "",
    "operation": "UpdateConversationTTLMutation",
    "queryId": "Gu3kCEwNN2V-Az8NDk30Zg",
    "http": "POST",
    "features": ""
  },
  "UpdateDmSettingsMutation": {
    "endpoint": "",
    "operation": "UpdateDmSettingsMutation",
    "queryId": "mlBrJopw8TCKeVpaqb5AdQ",
    "http": "POST",
    "features": ""
  },
  "UpdateGroupAdminSettingsMutation": {
    "endpoint": "",
    "operation": "UpdateGroupAdminSettingsMutation",
    "queryId": "x5knO9L-5h-hoCX3dzkNIw",
    "http": "POST",
    "features": ""
  },
  "UpdatePinnedTimelines": {
    "endpoint": "update_pinned_timelines",
    "operation": "UpdatePinnedTimelines",
    "queryId": "Ia57eakdNOqtfr8Ul7-FCQ",
    "http": "POST",
    "features": "B"
  },
  "UpdateTweetVoiceInfo": {
    "endpoint": "update_tweet_voice_info",
    "operation": "UpdateTweetVoiceInfo",
    "queryId": "ypmjbNda88Co1H-2Denpyw",
    "http": "POST",
    "features": ""
  },
  "UpdateXChatUserRealmStateMutation": {
    "endpoint": "",
    "operation": "UpdateXChatUserRealmStateMutation",
    "queryId": "B4iU-NL0I05KoyZzh9E2sw",
    "http": "POST",
    "features": ""
  },
  "UserAboutTimelineQuery": {
    "endpoint": "user_about_timeline_query",
    "operation": "UserAboutTimelineQuery",
    "queryId": "kbZS5ZH3Sex8Z2E35bOFrg",
    "http": "GET",
    "features": "A"
  },
  "UserAffiliatedUsers": {
    "endpoint": "user_affiliated_users",
    "operation": "UserAffiliatedUsers",
    "queryId": "fluvXY3yJTKutMsYW_kEtQ",
    "http": "GET",
    "features": "A"
  },
  "UserAvCallSettingsPut": {
    "endpoint": "user_av_call_settings_put",
    "operation": "UserAvCallSettingsPut",
    "queryId": "umUeiLvtyldLVdCAzDO27g",
    "http": "POST",
    "features": ""
  },
  "UserByRestId": {
    "endpoint": "user_by_rest_id",
    "operation": "UserByRestId",
    "queryId": "QdS5LJDl99iL_KUzckdfNQ",
    "http": "GET",
    "features": [
      "hidden_profile_likes_enabled",
      "hidden_profile_subscriptions_enabled",
      "profile_label_improvements_pcf_label_in_post_enabled",
      "verified_phone_label_enabled",
      "highlights_tweets_tab_ui_enabled",
      "responsive_web_twitter_article_notes_tab_enabled",
      "creator_subscriptions_tweet_preview_api_enabled",
      "responsive_web_graphql_exclude_directive_enabled",
      "responsive_web_graphql_timeline_navigation_enabled",
      "responsive_web_graphql_skip_user_profile_image_extensions_enabled"
    ]
  },
  "UserByScreenName": {
    "endpoint": "user_by_screen_name",
    "operation": "UserByScreenName",
    "queryId": "IGgvgiOx4QZndDHuD3x9TQ",
    "http": "GET",
    "features": [
      "hidden_profile_subscriptions_enabled",
      "profile_label_improvements_pcf_label_in_post_enabled",
      "responsive_web_profile_redirect_enabled",
      "rweb_tipjar_consumption_enabled",
      "verified_phone_label_enabled",
      "subscriptions_verification_info_is_identity_verified_enabled",
      "subscriptions_verification_info_verified_since_enabled",
      "highlights_tweets_tab_ui_enabled",
      "responsive_web_twitter_article_notes_tab_enabled",
      "subscriptions_feature_can_gift_premium",
      "creator_subscriptions_tweet_preview_api_enabled",
      "responsive_web_graphql_skip_user_profile_image_extensions_enabled",
      "responsive_web_graphql_timeline_navigation_enabled"
    ]
  },
  "UserCommunityInviteMutation": {
    "endpoint": "user_community_invite_mutation",
    "operation": "UserCommunityInviteMutation",
    "queryId": "DSbmt8ctjvcG7EqJKqQ25Q",
    "http": "POST",
    "features": "B"
  },
  "UserCreateAboutModuleFromVenue": {
    "endpoint": "user_create_about_module_from_venue",
    "operation": "UserCreateAboutModuleFromVenue",
    "queryId": "_mseS6R1pjYdYMGNmub-bw",
    "http": "POST",
    "features": "B"
  },
  "UserCreateAppModule": {
    "endpoint": "user_create_app_module",
    "operation": "UserCreateAppModule",
    "queryId": "Ob3WXKB4F1cjr-zHJnHW1w",
    "http": "POST",
    "features": "B"
  },
  "UserCreateCommunitiesModuleMutation": {
    "endpoint": "user_create_communities_module_mutation",
    "operation": "UserCreateCommunitiesModuleMutation",
    "queryId": "fSpw5Izp8EtEhIbrrEel1w",
    "http": "POST",
    "features": "B"
  },
  "UserCreateLinkModule": {
    "endpoint": "user_create_link_module",
    "operation": "UserCreateLinkModule",
    "queryId": "W3KSmCM22RPst81ZBRKYjA",
    "http": "POST",
    "features": "B"
  },
  "UserDeleteAboutModuleAndVenue": {
    "endpoint": "user_delete_about_module_and_venue",
    "operation": "UserDeleteAboutModuleAndVenue",
    "queryId": "75bdkdTykLMX9nXD52uoHw",
    "http": "POST",
    "features": "B"
  },
  "UserDeleteAppModule": {
    "endpoint": "user_delete_app_module",
    "operation": "UserDeleteAppModule",
    "queryId": "E7LrRvILgHl_z9-xGY9kJw",
    "http": "POST",
    "features": "B"
  },
  "UserDeleteCommunitiesModuleMutation": {
    "endpoint": "user_delete_communities_module_mutation",
    "operation": "UserDeleteCommunitiesModuleMutation",
    "queryId": "oidlSSrrOQf2yVA8KAR2bw",
    "http": "POST",
    "features": "B"
  },
  "UserDeleteLinkModule": {
    "endpoint": "user_delete_link_module",
    "operation": "UserDeleteLinkModule",
    "queryId": "LzcStkGMhPS2vHf6sO532Q",
    "http": "POST",
    "features": "B"
  },
  "UserDmNsfwFilterSettingsUpdate": {
    "endpoint": "user_dm_nsfw_filter_settings_update",
    "operation": "UserDmNsfwFilterSettingsUpdate",
    "queryId": "Zx2AzSs6KfU15AkXxpa0YQ",
    "http": "POST",
    "features": ""
  },
  "UserEditableProfileModulesQuery": {
    "endpoint": "user_editable_profile_modules_query",
    "operation": "UserEditableProfileModulesQuery",
    "queryId": "VEob2BUpEy0R7YCS0EftSA",
    "http": "GET",
    "features": "B"
  },
  "UserEmailNotificationsSettingsUpdate": {
    "endpoint": "user_email_notifications_settings_update",
    "operation": "UserEmailNotificationsSettingsUpdate",
    "queryId": "G_1gf5jOsfFLCIYu0bPiig",
    "http": "POST",
    "features": ""
  },
  "UserFollowersTimelineQuery": {
    "endpoint": "user_followers_timeline_query",
    "operation": "UserFollowersTimelineQuery",
    "queryId": "XMLXqm9EMMVO1w71XJWeCQ",
    "http": "GET",
    "features": "A"
  },
  "UserFollowingTimelineQuery": {
    "endpoint": "user_following_timeline_query",
    "operation": "UserFollowingTimelineQuery",
    "queryId": "bNPayvtkxorTHM4JGod1lw",
    "http": "GET",
    "features": "A"
  },
  "UserFriendsFollowingTimelineQuery": {
    "endpoint": "user_friends_following_timeline_query",
    "operation": "UserFriendsFollowingTimelineQuery",
    "queryId": "I4VgTq0DHf01VqcR4D8-Bg",
    "http": "GET",
    "features": "A"
  },
  "UserIncomingFriendshipsTimelineQuery": {
    "endpoint": "user_incoming_friendships_timeline_query",
    "operation": "UserIncomingFriendshipsTimelineQuery",
    "queryId": "bGaAXthJZhzdN2NnfYIvUw",
    "http": "GET",
    "features": "A"
  },
  "UserListMute": {
    "endpoint": "user_list_mute",
    "operation": "UserListMute",
    "queryId": "706Hnj2UKNqAJOZJXT0ZqQ",
    "http": "POST",
    "features": ""
  },
  "UserListSubscribe": {
    "endpoint": "user_list_subscribe",
    "operation": "UserListSubscribe",
    "queryId": "uKER2Ur0iQTVXkqUEUg-Kg",
    "http": "POST",
    "features": "B"
  },
  "UserListUnmute": {
    "endpoint": "user_list_unmute",
    "operation": "UserListUnmute",
    "queryId": "bS5Ku2wVQGyKU2rhr_B8fg",
    "http": "POST",
    "features": ""
  },
  "UserListUnsubscribe": {
    "endpoint": "user_list_unsubscribe",
    "operation": "UserListUnsubscribe",
    "queryId": "MFR5-RSk4A5F6zDoJ-FDEw",
    "http": "POST",
    "features": "B"
  },
  "UserPreferencesGet": {
    "endpoint": "user_preferences_get",
    "operation": "UserPreferencesGet",
    "queryId": "UIjeD7AZKF-P4hfT2EONQg",
    "http": "GET",
    "features": ""
  },
  "UserPreferencesGrokDeleteData": {
    "endpoint": "user_preferences_grok_delete_data",
    "operation": "UserPreferencesGrokDeleteData",
    "queryId": "28CM05OHbQfDWO4b1n90sg",
    "http": "POST",
    "features": ""
  },
  "UserPreferencesUpdateAllowForYouRecommendations": {
    "endpoint": "user_preferences_update_allow_for_you_recommendations",
    "operation": "UserPreferencesUpdateAllowForYouRecommendations",
    "queryId": "uJ0iXR1R-jxu9CzKXXQjEQ",
    "http": "POST",
    "features": ""
  },
  "UserPreferencesUpdateAllowGamblingAds": {
    "endpoint": "user_preferences_update_allow_gambling_ads",
    "operation": "UserPreferencesUpdateAllowGamblingAds",
    "queryId": "yx6aK4P8kSffBXm-dbq70A",
    "http": "POST",
    "features": ""
  },
  "UserPreferencesUpdateAllowVideoDownloads": {
    "endpoint": "user_preferences_update_allow_video_downloads",
    "operation": "UserPreferencesUpdateAllowVideoDownloads",
    "queryId": "srtPWSpugzh1H1YdXtuofg",
    "http": "POST",
    "features": ""
  },
  "UserPreferencesUpdateGrokDataSharing": {
    "endpoint": "user_preferences_update_grok_data_sharing",
    "operation": "UserPreferencesUpdateGrokDataSharing",
    "queryId": "NMSYSeV5KQobnorDwPFvtQ",
    "http": "POST",
    "features": ""
  },
  "UserPreferencesUpdateGrokMemory": {
    "endpoint": "user_preferences_update_grok_memory",
    "operation": "UserPreferencesUpdateGrokMemory",
    "queryId": "9D0ZHGY-DNs7-SBWCiWJNQ",
    "http": "POST",
    "features": ""
  },
  "UserPreferencesUpdateGrokPersonalization": {
    "endpoint": "user_preferences_update_grok_personalization",
    "operation": "UserPreferencesUpdateGrokPersonalization",
    "queryId": "d8Dsepig7V9mmKuIY2g21Q",
    "http": "POST",
    "features": ""
  },
  "UserPreferencesUpdateHideSubscriptions": {
    "endpoint": "user_preferences_update_hide_subscriptions",
    "operation": "UserPreferencesUpdateHideSubscriptions",
    "queryId": "ltjtmRyBlAwQosK-3NdjBQ",
    "http": "POST",
    "features": ""
  },
  "UserPreferencesUpdateInferredLocationResolutionPreference": {
    "endpoint": "user_preferences_update_inferred_location_resolution_preference",
    "operation": "UserPreferencesUpdateInferredLocationResolutionPreference",
    "queryId": "ZIiHWIz5tOMpZe-M958Muw",
    "http": "POST",
    "features": ""
  },
  "UserProfileAffiliatesTimelineQuery": {
    "endpoint": "",
    "operation": "UserProfileAffiliatesTimelineQuery",
    "queryId": "ogxBnBB3jELw56w17Ipa2w",
    "http": "POST",
    "features": ""
  },
  "UserProfileArticlesTimelineQuery": {
    "endpoint": "user_profile_articles_timeline_query",
    "operation": "UserProfileArticlesTimelineQuery",
    "queryId": "VUJhHsUKgD7kxd0pTb571w",
    "http": "GET",
    "features": "A"
  },
  "UserProfileFavoritesTimelineQuery": {
    "endpoint": "",
    "operation": "UserProfileFavoritesTimelineQuery",
    "queryId": "kFeudmJpk2bQTQywiX4Vmg",
    "http": "POST",
    "features": ""
  },
  "UserProfileHighlightsTimelineQuery": {
    "endpoint": "",
    "operation": "UserProfileHighlightsTimelineQuery",
    "queryId": "SwHnWu94kNf3hy71-GHhRg",
    "http": "POST",
    "features": ""
  },
  "UserProfileMediaTimelineQuery": {
    "endpoint": "",
    "operation": "UserProfileMediaTimelineQuery",
    "queryId": "ytVpKmE_goUL4z2YYgxkwg",
    "http": "POST",
    "features": ""
  },
  "UserProfileModulesQuery": {
    "endpoint": "user_profile_modules_query",
    "operation": "UserProfileModulesQuery",
    "queryId": "Pj60UkDRUFuQINySSdD-LQ",
    "http": "GET",
    "features": "B"
  },
  "UserProfileNewRepliesTimelineQuery": {
    "endpoint": "",
    "operation": "UserProfileNewRepliesTimelineQuery",
    "queryId": "Zuvnsyj31KUN49sddxrhSw",
    "http": "POST",
    "features": ""
  },
  "UserProfileOriginalsTimelineQuery": {
    "endpoint": "",
    "operation": "UserProfileOriginalsTimelineQuery",
    "queryId": "OpZFUTVdtRb_xLXfbqb6iw",
    "http": "POST",
    "features": ""
  },
  "UserProfileRepliesTimelineQuery": {
    "endpoint": "",
    "operation": "UserProfileRepliesTimelineQuery",
    "queryId": "PSBOqDra02L8mrBmnzklJQ",
    "http": "POST",
    "features": ""
  },
  "UserProfileRepostsTimelineQuery": {
    "endpoint": "user_profile_reposts_timeline_query",
    "operation": "UserProfileRepostsTimelineQuery",
    "queryId": "5Gp4Cy4U13LBpmTBYnwCig",
    "http": "GET",
    "features": [
      "android_home_timeline_status_injections_facepile_enabled",
      "grok_translations_post_auto_translation_is_enabled",
      "reply_dislike_android_enabled",
      "x_lite_quick_promote_analytics_banner_enabled"
    ]
  },
  "UserProfileSuperFollowersTimelineQuery": {
    "endpoint": "",
    "operation": "UserProfileSuperFollowersTimelineQuery",
    "queryId": "i-pglBDHoe-SdQil6tyVQA",
    "http": "POST",
    "features": ""
  },
  "UserResultByIdQuery": {
    "endpoint": "user_result_by_id_query",
    "operation": "UserResultByIdQuery",
    "queryId": "-DAaa9jPxPswYeI2fZ9rug",
    "http": "GET",
    "features": "B"
  },
  "UserResultByScreenNameQuery": {
    "endpoint": "user_result_by_screen_name_query",
    "operation": "UserResultByScreenNameQuery",
    "queryId": "-ZzAG_Bckx16LMbEvHC3lg",
    "http": "GET",
    "features": "B"
  },
  "UserSharingListeningDataWithFollowersSettingsUpdate": {
    "endpoint": "user_sharing_listening_data_with_followers_settings_update",
    "operation": "UserSharingListeningDataWithFollowersSettingsUpdate",
    "queryId": "znFz69bnfZ3GA86FMkAM8w",
    "http": "POST",
    "features": ""
  },
  "UserSuperFollowersTimelineQuery": {
    "endpoint": "user_super_followers_timeline_query",
    "operation": "UserSuperFollowersTimelineQuery",
    "queryId": "DX9jUPO9exxy0aqBIHVvug",
    "http": "GET",
    "features": "A"
  },
  "UserTweetsAndReplies": {
    "endpoint": "profile_tweets_and_replies_query",
    "operation": "UserTweetsAndReplies",
    "queryId": "EqtpEwt0CoQXmDfq5DKH0A",
    "http": "GET",
    "features": "C"
  },
  "UserUpdateAboutModuleFromVenue": {
    "endpoint": "user_update_about_module_from_venue",
    "operation": "UserUpdateAboutModuleFromVenue",
    "queryId": "hhb6N8z6qwrqxrRCzN3yyA",
    "http": "POST",
    "features": "B"
  },
  "UserUpdateAppModule": {
    "endpoint": "user_update_app_module",
    "operation": "UserUpdateAppModule",
    "queryId": "WnB2cARj2tJGXl9D5ZVnPg",
    "http": "POST",
    "features": "B"
  },
  "UserUpdateCommunitiesModuleMutation": {
    "endpoint": "user_update_communities_module_mutation",
    "operation": "UserUpdateCommunitiesModuleMutation",
    "queryId": "3jh0bCSsMLKkAP3Xi5Uerg",
    "http": "POST",
    "features": "B"
  },
  "UserUpdateLinkModule": {
    "endpoint": "user_update_link_module",
    "operation": "UserUpdateLinkModule",
    "queryId": "RQUkzX3oNZA6YuW8tKYr6g",
    "http": "POST",
    "features": "B"
  },
  "UserUpdateModuleVisibility": {
    "endpoint": "user_update_module_visibility",
    "operation": "UserUpdateModuleVisibility",
    "queryId": "7ZTYrhErufhdk2-it4APUg",
    "http": "POST",
    "features": "B"
  },
  "UserUpdateProfessionalCategoryDisplay": {
    "endpoint": "user_update_professional_category_display",
    "operation": "UserUpdateProfessionalCategoryDisplay",
    "queryId": "Wxve9Btx3tHIwkAdF1vZ0A",
    "http": "POST",
    "features": "B"
  },
  "UserVerifiedReasonQuery": {
    "endpoint": "user_verified_reason_query",
    "operation": "UserVerifiedReasonQuery",
    "queryId": "zRXYMcGAF6LiKr7dow6CVQ",
    "http": "GET",
    "features": ""
  },
  "UserVitFollowersTimelineQuery": {
    "endpoint": "user_vit_followers_timeline_query",
    "operation": "UserVitFollowersTimelineQuery",
    "queryId": "D6gamO3p6hNhYPacLmHKWA",
    "http": "GET",
    "features": "A"
  },
  "UserWithProfileHighlightsTimelineQuery": {
    "endpoint": "user_with_profile_highlights_timeline_query",
    "operation": "UserWithProfileHighlightsTimelineQuery",
    "queryId": "O4NgjliT3TF-GTEra4Nr3g",
    "http": "GET",
    "features": "A"
  },
  "UserWithProfileReplyDeviceFollow": {
    "endpoint": "user_with_profile_reply_device_follow",
    "operation": "UserWithProfileReplyDeviceFollow",
    "queryId": "0iCEMO6QzSVi3CUZjvuiBA",
    "http": "POST",
    "features": ""
  },
  "UserWithProfileReplyDeviceUnfollow": {
    "endpoint": "user_with_profile_reply_device_unfollow",
    "operation": "UserWithProfileReplyDeviceUnfollow",
    "queryId": "qQrGirsSX8f-CVBT8-Ue3Q",
    "http": "POST",
    "features": ""
  },
  "UserWithProfileSuperFollowTweetsQuery": {
    "endpoint": "user_with_profile_super_follow_tweets_query",
    "operation": "UserWithProfileSuperFollowTweetsQuery",
    "queryId": "1viCRDLHXmw-rPwwZeS3eg",
    "http": "GET",
    "features": "A"
  },
  "UserWithProfileTweetsAndRepliesQueryV2": {
    "endpoint": "user_with_profile_tweets_and_replies_query_v2",
    "operation": "UserWithProfileTweetsAndRepliesQueryV2",
    "queryId": "AcYHjc_YAx-9_rKWdMsKvA",
    "http": "GET",
    "features": "A"
  },
  "UserWithProfileTweetsQueryV2": {
    "endpoint": "user_with_profile_tweets_query_v2",
    "operation": "UserWithProfileTweetsQueryV2",
    "queryId": "B2UkbYOGwyE4DX_2WNIySw",
    "http": "GET",
    "features": "A"
  },
  "UserWithRitoActionedTweetsTimelineQuery": {
    "endpoint": "user_with_rito_actioned_tweets_timeline_query",
    "operation": "UserWithRitoActionedTweetsTimelineQuery",
    "queryId": "WG9NCVqjVUQkLabIgEWzMQ",
    "http": "GET",
    "features": "A"
  },
  "UserWithRitoFlaggedTweetsTimelineQuery": {
    "endpoint": "user_with_rito_flagged_tweets_timeline_query",
    "operation": "UserWithRitoFlaggedTweetsTimelineQuery",
    "queryId": "B7HIMpjzPGE4dsqDy5N5LQ",
    "http": "GET",
    "features": "A"
  },
  "ViewerBlockingTimeline": {
    "endpoint": "",
    "operation": "ViewerBlockingTimeline",
    "queryId": "U07TB8xYtl9DsThafdimbA",
    "http": "POST",
    "features": ""
  },
  "ViewerBlockingTimelineQuery": {
    "endpoint": "viewer_blocking_timeline_query",
    "operation": "ViewerBlockingTimelineQuery",
    "queryId": "MQhlNOS3gxEAUAtzgAWz7w",
    "http": "GET",
    "features": "A"
  },
  "ViewerChannelsDiscoveryTimelineQuery": {
    "endpoint": "viewer_channels_discovery_timeline_query",
    "operation": "ViewerChannelsDiscoveryTimelineQuery",
    "queryId": "PG9fEJDJg1_dy7W3F5yk3A",
    "http": "GET",
    "features": "A"
  },
  "ViewerFlaggedAccountsTimelineQuery": {
    "endpoint": "viewer_flagged_accounts_timeline_query",
    "operation": "ViewerFlaggedAccountsTimelineQuery",
    "queryId": "4PCekDmhLepadVT9-HdELQ",
    "http": "GET",
    "features": "A"
  },
  "ViewerImportedBlockingTimelineQuery": {
    "endpoint": "viewer_imported_blocking_timeline_query",
    "operation": "ViewerImportedBlockingTimelineQuery",
    "queryId": "myQFy3Y8lbe9hlPUQHta1w",
    "http": "GET",
    "features": "A"
  },
  "ViewerListManagementTimeline": {
    "endpoint": "viewer_list_management_timeline",
    "operation": "ViewerListManagementTimeline",
    "queryId": "xJ_-IOX85VVK5-DwsfoZ4A",
    "http": "GET",
    "features": "A"
  },
  "ViewerMutingTimeline": {
    "endpoint": "",
    "operation": "ViewerMutingTimeline",
    "queryId": "n0wKN-YgJnLQIRb9m5Xwzw",
    "http": "POST",
    "features": ""
  },
  "ViewerMutingTimelineQuery": {
    "endpoint": "viewer_muting_timeline_query",
    "operation": "ViewerMutingTimelineQuery",
    "queryId": "_zWu96VQwhY6TgNEepteRQ",
    "http": "GET",
    "features": "A"
  },
  "ViewerSmartBlockingTimelineQuery": {
    "endpoint": "viewer_smart_blocking_timeline_query",
    "operation": "ViewerSmartBlockingTimelineQuery",
    "queryId": "Ui6pSpwJEqjT82QjYZ7yuQ",
    "http": "GET",
    "features": "A"
  },
  "ViewerUrtFixtureQuery": {
    "endpoint": "viewer_urt_fixture_query",
    "operation": "ViewerUrtFixtureQuery",
    "queryId": "ss7aBtvi95rgEpV8Jn_aPA",
    "http": "GET",
    "features": "A"
  },
  "ViewerUserQuery": {
    "endpoint": "viewer_user_query",
    "operation": "ViewerUserQuery",
    "queryId": "_ccRJ_8nuJ1-RzBDtk-9Xg",
    "http": "GET",
    "features": "B"
  },
  "XChatAcceptEnrollmentMutation": {
    "endpoint": "",
    "operation": "XChatAcceptEnrollmentMutation",
    "queryId": "3OqnkNBoD_u-WQ3vYF3MwA",
    "http": "POST",
    "features": ""
  },
  "XChatCompleteEnrollmentMutation": {
    "endpoint": "",
    "operation": "XChatCompleteEnrollmentMutation",
    "queryId": "_z_jittTpDl2zvg2e_iI4w",
    "http": "POST",
    "features": ""
  },
  "XChatCreateEnrollmentSessionMutation": {
    "endpoint": "",
    "operation": "XChatCreateEnrollmentSessionMutation",
    "queryId": "sAkeiiKaXEGVI7X2zuADqg",
    "http": "POST",
    "features": ""
  },
  "XChatDenyEnrollmentMutation": {
    "endpoint": "",
    "operation": "XChatDenyEnrollmentMutation",
    "queryId": "7WqlOYn720k4XH8f3-_8Xw",
    "http": "POST",
    "features": ""
  },
  "XChatGetEnrollmentSessionMutation": {
    "endpoint": "",
    "operation": "XChatGetEnrollmentSessionMutation",
    "queryId": "KOvF0kG8ItHUyG0LRcKZWg",
    "http": "POST",
    "features": ""
  },
  "XChatGrokSearchPageQuery": {
    "endpoint": "",
    "operation": "XChatGrokSearchPageQuery",
    "queryId": "fViyRu-_mQfM3rS0ZvRxFQ",
    "http": "POST",
    "features": ""
  },
  "XChatInitiatePasscodeRetrievalMutation": {
    "endpoint": "",
    "operation": "XChatInitiatePasscodeRetrievalMutation",
    "queryId": "nTsYB72LJ1it6qlLt0EexQ",
    "http": "POST",
    "features": ""
  },
  "XChatSendEnrollmentEncryptedKeysMutation": {
    "endpoint": "",
    "operation": "XChatSendEnrollmentEncryptedKeysMutation",
    "queryId": "nXbEKrcM_Gq5Q0fx0U3JBw",
    "http": "POST",
    "features": ""
  },
  "XChatSendEnrollmentPublicKeyMutation": {
    "endpoint": "",
    "operation": "XChatSendEnrollmentPublicKeyMutation",
    "queryId": "aS0916UCJ9VUkwucQoUYow",
    "http": "POST",
    "features": ""
  },
  "XChatSendGrokMessagePlaintextMutation": {
    "endpoint": "",
    "operation": "XChatSendGrokMessagePlaintextMutation",
    "queryId": "qm71_NDegIBh5UY73hBXaQ",
    "http": "POST",
    "features": ""
  }
});

export const OPERATION_COUNT = 396;

export function findOperation(nameOrEndpoint) {
  if (!nameOrEndpoint) {
    return undefined;
  }
  const key = String(nameOrEndpoint);
  return OPERATIONS_BY_NAME[key] ?? OPERATIONS_BY_ENDPOINT[key];
}
