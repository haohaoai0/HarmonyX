import { ComposerOptions, ComposerPlace, ComposerScheduledPost } from '../models/ComposerOptions';

export function composerV2Fields(payload: Record<string, Object>, options: ComposerOptions): void {
  if (options.needsWebSession()) { throw new Error('composer_option_requires_web_session'); }
  if (options.pollChoices.length > 0) {
    const poll: Record<string, Object> = { 'options': options.pollChoices.map((choice: string): string => choice.trim()),
      'duration_minutes': options.pollDurationMinutes };
    payload['poll'] = poll;
  }
  const mode: string = options.replyMode === 'Community' ? 'following' :
    options.replyMode === 'ByInvitation' ? 'mentionedUsers' : options.replyMode === 'Verified' ? 'verified' : '';
  if (mode.length > 0) { payload['reply_settings'] = mode; }
  if (options.placeId.length > 0) {
    const geo: Record<string, string> = { 'place_id': options.placeId };
    payload['geo'] = geo;
  }
  if (options.paidPartnership) { payload['paid_partnership'] = true; }
  if (options.madeWithAi) { payload['made_with_ai'] = true; }
}

export function composerPrivateFields(payload: Record<string, Object>, options: ComposerOptions,
  cardUri: string): void {
  if (cardUri.length > 0) { payload['card_uri'] = cardUri; }
  if (options.replyMode.length > 0) {
    const control: Record<string, string> = { 'mode': options.replyMode };
    payload['conversation_control'] = control;
  }
  if (options.placeId.length > 0) {
    const geo: Record<string, string> = { 'place_id': options.placeId };
    if (options.geoSearchRequestId.length > 0) { geo['geo_search_request_id'] = options.geoSearchRequestId; }
    payload['geo'] = geo;
  }
  if (options.paidPartnership || options.madeWithAi) {
    const disclosure: Record<string, Object> = {};
    if (options.paidPartnership) {
      const advertising: Record<string, boolean> = { 'is_paid_promotion': true };
      disclosure['advertising_disclosure'] = advertising;
    }
    if (options.madeWithAi) {
      const ai: Record<string, Object> = { 'has_ai_generated_media': true,
        'ai_generated_detection_source': 'UserDeclared' };
      disclosure['ai_generated_disclosure'] = ai;
    }
    payload['content_disclosure'] = disclosure;
  }
}

export function composerPollCard(options: ComposerOptions, imageIds: string[] = []): Record<string, Object> {
  const hasImages: boolean = imageIds.some((id: string): boolean => id.length > 0);
  const card: Record<string, Object> = { 'twitter:card': hasImages ? '1906814671912599552:poll_choice_images' :
    'poll' + options.pollChoices.length.toString() + 'choice_text_only',
    'twitter:api:api:endpoint': '1', 'twitter:long:duration_minutes': options.pollDurationMinutes };
  for (let i: number = 0; i < options.pollChoices.length; i++) {
    card['twitter:string:choice' + (i + 1).toString() + '_label'] = options.pollChoices[i].trim();
    if (i < imageIds.length && imageIds[i].length > 0) {
      card['twitter:image:choice' + (i + 1).toString() + '_image:src:id'] = 'mis://' + imageIds[i];
    }
  }
  return card;
}

export function composerScheduleVariables(text: string, replyId: string, mediaIds: string[],
  executeAt: number, options: ComposerOptions = new ComposerOptions()): Record<string, Object> {
  const request: Record<string, Object> = { 'auto_populate_reply_metadata': replyId.length > 0,
    'status': text, 'exclude_reply_user_ids': [], 'media_ids': mediaIds };
  if (replyId.length > 0) { request['in_reply_to_status_id'] = replyId; }
  if (options.paidPartnership || options.madeWithAi) {
    const fields: Record<string, Object> = {};
    composerPrivateFields(fields, options, '');
    request['content_disclosure_options'] = fields['content_disclosure'];
  }
  return { 'post_tweet_request': request, 'execute_at': Math.floor(executeAt / 1000) };
}

export function composerPlaces(body: string): ComposerPlace[] {
  try {
    const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
    const result: Record<string, Object> = (root['result'] ?? root) as Record<string, Object>;
    const rows: ComposerPlace[] = (result['places'] ?? []) as ComposerPlace[];
    return rows.filter((place: ComposerPlace): boolean => typeof place.id === 'string' && place.id.length > 0)
      .map((place: ComposerPlace): ComposerPlace => ({ id: place.id, name: place.name ?? '',
        full_name: place.full_name ?? place.name ?? '', country: place.country ?? '',
        geoSearchRequestId: String(result['geo_search_request_id'] ?? '') }));
  } catch (error) { return []; }
}

export function composerScheduledPosts(body: string): ComposerScheduledPost[] {
  const posts: ComposerScheduledPost[] = [];
  try {
    const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
    const data: Record<string, Object> = (root['data'] ?? {}) as Record<string, Object>;
    const viewer: Record<string, Object> = (data['viewer'] ?? {}) as Record<string, Object>;
    const list: Array<Record<string, Object>> = (viewer['scheduled_tweet_list'] ?? []) as Array<Record<string, Object>>;
    for (let i: number = 0; i < list.length; i++) {
      const row: Record<string, Object> = list[i];
      const id: string = String(row['rest_id'] ?? '');
      const request: Record<string, Object> = (row['tweet_create_request'] ?? {}) as Record<string, Object>;
      const scheduling: Record<string, Object> = (row['scheduling_info'] ?? {}) as Record<string, Object>;
      const text: string = String(request['text'] ?? request['status'] ?? '');
      const executeAt: number = Number(scheduling['execute_at'] ?? 0) * 1000;
      if (/^\d+$/.test(id) && Number.isFinite(executeAt) && executeAt > 0) {
        posts.push({ id: id, text: text, executeAt: executeAt });
      }
    }
  } catch (error) {}
  return posts;
}
