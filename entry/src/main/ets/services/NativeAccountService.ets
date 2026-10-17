import {
  NativeAccountField, NativeAccountSnapshot, NativeAccountRow, NativeMutedKeywordList
} from '../models/NativeAccount';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { XUserParser } from './XUserParser';
import { UserProfile } from '../models/Tweet';

export class NativeAccountService {
  check(generation: number): void {
    if (!xPrivateClient.isSignedIn() || generation !== xPrivateClient.sessionGeneration()) { throw new Error('account_changed'); }
  }

  object(value: Object | null | undefined): Record<string, Object | null> {
    return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value) ?
      value as Record<string, Object | null> : {};
  }

  array(value: Object | null | undefined): Record<string, Object | null>[] {
    return Array.isArray(value) ? value as Record<string, Object | null>[] : [];
  }

  string(value: Object | null | undefined): string {
    return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
  }

  async request(method: string, path: string, payload: Record<string, Object | null>, json: boolean,
    generation: number): Promise<string> {
    this.check(generation);
    const result: XPrivateResult = await xPrivateClient.accountManagementRequest(method, path, payload, json, generation);
    this.check(generation);
    if (!result.ok) { throw new Error('native_request_failed_' + result.status); }
    if (result.body.trim().startsWith('{')) {
      const root: Record<string, Object | null> = this.object(JSON.parse(result.body) as Object);
      if (this.array(root['errors']).length > 0) { throw new Error('native_request_failed_' + result.status); }
    }
    return result.body;
  }

  private async get(path: string, generation: number, payload: Record<string, Object | null> = {}): Promise<Record<string, Object | null>> {
    return this.object(JSON.parse(await this.request('GET', path, payload, false, generation)) as Object);
  }

  private async relay(name: string, generation: number, variables: Record<string, Object | null> = {}): Promise<Record<string, Object | null>> {
    this.check(generation);
    const result: XPrivateResult = await xPrivateClient.accountSettingsGraphql(name, variables);
    this.check(generation);
    if (!result.ok) { throw new Error('native_request_failed_' + result.status); }
    const root: Record<string, Object | null> = this.object(JSON.parse(result.body) as Object);
    if (Array.isArray(root['errors']) && this.array(root['errors']).length > 0) { throw new Error('native_unavailable'); }
    if (root['data'] === undefined || root['data'] === null) { throw new Error('native_unavailable'); }
    return this.object(root['data']);
  }

  private field(snapshot: NativeAccountSnapshot, id: string, title: Resource, kind: string,
    data: Record<string, Object | null>, key: string = id): NativeAccountField {
    const value: Object | null | undefined = data[key];
    const field: NativeAccountField = new NativeAccountField(id, title, kind,
      typeof value === 'boolean' ? String(value) : this.string(value));
    field.available = kind === 'toggle' ? typeof value === 'boolean' :
      typeof value === 'string' || typeof value === 'number' || (kind === 'readonly' && typeof value === 'boolean');
    snapshot.fields.push(field);
    return field;
  }

  private input(snapshot: NativeAccountSnapshot, id: string, title: Resource | string, kind: string = 'text', value: string = ''): void {
    snapshot.fields.push(new NativeAccountField(id, title, kind, value));
  }

  private rows(snapshot: NativeAccountSnapshot, data: Record<string, Object | null>[], action: string = ''): void {
    for (let i: number = 0; i < data.length; i++) {
      const item: Record<string, Object | null> = data[i];
      if (typeof item === 'string' || typeof item === 'number') {
        snapshot.rows.push({ id: 'record:' + snapshot.rows.length, title: String(item), detail: '', value: '', action: '' }); continue;
      }
      const serverId: string = this.string(item['id'] ?? item['id_str'] ?? item['token'] ?? item['registration_token']);
      const id: string = serverId || 'record:' + snapshot.rows.length;
      const title: string = this.string(item['name'] ?? item['display_name'] ?? item['keyword'] ?? item['client_type'] ??
        item['externalDisplayName'] ?? item['device_name'] ?? item['device_type'] ?? item['app_name'] ?? item['display'] ?? item['twoFactorType'] ?? item['source_name'] ?? item['country'] ?? item['status']);
      const details: string[] = [];
      const keys: string[] = ['description', 'location', 'country', 'ip', 'created_at', 'created_at_ms', 'createdAtMs',
        'timestamp', 'time', 'registration_ts', 'last_seen_at', 'valid_until', 'twoFactorType', 'organization', 'email', 'phone_number'];
      for (let j: number = 0; j < keys.length; j++) {
        const value: string = this.string(item[keys[j]]);
        if (value.length > 0) { details.push(value); }
      }
      snapshot.rows.push({ id: id, title: title || id, detail: details.join(' · '),
        value: this.string(item['url'] ?? item['download_url'] ?? item['token_hash'] ?? item['sso_provider']), action: serverId.length > 0 && item['is_current_device'] !== true ? action : '' });
    }
  }

  private async account(generation: number): Promise<Record<string, Object | null>> {
    return await this.get('/1.1/account/settings.json', generation, {
      'include_nsfw_user_flag': true, 'include_country_code': true, 'ext': 'ssoConnections',
      'include_ext_sharing_audiospaces_listening_data_with_followers': true
    });
  }

  async load(feature: string): Promise<NativeAccountSnapshot> {
    const snapshot: NativeAccountSnapshot = new NativeAccountSnapshot();
    snapshot.generation = xPrivateClient.sessionGeneration();
    const generation: number = snapshot.generation;
    this.check(generation);
    if (feature === 'password') {
      this.input(snapshot, 'current_password', $r('app.string.xnative_current_password'), 'password');
      this.input(snapshot, 'password', $r('app.string.xnative_new_password'), 'password');
      this.input(snapshot, 'password_confirmation', $r('app.string.xnative_confirm_password'), 'password');
    } else if (feature === 'deactivate') {
      this.input(snapshot, 'current_password', $r('app.string.xnative_current_password'), 'password');
    } else if (feature === 'username' || feature === 'country' || feature === 'password_protection' ||
      feature === 'discoverability' || feature === 'spaces' || feature === 'cookie_controls' || feature === 'precise_location') {
      snapshot.data = await this.account(generation);
      if (feature === 'username') { this.field(snapshot, 'screen_name', $r('app.string.xsettings_username'), 'text', snapshot.data); }
      if (feature === 'country') { this.field(snapshot, 'country_code', $r('app.string.xsettings_country'), 'text', snapshot.data); }
      if (feature === 'password_protection') {
        this.field(snapshot, 'protect_password_reset', $r('app.string.xsettings_password_protection'), 'toggle', snapshot.data);
        this.input(snapshot, 'current_password', $r('app.string.xnative_current_password'), 'password');
      }
      if (feature === 'discoverability') {
        this.field(snapshot, 'discoverable_by_email', $r('app.string.xnative_discover_email'), 'toggle', snapshot.data);
        this.field(snapshot, 'discoverable_by_mobile_phone', $r('app.string.xnative_discover_phone'), 'toggle', snapshot.data);
      }
      if (feature === 'spaces') {
        this.field(snapshot, 'ext_sharing_audiospaces_listening_data_with_followers', $r('app.string.xnative_spaces_listening'), 'toggle', snapshot.data);
      }
      if (feature === 'cookie_controls') { this.field(snapshot, 'use_cookie_personalization', $r('app.string.xnative_cookie_personalization'), 'toggle', snapshot.data); }
      if (feature === 'precise_location') { this.field(snapshot, 'geo_enabled', $r('app.string.xnative_post_location'), 'toggle', snapshot.data); }
    } else if (feature === 'email' || feature === 'phone') {
      snapshot.data = await this.get('/1.1/users/email_phone_info.json', generation, { 'include_pending_email': true });
        const key: string = feature === 'email' ? 'emails' : 'phone_numbers';
        if (!Array.isArray(snapshot.data[key])) { throw new Error('native_unavailable'); }
        const list: Record<string, Object | null>[] = this.array(snapshot.data[key]);
        for (let i: number = 0; i < list.length; i++) {
          const address: string = this.string(list[i]['email'] ?? list[i]['phone_number']);
          const verified: Object | null | undefined = list[i][feature === 'email' ? 'email_verified' : 'phone_verified'];
          snapshot.rows.push({ id: address, title: address,
            detail: '', value: address, verified: typeof verified === 'boolean' ? verified : undefined,
            action: feature === 'phone' && address.length > 0 ? 'remove_phone' : feature === 'email' && list[i]['email_verified'] === false ? 'resend_email' : '' });
        }
    } else if (feature === 'profile' || feature === 'age') {
      const result: XPrivateResult = await xPrivateClient.userByRestId(xPrivateClient.viewerId());
      this.check(generation);
      const profile: UserProfile | null = result.ok ? XUserParser.parse(result.body) : null;
      if (profile === null) { throw new Error('native_unavailable'); }
      if (feature === 'profile') {
        this.input(snapshot, 'name', $r('app.string.xnative_display_name'), 'text', profile.name);
        this.input(snapshot, 'description', $r('app.string.xnative_bio'), 'text', profile.description);
        this.input(snapshot, 'location', $r('app.string.xnative_location'), 'text', profile.location ?? '');
        this.input(snapshot, 'url', $r('app.string.xnative_website'), 'text', profile.website ?? '');
      } else {
        const data: Record<string, Object | null> = this.object(this.object(JSON.parse(result.body) as Object)['data']);
        const user: Record<string, Object | null> = this.object(this.object(data['user'])['result']);
        const birth: Record<string, Object | null> = this.object(this.object(user['legacy_extended_profile'])['birthdate']);
        this.input(snapshot, 'birthdate_year', $r('app.string.xnative_year'), 'number', this.string(birth['year']));
        this.input(snapshot, 'birthdate_month', $r('app.string.xnative_month'), 'number', this.string(birth['month']));
        this.input(snapshot, 'birthdate_day', $r('app.string.xnative_day'), 'number', this.string(birth['day']));
        const visibility: NativeAccountField = this.field(snapshot, 'birthdate_visibility', $r('app.string.xnative_birthdate_visibility'), 'choice', birth, 'visibility');
        const yearVisibility: NativeAccountField = this.field(snapshot, 'birthdate_year_visibility', $r('app.string.xnative_birthyear_visibility'), 'choice', birth, 'year_visibility');
        visibility.choices = [{ value: 'self', label: $r('app.string.xnative_only_me') }, { value: 'public', label: $r('app.string.xsettings_everyone') },
          { value: 'followers', label: $r('app.string.xnative_followers') }, { value: 'following', label: $r('app.string.xnative_people_following') }, { value: 'mutualfollow', label: $r('app.string.xnative_mutual') }];
        yearVisibility.choices = visibility.choices;
      }
    } else if (feature === 'muted_words') {
      const response: NativeMutedKeywordList = JSON.parse(await this.request('GET', '/1.1/mutes/keywords/list.json', {}, false, generation)) as NativeMutedKeywordList;
      if (!Array.isArray(response.muted_keywords)) { throw new Error('native_unavailable'); }
      for (let i: number = 0; i < response.muted_keywords.length; i++) {
        const keyword = response.muted_keywords[i];
        snapshot.rows.push({ id: keyword.id, title: keyword.keyword, detail: keyword.valid_until ?? '', value: '', action: 'edit_keyword' });
      }
      snapshot.keywords = response.muted_keywords;
    } else if (feature === 'notification_filters') {
      snapshot.data = await this.get('/1.1/mutes/advanced_filters.json', generation);
      const keys: string[] = ['filter_not_following', 'filter_not_followed_by', 'filter_new_users',
        'filter_default_profile_image', 'filter_no_confirmed_email', 'filter_no_confirmed_phone'];
      const titles: Resource[] = [$r('app.string.xnative_filter_not_following'), $r('app.string.xnative_filter_not_followed'),
        $r('app.string.xnative_filter_new'), $r('app.string.xnative_filter_avatar'), $r('app.string.xnative_filter_email'), $r('app.string.xnative_filter_phone')];
      for (let i: number = 0; i < keys.length; i++) {
        const field: NativeAccountField = new NativeAccountField(keys[i], titles[i], 'toggle');
          const value: Object | null | undefined = snapshot.data[keys[i]];
          field.available = typeof value === 'boolean'; field.value = String(value === true);
        snapshot.fields.push(field);
      }
    } else if (feature === 'imported_contacts') {
      snapshot.data = await this.get('/1.1/contacts/addressbook.json', generation, { 'count': 100 });
      const contacts: Record<string, Object | null>[] = this.array(snapshot.data['contacts']);
      for (let i: number = 0; i < contacts.length; i++) {
        const lines: string[] = this.string(contacts[i]['vcard']).replace(/\r?\n[ \t]/g, '').split(/\r?\n/);
        let name: string = ''; const details: string[] = [];
        for (let j: number = 0; j < lines.length; j++) {
          const separator: number = lines[j].indexOf(':'); if (separator < 0) { continue; }
          const key: string = lines[j].substring(0, separator).split(';')[0].toUpperCase();
          const value: string = lines[j].substring(separator + 1).replace(/\\n/g, '\n').replace(/\\([,;\\])/g, '$1');
          if (key === 'FN') { name = value; } else if (key === 'EMAIL' || key === 'TEL') { details.push(value); }
        }
        snapshot.rows.push({ id: this.string(contacts[i]['id'] ?? contacts[i]['id_str']) || 'contact:' + i,
          title: name || details[0] || $r('app.string.xnative_contact'), detail: details.join(' · '), value: '', action: '' });
      }
    } else if (feature === 'search') {
      snapshot.data = await this.get('/1.1/strato/column/User/' + xPrivateClient.viewerId() + '/search/searchSafetyReadonly', generation);
      this.field(snapshot, 'optInFiltering', $r('app.string.xnative_search_sensitive'), 'toggle', snapshot.data);
      this.field(snapshot, 'optInBlocking', $r('app.string.xnative_search_muted'), 'toggle', snapshot.data);
    } else if (feature === 'sensitive_categories') {
      const data: Record<string, Object | null> = await this.relay('SensitiveMediaSettingsQuery', generation);
      const user: Record<string, Object | null> = this.object(this.object(this.object(data['viewer'])['user_results'])['result']);
      const info: Record<string, Object | null> = this.object(user['sensitive_media_settings']);
      snapshot.data = this.object(info['sensitive_media_settings']);
      snapshot.data['can_user_allow_sensitive_content'] = info['can_user_allow_sensitive_content'] ?? null;
      const keys: string[] = ['view_violent_content', 'view_adult_content', 'view_other_content'];
      const titles: Resource[] = [$r('app.string.xnative_violent_content'), $r('app.string.xnative_adult_content'), $r('app.string.xnative_other_content')];
      for (let i: number = 0; i < keys.length; i++) {
        const field: NativeAccountField = this.field(snapshot, keys[i], titles[i], 'choice', snapshot.data);
        field.choices = [{ value: 'Warn', label: $r('app.string.xnative_warn') }, { value: 'Allow', label: $r('app.string.xnative_allow') }, { value: 'Drop', label: $r('app.string.xnative_drop') }];
        if (keys[i] === 'view_adult_content' && info['can_user_allow_sensitive_content'] !== true) { field.available = false; }
      }
    } else if (feature === 'explore') {
      snapshot.data = await this.get('/2/guide/get_explore_settings.json', generation);
      this.field(snapshot, 'use_current_location', $r('app.string.xnative_explore_location'), 'toggle', snapshot.data);
      this.field(snapshot, 'use_personalized_trends', $r('app.string.xnative_explore_personalized'), 'toggle', snapshot.data);
      if (snapshot.data['is_stories_available'] === true) { this.field(snapshot, 'use_fun_mode_stories', $r('app.string.xnative_explore_fun'), 'toggle', snapshot.data); }
    } else if (feature === 'two_factor' || feature === 'security_keys') {
      snapshot.data = await this.get('/1.1/strato/column/User/' + xPrivateClient.viewerId() + '/account-security/twoFactorAuthSettings2', generation);
      this.field(snapshot, 'twoFactorAuthEnabled', $r('app.string.xsettings_two_factor'), 'readonly', snapshot.data);
      const methods: Record<string, Object | null>[] = this.array(snapshot.data['methods']);
      this.rows(snapshot, feature === 'security_keys' ? methods.filter((item: Record<string, Object | null>): boolean => item['twoFactorType'] === 'U2fSecurityKey') : methods, 'disable_2fa_method');
    } else if (feature === 'passkeys') {
      const data: Record<string, Object | null> = await this.relay('PasskeyManagement_Query', generation);
      const user: Record<string, Object | null> = this.object(this.object(this.object(data['viewer_v2'])['user_results'])['result']);
      if (!Array.isArray(user['passkey_auth_settings_with_view'])) { throw new Error('native_unavailable'); }
      this.rows(snapshot, this.array(user['passkey_auth_settings_with_view']), 'delete_passkey');
    } else if (feature === 'ad_categories') {
      const data: Record<string, Object | null> = await this.relay('AdsCategoriesQuery', generation);
      snapshot.data = this.object(data['user_preferences']);
      this.field(snapshot, 'allow_gambling_ads', $r('app.string.xnative_gambling_ads'), 'toggle', snapshot.data);
    } else if (feature === 'parody') {
      const data: Record<string, Object | null> = await this.relay('AccountParodyScreenImplV2ParodyLabelSettingQuery', generation);
      snapshot.data = this.object(data['get_parody_label_settings']);
      const field: NativeAccountField = this.field(snapshot, 'parody_commentary_fan_label', $r('app.string.xsettings_parody'), 'choice', snapshot.data);
      field.available = field.available && snapshot.data['is_label_update_disabled'] !== true;
      field.choices = [{ value: 'None', label: $r('app.string.xnative_none') }, { value: 'Parody', label: $r('app.string.xnative_parody') },
        { value: 'Commentary', label: $r('app.string.xnative_commentary') }, { value: 'Fan', label: $r('app.string.xnative_fan') }];
    } else if (feature === 'connected_accounts') {
      snapshot.data = await this.account(generation);
      const result: Record<string, Object | null> = this.object(this.object(this.object(snapshot.data['ext'])['ssoConnections'])['r']);
      if (!Array.isArray(result['ok'])) { throw new Error('native_unavailable'); }
      const connections: Record<string, Object | null>[] = this.array(result['ok']);
      for (let i: number = 0; i < connections.length; i++) {
        const provider: string = this.string(connections[i]['ssoProvider']);
        if (provider.length > 0) { snapshot.rows.push({ id: provider, title: provider, detail: '', value: provider.toLowerCase(), action: 'remove_sso' }); }
      }
    } else if (feature === 'chat_devices') {
      snapshot.data = await this.get('/1.1/keyregistry/extract_public_keys/' + xPrivateClient.viewerId(), generation);
      if (!Array.isArray(snapshot.data['public_keys'])) { throw new Error('native_unavailable'); }
      this.rows(snapshot, this.array(snapshot.data['public_keys']), 'remove_chat_device');
    } else if (feature === 'archive') {
      const body: string = await this.request('GET', '/1.1/account/user_twitter_data', {}, false, generation);
      const downloads: Object = JSON.parse(body) as Object;
      if (!Array.isArray(downloads)) { throw new Error('native_unavailable'); }
      this.rows(snapshot, this.array(downloads));
      for (let i: number = 0; i < snapshot.rows.length; i++) {
        if (this.safeDownload(snapshot.rows[i].value)) { snapshot.rows[i].action = 'open_download'; }
      }
    } else if (feature === 'automation') {
      const data: Record<string, Object | null> = await this.relay('UserAccountLabel', generation, { 'rest_id': xPrivateClient.viewerId() });
      const user: Record<string, Object | null> = this.object(this.object(data['user'])['result']);
      if (user['account_label'] === undefined) { throw new Error('native_unavailable'); }
      const managed: Record<string, Object | null> = this.object(this.object(user['account_label'])['managed_label']);
      const owner: string = this.string(managed['owner_screen_name']);
      if (owner.length > 0) { snapshot.rows.push({ id: 'automation', title: '@' + owner, detail: '', value: '', action: 'disable_automation' }); }
    } else if (feature === 'verified') {
      const data: Record<string, Object | null> = await this.relay('IDVerificationQuery', generation);
      const user: Record<string, Object | null> = this.object(this.object(this.object(data['viewer'])['user_results'])['result']);
      snapshot.data = this.object(user['verification_info']);
      const status: string = this.string(snapshot.data['identity_verification_status']);
      if (status.length === 0) { throw new Error('native_unavailable'); }
      this.field(snapshot, 'is_identity_verified', $r('app.string.xnative_verification_status'), 'readonly', snapshot.data);
      const field: NativeAccountField = this.field(snapshot, 'is_identity_verified_label_hidden', $r('app.string.xnative_hide_verified'), 'toggle', snapshot.data);
      field.available = field.available && snapshot.data['is_identity_verified'] === true && status !== 'UnavailableMissingBlueSubscription';
      this.input(snapshot, 'identity_verification_status', $r('app.string.xnative_verification_status'), 'readonly', status);
      const statusField: NativeAccountField = snapshot.fields[snapshot.fields.length - 1];
      statusField.choices = [{ value: 'IdentityVerified', label: $r('app.string.xnative_verified') }, { value: 'CanVerifyIdentity', label: $r('app.string.xnative_verification_ready') },
        { value: 'PendingResult', label: $r('app.string.xnative_verification_pending') }, { value: 'RequestLocked', label: $r('app.string.xnative_verification_locked') },
        { value: 'UnavailableMissingBlueSubscription', label: $r('app.string.xnative_verification_premium') }, { value: 'IdentityNonVerifiable', label: $r('app.string.xnative_verification_unavailable') }];
    } else if (feature === 'grok_history') {
      await this.historyPage(snapshot);
    } else if (feature === 'topics') {
      const data: Record<string, Object | null> = await this.relay('TopicToFollowSidebar', generation, { 'userId': xPrivateClient.viewerId() });
      this.collectTopics(snapshot, data, 0);
      snapshot.notice = $r('app.string.xnative_topic_suggestions');
    } else if (feature === 'delegate') {
      await this.delegates(snapshot);
    } else if (['account_data', 'x_data', 'login_history', 'location_history', 'logged_devices', 'advertiser_audiences', 'gender', 'languages', 'interests'].indexOf(feature) >= 0) {
      snapshot.data = await this.get('/1.1/account/personalization/p13n_data.json', generation);
      if (feature === 'login_history') { this.rows(snapshot, this.array(snapshot.data['login_history'])); }
      else if (feature === 'location_history') { this.rows(snapshot, this.array(snapshot.data['location_history'])); }
      else if (feature === 'logged_devices') {
        const known: Record<string, Object | null> = this.object(snapshot.data['known_devices']);
        const categories: string[] = ['phone', 'tablet', 'desktop'];
        for (let i: number = 0; i < categories.length; i++) { this.rows(snapshot, this.array(known[categories[i]])); }
      }
      else if (feature === 'advertiser_audiences') {
        const summary: Record<string, Object | null> = this.object(snapshot.data['tailored_audience_summary']);
        this.field(snapshot, 'num_advertisers', $r('app.string.xsettings_advertiser_audiences'), 'readonly', summary);
        this.field(snapshot, 'num_audiences', $r('app.string.xsettings_advertiser_audiences'), 'readonly', summary);
      }
      else if (feature === 'languages' || feature === 'gender' || feature === 'interests') {
        const preferences: Record<string, Object | null> = await this.get('/1.1/account/personalization/p13n_preferences.json', generation);
        snapshot.data['preferences'] = preferences;
        if (feature === 'gender') {
          const gender: Record<string, Object | null> = this.object(preferences['gender_preferences']);
          const override: Record<string, Object | null> = this.object(gender['gender_override']);
          const type: string = this.string(override['type']) || this.string(snapshot.data['gender']);
          const field: NativeAccountField = new NativeAccountField('gender_type', $r('app.string.xnative_gender_type'), 'choice', type);
          field.choices = [{ value: 'male', label: $r('app.string.xnative_male') }, { value: 'female', label: $r('app.string.xnative_female') }, { value: 'custom', label: $r('app.string.xnative_custom_gender') }];
          snapshot.fields.push(field);
          this.input(snapshot, 'gender_value', $r('app.string.xnative_custom_gender'), 'text', this.string(override['value']) || type);
        } else if (feature === 'interests') {
          const interests: Record<string, Object | null> = await this.get('/1.1/account/personalization/partner_interests.json', generation);
          const disabled: string[] = this.strings(this.object(preferences['interest_preferences'])['disabled_partner_interests']);
          const list: Record<string, Object | null>[] = this.array(interests['partner_interests']);
          for (let i: number = 0; i < list.length; i++) {
            const id: string = this.string(list[i]['id']);
            if (id.length > 0) { this.input(snapshot, 'interest:' + id, this.string(list[i]['display_name']), 'toggle', String(disabled.indexOf(id) < 0)); }
          }
        } else {
          const disabled: string[] = this.strings(this.object(preferences['language_preferences'])['disabled_languages']);
          const list: Record<string, Object | null>[] = this.array(snapshot.data['languages']);
          for (let i: number = 0; i < list.length; i++) {
            const id: string = this.string(list[i]['key']);
            if (id.length > 0) { this.input(snapshot, 'language:' + id, this.string(list[i]['display']), i === 0 ? 'readonly' : 'toggle', i === 0 ? this.string(list[i]['display']) : String(disabled.indexOf(id) < 0)); }
          }
        }
      } else {
        const keys: string[] = ['signup_details', 'account', 'ages', 'languages', 'gender', 'location_history', 'login_history'];
        for (let i: number = 0; i < keys.length; i++) {
          const value: Object | null | undefined = snapshot.data[keys[i]];
          if (value === undefined || value === null) { continue; }
          const titles: Resource[] = [$r('app.string.xnative_data_account'), $r('app.string.xnative_data_account'), $r('app.string.xnative_data_age'), $r('app.string.xnative_data_language'), $r('app.string.xnative_data_gender'), $r('app.string.xnative_data_location'), $r('app.string.xnative_data_login')];
          snapshot.rows.push({ id: keys[i], title: titles[i], detail: typeof value === 'object' ?
            this.readable(value) : this.string(value), value: keys[i], action: 'data_section' });
        }
      }
    } else { throw new Error('native_unavailable'); }
    this.check(generation);
    return snapshot;
  }

  private async historyPage(snapshot: NativeAccountSnapshot, cursor: string = ''): Promise<void> {
    const variables: Record<string, Object | null> = {};
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    const data: Record<string, Object | null> = await this.relay('GrokHistory', snapshot.generation, variables);
    const history: Record<string, Object | null> = this.object(data['grok_conversation_history']);
    if (!Array.isArray(history['items'])) { throw new Error('native_unavailable'); }
    snapshot.data = history;
    const items: Record<string, Object | null>[] = this.array(history['items']);
    for (let i: number = 0; i < items.length; i++) {
      const conversation: Record<string, Object | null> = this.object(items[i]['grokConversation']);
      const id: string = this.string(conversation['rest_id'] ?? conversation['id']);
      if (id.length > 0 && !snapshot.rows.some((row: NativeAccountRow): boolean => row.id === id)) {
        snapshot.rows.push({ id: id, title: this.string(items[i]['title']) || id,
          detail: this.date(items[i]['created_at_ms']), value: '', action: '' });
      }
    }
    if (cursor.length > 0 && this.string(history['cursor']) === cursor) { snapshot.data['cursor'] = null; }
  }

  async moreHistory(snapshot: NativeAccountSnapshot): Promise<NativeAccountSnapshot> {
    this.check(snapshot.generation);
    const cursor: string = this.string(snapshot.data['cursor']);
    if (cursor.length === 0) { throw new Error('native_unavailable'); }
    const next: NativeAccountSnapshot = new NativeAccountSnapshot();
    next.generation = snapshot.generation; next.rows = [...snapshot.rows];
    await this.historyPage(next, cursor);
    return next;
  }

  private readable(value: Object): string {
    if (Array.isArray(value)) { return (value as Object[]).map((item: Object): string => this.readable(item)).filter((s: string): boolean => s.length > 0).join('\n'); }
    if (typeof value !== 'object') { return String(value); }
    const data: Record<string, Object | null> = this.object(value);
    const keys: string[] = ['name', 'display_name', 'country', 'location', 'ip', 'date', 'created_at', 'timestamp', 'source_name', 'address'];
    const values: string[] = [];
    for (let i: number = 0; i < keys.length; i++) { const text: string = this.string(data[keys[i]]); if (text.length > 0) { values.push(text); } }
    return values.join(' · ');
  }

  private strings(value: Object | null | undefined): string[] {
    return Array.isArray(value) ? (value as Object[]).map((item: Object): string => this.string(item)) : [];
  }

  private date(value: Object | null | undefined): string {
    const raw: string = this.string(value);
    const time: number = Number(raw);
    return raw.length > 0 && Number.isFinite(time) && time > 0 ? new Date(time).toLocaleString() : raw;
  }

  private collectTopics(snapshot: NativeAccountSnapshot, value: Object | null, depth: number): void {
    if (value === null || typeof value !== 'object' || depth > 20) { return; }
    if (Array.isArray(value)) {
      const list: Object[] = value as Object[];
      for (let i: number = 0; i < list.length; i++) { this.collectTopics(snapshot, list[i], depth + 1); } return;
    }
    const item: Record<string, Object | null> = this.object(value);
    const id: string = this.string(item['topic_id']);
    if (id.length > 0 && !snapshot.rows.some((row: NativeAccountRow): boolean => row.id === id)) {
      const following: Object | null | undefined = item['following'];
      const ignored: Object | null | undefined = item['not_interested'];
      snapshot.rows.push({ id: id, title: this.string(item['name']) || id, detail: this.string(item['description']), value: '',
        action: typeof following === 'boolean' ? following ? 'topic_unfollow' : 'topic_follow' : '',
        secondaryAction: typeof ignored === 'boolean' ? ignored ? 'topic_restore' : 'topic_ignore' : '' });
    }
    const keys: string[] = Object.keys(item);
    for (let i: number = 0; i < keys.length; i++) { this.collectTopics(snapshot, item[keys[i]] ?? null, depth + 1); }
  }

  safeDownload(url: string): boolean { return /^https:\/\/(?:x\.com|twitter\.com|(?:[a-z0-9-]+\.)?twimg\.com)\//i.test(url); }

  async backup(generation: number, renew: boolean = false): Promise<string> {
    const response: Record<string, Object | null> = this.object(JSON.parse(await this.request(renew ? 'POST' : 'GET', '/1.1/account/backup_code.json', {}, false, generation)) as Object);
    const codes: string[] = this.strings(response['codes']);
    if (codes.length === 0) { throw new Error('native_unavailable'); }
    return codes[0];
  }

  private async delegates(snapshot: NativeAccountSnapshot): Promise<void> {
    const generation: number = snapshot.generation;
    const data: Record<string, Object | null> = await this.relay('DelegateQuery', generation);
    snapshot.data = this.object(this.object(this.object(data['viewer_v2'])['user_results'])['result']);
    const field: NativeAccountField = this.field(snapshot, 'delegation_invitation_preferences', $r('app.string.xnative_delegation'), 'choice', snapshot.data);
    field.choices = [{ value: 'Nobody', label: $r('app.string.xsettings_nobody') }, { value: 'Everyone', label: $r('app.string.xsettings_everyone') }, { value: 'OnlyFollowing', label: $r('app.string.xnative_people_following') }];
    const membersData: Record<string, Object | null> = await this.relay('MembersDelegateQuery', generation);
    const viewer: Record<string, Object | null> = this.object(membersData['viewer_v2']);
    const viewerId: string = this.string(this.object(viewer['user'])['rest_id']);
    if (viewerId !== xPrivateClient.viewerId()) { throw new Error('native_unavailable'); }
    const groups: Record<string, Object | null>[] = this.array(viewer['list_delegation_groups']);
    const group: Record<string, Object | null> = groups.length > 0 ? groups[0] : {};
    snapshot.data['delegationGroupId'] = this.string(group['rest_id']) || viewerId;
    const members: Record<string, Object | null>[] = this.array(group['members']);
    for (let i: number = 0; i < members.length; i++) {
      const member: Record<string, Object | null> = members[i];
      const user: Record<string, Object | null> = this.object(this.object(member['user_results'])['result']);
      const core: Record<string, Object | null> = this.object(user['core']);
      const role: string = this.string(member['role']);
      const status: string = this.string(member['status']);
      const id: string = this.string(member['rest_id']);
      snapshot.rows.push({ id: id, title: '@' + this.string(core['screen_name']), detail: this.string(core['name']) + ' · ' + role + ' · ' + status,
        value: '', targetId: this.string(user['rest_id']), role: role,
        action: id.length > 0 && role !== 'Owner' ? status === 'Pending' ? 'cancel_delegate' : 'remove_delegate' : '',
        secondaryAction: id.length > 0 && (role === 'Admin' || role === 'Contributor') && status === 'Accepted' ? 'change_delegate_role' : '' });
    }
    const groupData: Record<string, Object | null> = await this.relay('GroupsDelegateQuery', generation);
    const groupViewer: Record<string, Object | null> = this.object(groupData['viewer_v2']);
    const loggedId: string = this.string(this.object(groupViewer['user'])['id']);
    const keys: string[] = ['acceptedAdminGroups', 'acceptedContributorGroups', 'pendingGroups'];
    for (let i: number = 0; i < keys.length; i++) {
      const list: Record<string, Object | null>[] = this.array(groupViewer[keys[i]]);
      for (let j: number = 0; j < list.length; j++) {
        const owner: Record<string, Object | null> = this.object(this.object(list[j]['handle_results'])['result']);
        const memberships: Record<string, Object | null>[] = this.array(list[j]['members']);
        const membership = memberships.find((item: Record<string, Object | null>): boolean => this.string(this.object(this.object(item['user_results'])['result'])['id']) === loggedId);
        const id: string = this.string(membership?.['rest_id']);
        if (loggedId.length > 0 && id.length > 0) { snapshot.rows.push({ id: 'group:' + id,
          title: '@' + this.string(this.object(owner['core'])['screen_name']), detail: this.string(membership?.['role']),
          value: id, action: i === 2 ? 'reject_delegate' : 'leave_delegate', secondaryAction: i === 2 ? 'accept_delegate' : '' }); }
      }
    }
  }

  value(fields: NativeAccountField[], id: string): string {
    const field: NativeAccountField | undefined = fields.find((item: NativeAccountField): boolean => item.id === id);
    return field?.value ?? '';
  }

  async verify(password: string, generation: number): Promise<void> {
    if (password.length === 0) { throw new Error('password_required'); }
    await this.request('POST', '/1.1/account/verify_password.json', { 'password': password }, false, generation);
  }

  async save(feature: string, snapshot: NativeAccountSnapshot, fields: NativeAccountField[]): Promise<NativeAccountSnapshot> {
    const generation: number = snapshot.generation;
    this.check(generation);
    const form: Record<string, Object | null> = {};
    for (let i: number = 0; i < fields.length; i++) {
      const field: NativeAccountField = fields[i];
      if (!field.available || field.kind === 'readonly') { continue; }
      if (!snapshot.fields.some((item: NativeAccountField): boolean => item.id === field.id && item.available && item.kind === field.kind)) { throw new Error('native_unavailable'); }
      if (field.kind === 'toggle' && field.value !== 'true' && field.value !== 'false') { throw new Error('native_unavailable'); }
      if (field.kind === 'choice' && !field.choices.some((choice): boolean => choice.value === field.value)) { throw new Error('native_unavailable'); }
      form[field.id] = field.kind === 'toggle' ? field.value === 'true' : field.value;
    }
    if (feature === 'password') {
      const password: string = this.value(fields, 'password');
      if (this.value(fields, 'current_password').length === 0 || password.length < 8 || password.length > 128 || password !== this.value(fields, 'password_confirmation') ||
        password === this.value(fields, 'current_password')) { throw new Error('invalid_password'); }
      await this.request('POST', '/i/account/change_password.json', form, false, generation);
      return await this.load(feature);
    }
    if (feature === 'deactivate') {
      if (this.value(fields, 'current_password').length === 0) { throw new Error('invalid_password'); }
      form['deactivation_timespan'] = '30_days';
      await this.request('POST', '/1.1/account/deactivate.json', form, false, generation);
      return snapshot;
    }
    if (feature === 'username' && !/^[A-Za-z0-9_]{3,15}$/.test(this.value(fields, 'screen_name'))) { throw new Error('invalid_username'); }
    if (feature === 'country' && !/^[A-Za-z]{2}$/.test(this.value(fields, 'country_code'))) { throw new Error('invalid_country'); }
    if (feature === 'age') {
      const year: number = Number(this.value(fields, 'birthdate_year'));
      const month: number = Number(this.value(fields, 'birthdate_month'));
      const day: number = Number(this.value(fields, 'birthdate_day'));
      const date: Date = new Date(year, month - 1, day);
      if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day || date.getTime() > Date.now() || year < 1900) { throw new Error('invalid_date'); }
    }
    if (feature === 'sensitive_categories') {
      const fresh: NativeAccountSnapshot = await this.load(feature);
      this.check(generation);
      const variables: Record<string, Object | null> = { 'userId': xPrivateClient.viewerId() };
      const keys: string[] = ['view_adult_content', 'view_other_content', 'view_violent_content'];
      for (let i: number = 0; i < keys.length; i++) {
        const field: NativeAccountField | undefined = fields.find((item: NativeAccountField): boolean => item.id === keys[i]);
        const value: string = field?.available === true && (keys[i] !== 'view_adult_content' || fresh.data['can_user_allow_sensitive_content'] === true) ?
          field.value : this.string(fresh.data[keys[i]]);
        if (['Warn', 'Allow', 'Drop'].indexOf(value) < 0) { throw new Error('native_unavailable'); }
        variables[keys[i]] = value;
      }
      const data: Record<string, Object | null> = await this.relay('useEditSensitiveMediaSettingsMutation', generation, variables);
      if (data['user_sensitive_media_settings_put'] !== true) { throw new Error('settings_unconfirmed'); }
    } else if (feature === 'delegate') {
      const setting: string = this.value(fields, 'delegation_invitation_preferences');
      if (['Nobody', 'Everyone', 'OnlyFollowing'].indexOf(setting) < 0) { throw new Error('native_unavailable'); }
      const data: Record<string, Object | null> = await this.relay('useDelegateMutation_settings_Mutation', generation,
        { 'userId': xPrivateClient.viewerId(), 'invitationSetting': setting });
      if (data['user_delegation_invitation_preferences_put'] !== true) { throw new Error('settings_unconfirmed'); }
    } else if (feature === 'verified') {
      if (snapshot.data['is_identity_verified'] !== true || form['is_identity_verified_label_hidden'] === undefined) { throw new Error('native_unavailable'); }
      const data: Record<string, Object | null> = await this.relay('IDVerificationUpdateHideLabelMutation', generation,
        { 'user_id': xPrivateClient.viewerId(), 'is_identity_verified_label_hidden': form['is_identity_verified_label_hidden'] ?? null });
      if (data['userverificationinfo_is_identity_verified_label_hidden_put'] !== true) { throw new Error('settings_unconfirmed'); }
    } else if (feature === 'languages' || feature === 'interests') {
      const fresh: Record<string, Object | null> = await this.get('/1.1/account/personalization/p13n_preferences.json', generation);
      const key: string = feature === 'languages' ? 'language_preferences' : 'interest_preferences';
      const preference: Record<string, Object | null> = this.object(fresh[key]);
      const disabledKey: string = feature === 'languages' ? 'disabled_languages' : 'disabled_partner_interests';
      let disabled: string[] = this.strings(preference[disabledKey]);
      for (let i: number = 0; i < fields.length; i++) {
        const field: NativeAccountField = fields[i];
        if (!field.available || field.kind !== 'toggle' || !snapshot.fields.some((item: NativeAccountField): boolean => item.id === field.id)) { continue; }
        const id: string = field.id.substring(field.id.indexOf(':') + 1);
        disabled = disabled.filter((item: string): boolean => item !== id);
        if (field.value === 'false') { disabled.push(id); }
      }
      preference[disabledKey] = disabled;
      const preferences: Record<string, Object | null> = {}; preferences[key] = preference;
      await this.request('POST', '/1.1/account/personalization/p13n_preferences.json', { 'preferences': preferences }, true, generation);
    } else if (feature === 'gender') {
      const preferences: Record<string, Object | null> = this.object(snapshot.data['preferences']);
      const gender: Record<string, Object | null> = this.object(preferences['gender_preferences']);
      const type: string = this.value(fields, 'gender_type');
      if (['male', 'female', 'custom'].indexOf(type) < 0) { throw new Error('native_unavailable'); }
      const value: string = type === 'custom' ? this.value(fields, 'gender_value').trim() : type;
      if (value.length === 0 || value.length > 30) { throw new Error('native_unavailable'); }
      const override: Record<string, Object | null> = { 'type': type, 'value': value };
      gender['gender_override'] = override;
      const genderPreferences: Record<string, Object | null> = { 'gender_preferences': gender };
      await this.request('POST', '/1.1/account/personalization/p13n_preferences.json', { 'preferences': genderPreferences }, true, generation);
    } else if (feature === 'spaces') {
      await this.relay('SharingAudiospacesListeningDataWithFollowersUpdate', generation,
        { 'userId': xPrivateClient.viewerId(), 'sharingAudiospacesListeningDataWithFollowers': form['ext_sharing_audiospaces_listening_data_with_followers'] ?? false });
    } else if (feature === 'parody') {
      if (['None', 'Parody', 'Commentary', 'Fan'].indexOf(this.value(fields, 'parody_commentary_fan_label')) < 0) { throw new Error('native_unavailable'); }
      await this.relay('AccountParodyScreenImplV2ParodyLabelMutation', generation, { 'parodyProfileLabel': this.value(fields, 'parody_commentary_fan_label') });
    } else if (feature === 'ad_categories') {
      const data: Record<string, Object | null> = await this.relay('AdsCategoriesMutation', generation, { 'allowGamblingAds': form['allow_gambling_ads'] ?? false });
      if (data['user_preferences_put'] !== true) { throw new Error('settings_unconfirmed'); }
    } else if (feature === 'search') {
      await this.request('POST', '/1.1/strato/column/User/' + xPrivateClient.viewerId() + '/search/searchSafety', form, true, generation);
    } else if (feature === 'explore') {
      await this.request('POST', '/2/guide/set_explore_settings.json', form, false, generation);
    } else if (feature === 'notification_filters') {
      await this.request('POST', '/1.1/mutes/advanced_filters.json', form, false, generation);
    } else {
      const allowed: string[] = ['username', 'country', 'password_protection', 'discoverability', 'spaces', 'cookie_controls', 'precise_location', 'profile', 'age'];
      if (allowed.indexOf(feature) < 0) { throw new Error('native_unavailable'); }
      await this.request('POST', feature === 'profile' || feature === 'age' ? '/1.1/account/update_profile.json' : '/1.1/account/settings.json', form, false, generation);
    }
    const confirmed: NativeAccountSnapshot = await this.load(feature);
    for (let i: number = 0; i < fields.length; i++) {
      if (!fields[i].available || fields[i].kind === 'password' || fields[i].kind === 'readonly') { continue; }
      if (feature === 'gender' && fields[i].id === 'gender_value' && this.value(fields, 'gender_type') !== 'custom') { continue; }
      if (this.value(confirmed.fields, fields[i].id) !== fields[i].value) { throw new Error('settings_unconfirmed'); }
    }
    return confirmed;
  }

  async keyword(id: string, fields: NativeAccountField[], generation: number): Promise<void> {
    const keyword: string = this.value(fields, 'keyword').trim();
    const home: boolean = this.value(fields, 'home') === 'true';
    const notifications: string = this.value(fields, 'notifications');
    if (keyword.length === 0 || Array.from(keyword).length > 140 || (!home && notifications === 'none')) { throw new Error('invalid_keyword'); }
    const surfaces: string[] = home ? ['home_timeline', 'tweet_replies'] : [];
    if (notifications !== 'none') { surfaces.push('notifications'); }
    const form: Record<string, Object | null> = { 'mute_surfaces': surfaces.join(','),
      'mute_options': notifications === 'following' ? 'exclude_following_accounts' : '' };
    if (this.value(fields, 'duration') !== 'keep') { form['duration'] = this.value(fields, 'duration'); }
    if (id.length > 0) { form['id'] = id; } else { form['keyword'] = keyword; }
    await this.request('POST', id.length > 0 ? '/1.1/mutes/keywords/update.json' : '/1.1/mutes/keywords/create.json', form, false, generation);
    const response: NativeMutedKeywordList = JSON.parse(await this.request('GET', '/1.1/mutes/keywords/list.json', {}, false, generation)) as NativeMutedKeywordList;
    const confirmed = response.muted_keywords?.find((item): boolean => id.length > 0 ? item.id === id : item.keyword.toLowerCase() === keyword.toLowerCase());
    if (confirmed === undefined || surfaces.some((surface: string): boolean => confirmed.mute_surfaces.indexOf(surface) < 0) ||
      confirmed.mute_surfaces.some((surface: string): boolean => surfaces.indexOf(surface) < 0) ||
      (confirmed.mute_options.indexOf('exclude_following_accounts') >= 0) !== (notifications === 'following')) { throw new Error('settings_unconfirmed'); }
  }

  async invite(snapshot: NativeAccountSnapshot, handle: string, role: string): Promise<NativeAccountSnapshot> {
    const generation: number = snapshot.generation;
    this.check(generation);
    if (['Admin', 'Contributor'].indexOf(role) < 0) { throw new Error('native_unavailable'); }
    let userId: string = handle.trim().replace(/^@/, '');
    if (!/^\d+$/.test(userId)) {
      const result: XPrivateResult = await xPrivateClient.userByScreenName(userId);
      this.check(generation);
      const profile: UserProfile | null = result.ok ? XUserParser.parse(result.body) : null;
      if (profile === null) { throw new Error('native_unavailable'); }
      userId = profile.id;
    }
    if (userId.length === 0 || userId === xPrivateClient.viewerId()) { throw new Error('native_unavailable'); }
    const fresh: NativeAccountSnapshot = await this.load('delegate');
    this.check(generation);
    const groupId: string = this.string(fresh.data['delegationGroupId']);
    if (groupId.length === 0) { throw new Error('native_unavailable'); }
    await this.relay('useAddMemberModalMutation_add_Mutation', generation, { 'delegationGroupId': groupId, 'userId': userId, 'selectedRole': role });
    const confirmed: NativeAccountSnapshot = await this.load('delegate');
    if (!confirmed.rows.some((row: NativeAccountRow): boolean => row.targetId === userId && row.role === role)) { throw new Error('settings_unconfirmed'); }
    return confirmed;
  }

  async clearHistory(generation: number): Promise<NativeAccountSnapshot> {
    const data: Record<string, Object | null> = await this.relay('ClearGrokConversations', generation);
    if (data['clear_grok_conversations'] === undefined || data['clear_grok_conversations'] === null ||
      this.object(data['clear_grok_conversations'])['grok_deletion_error'] != null) { throw new Error('settings_unconfirmed'); }
    const confirmed: NativeAccountSnapshot = await this.load('grok_history');
    if (confirmed.rows.length > 0) { throw new Error('settings_unconfirmed'); }
    return confirmed;
  }

  async rowAction(feature: string, row: NativeAccountRow, generation: number): Promise<void> {
    if (feature === 'topics') {
      this.check(generation);
      const data: Record<string, Object | null> = await this.relay('TopicByRestId', generation, { 'topicId': row.id });
      const topic: Record<string, Object | null> = this.object(data['topic']);
      if (this.string(topic['topic_id']) !== row.id || !['topic_follow', 'topic_unfollow', 'topic_ignore', 'topic_restore'].includes(row.action)) { throw new Error('native_unavailable'); }
      const operations: string[] = ['TopicFollow', 'TopicUnfollow', 'TopicNotInterested', 'TopicUndoNotInterested'];
      await this.relay(operations[['topic_follow', 'topic_unfollow', 'topic_ignore', 'topic_restore'].indexOf(row.action)], generation, { 'topicId': row.id });
      const confirmedData: Record<string, Object | null> = await this.relay('TopicByRestId', generation, { 'topicId': row.id });
      const confirmedTopic: Record<string, Object | null> = this.object(confirmedData['topic']);
      const key: string = row.action === 'topic_follow' || row.action === 'topic_unfollow' ? 'following' : 'not_interested';
      if (confirmedTopic[key] !== (row.action === 'topic_follow' || row.action === 'topic_ignore')) { throw new Error('settings_unconfirmed'); }
      return;
    }
    const fresh: NativeAccountSnapshot = await this.load(feature);
    this.check(generation);
    const current: NativeAccountRow | undefined = fresh.rows.find((item: NativeAccountRow): boolean => item.id === row.id);
    if (current === undefined || (row.action === 'delete_keyword' ? feature !== 'muted_words' || current.action !== 'edit_keyword' : current.action !== row.action && current.secondaryAction !== row.action)) { throw new Error('native_unavailable'); }
    if (row.action === 'delete_keyword') { await this.request('POST', '/1.1/mutes/keywords/destroy.json', { 'ids': row.id }, false, generation); }
    else if (row.action === 'disable_2fa_method') { await this.request('POST', '/1.1/account/login_verification/remove_method.json', { 'methodId': row.id }, false, generation); }
    else if (row.action === 'remove_sso') { await this.request('POST', '/1.1/sso/delete_connection', { 'sso_provider': current.value }, false, generation); }
    else if (row.action === 'remove_phone') { await this.request('POST', '/1.1/device/unregister.json', { 'phone_number': current.value }, false, generation); }
    else if (row.action === 'resend_email') { await this.request('POST', '/1.1/account/resend_confirmation_email.json', {}, false, generation); return; }
    else if (row.action === 'remove_chat_device') { await this.request('DELETE', '/1.1/keyregistry/delete/' + encodeURIComponent(row.id), {}, false, generation); }
    else if (row.action === 'disable_automation') { await this.relay('DisableUserAccountLabel', generation); }
    else if (['remove_delegate', 'cancel_delegate', 'leave_delegate', 'reject_delegate', 'accept_delegate'].indexOf(row.action) >= 0) {
      const operations: string[] = ['useMemberMenuMutation_remove_Mutation', 'useMemberMenuMutation_cancel_invite_Mutation', 'GroupMenuMutation', 'InviteMenu_reject_Mutation', 'InviteMenu_accept_Mutation'];
      await this.relay(operations[['remove_delegate', 'cancel_delegate', 'leave_delegate', 'reject_delegate', 'accept_delegate'].indexOf(row.action)], generation,
        { 'membershipId': row.id.startsWith('group:') ? row.value : row.id });
    } else if (row.action === 'change_delegate_role') {
      if (current.role !== 'Admin' && current.role !== 'Contributor') { throw new Error('native_unavailable'); }
      await this.relay('useChangeMemberRoleModalMutation_change_Mutation', generation, { 'userId': row.id, 'selectedRole': current.role === 'Admin' ? 'Contributor' : 'Admin' });
    }
    else { throw new Error('native_unavailable'); }
    const confirmed: NativeAccountSnapshot = await this.load(feature);
    if (row.action === 'change_delegate_role') {
      if (!confirmed.rows.some((item: NativeAccountRow): boolean => item.id === row.id && item.role !== current.role)) { throw new Error('settings_unconfirmed'); }
    } else if (row.action === 'accept_delegate') {
      if (!confirmed.rows.some((item: NativeAccountRow): boolean => item.id === row.id && item.action === 'leave_delegate')) { throw new Error('settings_unconfirmed'); }
    } else if (confirmed.rows.some((item: NativeAccountRow): boolean => item.id === row.id)) { throw new Error('settings_unconfirmed'); }
  }
}

export const nativeAccountService: NativeAccountService = new NativeAccountService();
