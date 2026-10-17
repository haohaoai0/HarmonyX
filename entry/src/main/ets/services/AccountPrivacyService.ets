import { common } from '@kit.AbilityKit';
import {
  AccountPrivacySnapshot, XAccountPrivacySettings, XPrivacyEnvelope, XUserPrivacyPreferences,
  XLoginSession, XConnectedApplication, XBusinessCountryPreference, XAboutAccountPreferences
} from '../models/AccountPrivacy';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { mediaSettingsStore } from './MediaSettingsStore';

// No account privacy settings are cached. Missing/failed reads never become
// false switches. Each mutation is bound to the session that loaded the page,
// then confirmed by a fresh server read before the UI reports success.
export class AccountPrivacyService {
  private requireGeneration(generation: number): void {
    if (!xPrivateClient.isSignedIn()) { throw new Error('no_session'); }
    if (generation !== xPrivateClient.sessionGeneration()) { throw new Error('account_changed'); }
  }

  private requireResult(result: XPrivateResult, generation: number): void {
    this.requireGeneration(generation);
    if (!result.ok) { throw new Error('settings_http_' + result.status); }
  }

  needsRead(section: string): boolean {
    return ['audience', 'posts', 'content', 'ads', 'activity', 'partners', 'locations', 'cookies',
      'grok_privacy', 'about_account', 'replies', 'sessions', 'applications'].indexOf(section) >= 0;
  }

  private async readAccount(generation: number): Promise<XAccountPrivacySettings> {
    const result: XPrivateResult = await xPrivateClient.accountSettingsRest('GET', '/1.1/account/settings.json', {
      'include_mention_filter': 'true', 'include_nsfw_user_flag': 'true', 'include_nsfw_admin_flag': 'true',
      'include_ranked_timeline': 'true', 'include_alt_text_compose': 'true', 'include_country_code': 'true',
      'include_ext_dm_av_call_settings': 'true', 'include_ext_dm_nsfw_media_filter': 'true',
      'include_ext_sharing_audiospaces_listening_data_with_followers': 'true', 'ext': 'ssoConnections'
    });
    this.requireResult(result, generation);
    const settings: XAccountPrivacySettings = JSON.parse(result.body) as XAccountPrivacySettings;
    if (settings === null || (settings.protected === undefined && settings.display_sensitive_media === undefined)) {
      throw new Error('settings_unavailable');
    }
    return settings;
  }

  private async readPreferences(section: string, generation: number): Promise<XUserPrivacyPreferences> {
    let name: string = 'GrokSettingsScreenQuery';
    let variables: Record<string, Object | null> = {};
    if (section === 'audience') { name = 'AudienceAndTaggingQuery'; }
    if (section === 'about_account') {
      name = 'UserPreferencesQuery';
      variables = { 'about_this_account_user_preferences': true, 'allow_for_you_recommendations': true,
        'inferred_location_resolution_preference': true };
    }
    const result: XPrivateResult = await xPrivateClient.accountSettingsGraphql(name, variables);
    this.requireResult(result, generation);
    const preferences: XUserPrivacyPreferences | undefined =
      (JSON.parse(result.body) as XPrivacyEnvelope).data?.user_preferences;
    if (preferences === undefined || preferences === null) { throw new Error('settings_unavailable'); }
    return preferences;
  }

  async read(section: string): Promise<AccountPrivacySnapshot> {
    const snapshot: AccountPrivacySnapshot = new AccountPrivacySnapshot();
    snapshot.generation = xPrivateClient.sessionGeneration();
    if (!this.needsRead(section)) { return snapshot; }
    this.requireGeneration(snapshot.generation);
    const tasks: Promise<void>[] = [];
    if (['audience', 'posts', 'content', 'ads', 'activity', 'partners', 'locations', 'cookies'].indexOf(section) >= 0) {
      tasks.push(this.readAccount(snapshot.generation).then((settings: XAccountPrivacySettings): void => {
        snapshot.account = settings;
      }).catch((): void => { snapshot.incomplete = true; }));
    }
    if (['audience', 'grok_privacy', 'about_account'].indexOf(section) >= 0) {
      tasks.push(this.readPreferences(section, snapshot.generation).then((preferences: XUserPrivacyPreferences): void => {
        snapshot.preferences = preferences;
      }).catch((): void => { snapshot.incomplete = true; }));
    }
    if (section === 'replies') {
      tasks.push(xPrivateClient.accountSettingsGraphql('RepliesGetUserToxicReplyFilterSettingQuery', {})
        .then((result: XPrivateResult): void => {
          this.requireResult(result, snapshot.generation);
          const data: XPrivacyEnvelope = JSON.parse(result.body) as XPrivacyEnvelope;
          snapshot.replyFilter = data.data?.viewer?.user_results?.result?.toxic_reply_filter_setting?.enabled;
          if (typeof snapshot.replyFilter !== 'boolean') { throw new Error('settings_unavailable'); }
        }).catch((): void => { snapshot.incomplete = true; }));
    }
    if (section === 'sessions') {
      tasks.push(this.readSessions(snapshot.generation).then((sessions: XLoginSession[]): void => {
        snapshot.sessions = sessions;
      }));
    }
    if (section === 'applications') {
      tasks.push(this.readApplications(snapshot.generation).then((applications: XConnectedApplication[]): void => {
        snapshot.applications = applications;
      }));
    }
    await Promise.all(tasks);
    this.requireGeneration(snapshot.generation);
    return snapshot;
  }

  booleanValue(snapshot: AccountPrivacySnapshot, field: string): boolean | undefined {
    const account: XAccountPrivacySettings | null = snapshot.account;
    const preferences: XUserPrivacyPreferences | null = snapshot.preferences;
    let value: boolean | undefined = undefined;
    if (field === 'protected') { value = account?.protected; }
    else if (field === 'protected_videos') {
      value = typeof preferences?.allow_video_downloads === 'boolean' ? !preferences.allow_video_downloads : undefined;
    } else if (field === 'nsfw_user') { value = account?.nsfw_user; }
    else if (field === 'display_sensitive_media') { value = account?.display_sensitive_media; }
    else if (field === 'geo_enabled') { value = account?.geo_enabled; }
    else if (field === 'allow_ads_personalization') { value = account?.allow_ads_personalization; }
    else if (field === 'allow_logged_out_device_personalization') { value = account?.allow_logged_out_device_personalization; }
    else if (field === 'allow_location_history_personalization') { value = account?.allow_location_history_personalization; }
    else if (field === 'allow_sharing_data_for_third_party_personalization') { value = account?.allow_sharing_data_for_third_party_personalization; }
    else if (field === 'use_cookie_personalization') { value = account?.use_cookie_personalization; }
    else if (field === 'allow_xai_data_sharing') { value = preferences?.allow_xai_data_sharing; }
    else if (field === 'allow_xai_personalization') { value = preferences?.allow_xai_personalization; }
    else if (field === 'allow_grok_memory') { value = preferences?.allow_grok_memory; }
    else if (field === 'allow_for_you_recommendations') { value = preferences?.allow_for_you_recommendations; }
    else if (field === 'reply_filter') { value = snapshot.replyFilter; }
    return typeof value === 'boolean' ? value : undefined;
  }

  stringValue(snapshot: AccountPrivacySnapshot, field: string): string | undefined {
    if (field === 'allow_media_tagging') {
      const value: string | undefined = snapshot.account?.allow_media_tagging;
      return value !== undefined && ['all', 'following', 'none'].indexOf(value) >= 0 ? value : undefined;
    }
    if (field === 'inferred_location_resolution_preference') {
      const value: string | undefined = snapshot.preferences?.inferred_location_resolution_preference;
      return value === 'Country' || value === 'Region' ? value : undefined;
    }
    if (field === 'selected_business_country_code') {
      return snapshot.preferences?.about_this_account_user_preferences?.selected_business_country_code;
    }
    return undefined;
  }

  private async preferenceWrite(name: string, variables: Record<string, Object | null>,
    generation: number, reply: boolean = false): Promise<void> {
    const result: XPrivateResult = await xPrivateClient.accountSettingsGraphql(name, variables);
    this.requireResult(result, generation);
    const response: XPrivacyEnvelope = JSON.parse(result.body) as XPrivacyEnvelope;
    if ((reply ? response.data?.user_toxic_reply_filter_setting_put : response.data?.user_preferences_put) !== true) {
      throw new Error('settings_unconfirmed');
    }
  }

  async saveBoolean(section: string, field: string, value: boolean, generation: number): Promise<AccountPrivacySnapshot> {
    this.requireGeneration(generation);
    const before: AccountPrivacySnapshot = await this.read(section);
    this.requireGeneration(generation);
    if (this.booleanValue(before, field) === undefined || (field === 'nsfw_user' && before.account?.nsfw_admin === true)) {
      throw new Error('settings_unavailable');
    }
    if (this.booleanValue(before, field) === value) { return before; }
    if (field === 'protected_videos') {
      await this.preferenceWrite('AudienceAndTaggingAllowVideoDownloadsMutation', { 'isAllowed': !value }, generation);
    } else if (field === 'allow_xai_data_sharing') {
      await this.preferenceWrite('XaiDataSharingSettingsMutation', { 'allowXaiDataSharing': value }, generation);
    } else if (field === 'allow_xai_personalization') {
      await this.preferenceWrite('XaiPersonalizationSettingsMutation', { 'allowXaiPersonalization': value }, generation);
    } else if (field === 'allow_grok_memory') {
      await this.preferenceWrite('XaiMemoryMutation', { 'allow_grok_memory': value }, generation);
    } else if (field === 'allow_for_you_recommendations') {
      await this.preferenceWrite('UserPreferencesMutation', { 'allow_for_you_recommendations': value,
        'about_this_account_user_preferences': null, 'inferred_location_resolution_preference': null }, generation);
    } else if (field === 'reply_filter') {
      const userId: string = xPrivateClient.viewerId();
      if (userId.length === 0) { throw new Error('settings_unavailable'); }
      await this.preferenceWrite('useToggleToxicReplyFilterSettingMutation', { 'enabled': value, 'userId': userId }, generation, true);
    } else {
      const allowed: string[] = ['protected', 'nsfw_user', 'display_sensitive_media', 'geo_enabled',
        'allow_ads_personalization', 'allow_logged_out_device_personalization', 'allow_location_history_personalization',
        'allow_sharing_data_for_third_party_personalization', 'use_cookie_personalization'];
      if (allowed.indexOf(field) < 0) { throw new Error('settings_unavailable'); }
      const form: Record<string, string> = {};
      form[field] = value ? 'true' : 'false';
      this.requireResult(await xPrivateClient.accountSettingsRest('POST', '/1.1/account/settings.json', form), generation);
    }
    const confirmed: AccountPrivacySnapshot = await this.read(section);
    this.requireGeneration(generation);
    if (this.booleanValue(confirmed, field) !== value) { throw new Error('settings_unconfirmed'); }
    return confirmed;
  }

  async saveChoice(section: string, field: string, value: string, generation: number): Promise<AccountPrivacySnapshot> {
    this.requireGeneration(generation);
    const before: AccountPrivacySnapshot = await this.read(section);
    this.requireGeneration(generation);
    if (this.stringValue(before, field) === undefined) { throw new Error('settings_unavailable'); }
    if (field === 'allow_media_tagging') {
      if (['all', 'following', 'none'].indexOf(value) < 0) { throw new Error('invalid_choice'); }
      this.requireResult(await xPrivateClient.accountSettingsRest('POST', '/1.1/account/settings.json',
        { 'allow_media_tagging': value }), generation);
    } else if (field === 'inferred_location_resolution_preference') {
      if (value !== 'Country' && value !== 'Region') { throw new Error('invalid_choice'); }
      await this.preferenceWrite('UserPreferencesMutation', { 'inferred_location_resolution_preference': value,
        'about_this_account_user_preferences': null, 'allow_for_you_recommendations': null }, generation);
    } else if (field === 'selected_business_country_code') {
      const preferences: XBusinessCountryPreference[] =
        before.preferences?.about_this_account_user_preferences?.business_country_code_preferences ?? [];
      if (!preferences.some((preference: XBusinessCountryPreference): boolean => preference.country_code === value)) {
        throw new Error('invalid_choice');
      }
      const about: XAboutAccountPreferences = {
        business_country_code_preferences: preferences, selected_business_country_code: value
      };
      await this.preferenceWrite('UserPreferencesMutation', { 'about_this_account_user_preferences': about,
        'allow_for_you_recommendations': null, 'inferred_location_resolution_preference': null }, generation);
    } else { throw new Error('invalid_choice'); }
    const confirmed: AccountPrivacySnapshot = await this.read(section);
    this.requireGeneration(generation);
    if (this.stringValue(confirmed, field) !== value) { throw new Error('settings_unconfirmed'); }
    return confirmed;
  }

  private async readSessions(generation: number): Promise<XLoginSession[]> {
    const result: XPrivateResult = await xPrivateClient.accountSettingsGraphql('UserSessionsList', {});
    this.requireResult(result, generation);
    const root: XPrivacyEnvelope = JSON.parse(result.body) as XPrivacyEnvelope;
    const sessions: XLoginSession[] | undefined = root.data?.viewer?.user_results?.result?.sessions_list ??
      root.data?.viewer?.user?.sessions_list ?? root.sessions;
    if (!Array.isArray(sessions)) { throw new Error('settings_unavailable'); }
    return sessions;
  }

  private async readApplications(generation: number): Promise<XConnectedApplication[]> {
    const result: XPrivateResult = await xPrivateClient.accountSettingsRest('GET', '/1.1/oauth/list.json', {});
    this.requireResult(result, generation);
    const applications: XConnectedApplication[] | undefined = (JSON.parse(result.body) as XPrivacyEnvelope).applications;
    if (!Array.isArray(applications)) { throw new Error('settings_unavailable'); }
    return applications.filter((application: XConnectedApplication): boolean => application.revoked !== true);
  }

  sessionToken(session: XLoginSession): string { return session.token ?? session.hashed_token ?? ''; }

  async revokeSession(token: string, generation: number): Promise<AccountPrivacySnapshot> {
    this.requireGeneration(generation);
    const sessions: XLoginSession[] = await this.readSessions(generation);
    const target: XLoginSession | undefined = sessions.find((session: XLoginSession): boolean => this.sessionToken(session) === token);
    if (token.length === 0 || target === undefined || target.is_current_session !== false) {
      throw new Error('invalid_session');
    }
    this.requireResult(await xPrivateClient.accountSettingsRest('POST', '/account/sessions/revoke', { 'hashed_token': token }), generation);
    const confirmed: AccountPrivacySnapshot = await this.read('sessions');
    this.requireGeneration(generation);
    if (confirmed.sessions.some((session: XLoginSession): boolean => this.sessionToken(session) === token)) {
      throw new Error('settings_unconfirmed');
    }
    return confirmed;
  }

  async revokeOtherSessions(generation: number): Promise<AccountPrivacySnapshot> {
    this.requireGeneration(generation);
    this.requireResult(await xPrivateClient.accountSettingsRest('POST', '/account/sessions/revoke_all', {}), generation);
    const confirmed: AccountPrivacySnapshot = await this.read('sessions');
    this.requireGeneration(generation);
    if (confirmed.sessions.some((session: XLoginSession): boolean => session.is_current_session !== true)) {
      throw new Error('settings_unconfirmed');
    }
    return confirmed;
  }

  async revokeApplication(application: XConnectedApplication, generation: number): Promise<AccountPrivacySnapshot> {
    this.requireGeneration(generation);
    const token: string = application.token ?? '';
    const hash: string = application.token_hash ?? '';
    if (token.length === 0 && hash.length === 0) { throw new Error('settings_unavailable'); }
    const applications: XConnectedApplication[] = await this.readApplications(generation);
    if (!applications.some((item: XConnectedApplication): boolean => token.length > 0 ? item.token === token : item.token_hash === hash)) {
      throw new Error('settings_unavailable');
    }
    const path: string = token.length > 0 ? '/1.1/oauth/revoke.json' : '/2/oauth2/revoke_token_hash';
    const form: Record<string, string> = token.length > 0 ? { 'token': token } : { 'token_hash': hash };
    this.requireResult(await xPrivateClient.accountSettingsRest('POST', path, form), generation);
    const confirmed: AccountPrivacySnapshot = await this.read('applications');
    this.requireGeneration(generation);
    if (confirmed.applications.some((item: XConnectedApplication): boolean => token.length > 0 ? item.token === token : item.token_hash === hash)) {
      throw new Error('settings_unconfirmed');
    }
    return confirmed;
  }

  async clearData(action: string, generation: number): Promise<void> {
    this.requireGeneration(generation);
    if (action !== 'contacts' && action !== 'locations') { throw new Error('invalid_action'); }
    const path: string = action === 'contacts' ? '/1.1/contacts/destroy/all.json' : '/1.1/geo/delete_location_data.json';
    this.requireResult(await xPrivateClient.accountSettingsRest('POST', path, {}), generation);
  }

  async syncSensitiveMedia(context: common.Context, reset: boolean = false): Promise<void> {
    if (reset) { mediaSettingsStore.saveShowSensitiveMedia(context, false); }
    if (!xPrivateClient.isSignedIn()) { return; }
    const generation: number = xPrivateClient.sessionGeneration();
    const settings: XAccountPrivacySettings = await this.readAccount(generation);
    this.requireGeneration(generation);
    if (typeof settings.display_sensitive_media === 'boolean') {
      mediaSettingsStore.saveShowSensitiveMedia(context, settings.display_sensitive_media);
    }
  }
}

export const accountPrivacyService: AccountPrivacyService = new AccountPrivacyService();
