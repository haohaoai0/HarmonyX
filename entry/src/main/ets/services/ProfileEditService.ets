import { UserProfile } from '../models/Tweet';
import { xPrivateClient, XPrivateResult } from './XPrivateClient';
import { XUserParser } from './XUserParser';

export const STORAGE_KEY_EDITED_PROFILE: string = 'harmonyx.edited_profile';
let latestEditedProfile: UserProfile | null = null;

export function lastEditedProfile(): UserProfile | null { return latestEditedProfile; }

// Separate from account-switch notifications: editing a name must not reset feeds.
export function publishEditedProfile(profile: UserProfile): void {
  latestEditedProfile = profile;
  AppStorage.setOrCreate<number>(STORAGE_KEY_EDITED_PROFILE,
    (AppStorage.get<number>(STORAGE_KEY_EDITED_PROFILE) ?? 0) + 1);
}

export class ProfileEditDraft {
  profile: UserProfile;
  name: string;
  bio: string;
  location: string;
  website: string;
  avatarUri: string = '';
  bannerUri: string = '';
  avatarApplied: boolean = false;
  bannerApplied: boolean = false;
  awaitingRefresh: boolean = false;

  constructor(profile: UserProfile) {
    this.profile = profile;
    this.name = profile.name;
    this.bio = profile.description;
    this.location = profile.location ?? '';
    this.website = profile.website ?? '';
  }

  textChanged(): boolean {
    return this.name.trim() !== this.profile.name || this.bio !== this.profile.description ||
      this.location !== (this.profile.location ?? '') || this.website !== (this.profile.website ?? '');
  }

  hasChanges(): boolean {
    return this.textChanged() || (this.avatarUri.length > 0 && !this.avatarApplied) ||
      (this.bannerUri.length > 0 && !this.bannerApplied) || this.awaitingRefresh;
  }

  normalizedWebsite(): string {
    const url: string = this.website.trim();
    return url.length > 0 && !/^[A-Za-z][A-Za-z0-9+.-]*:/.test(url) ? 'https://' + url : url;
  }

  valid(): boolean {
    return this.name.trim().length > 0 && Array.from(this.name.trim()).length <= 50 &&
      Array.from(this.bio).length <= 160 && Array.from(this.location).length <= 30 && this.website.length <= 100 &&
      (this.website.trim().length === 0 || /^https?:\/\/[^\s/:]+(?::[0-9]+)?(?:[/?#][^\s]*)?$/i.test(this.normalizedWebsite()));
  }
}

export class ProfileEditService {
  private check(draft: ProfileEditDraft, generation: number): void {
    if (!xPrivateClient.isSignedIn() || xPrivateClient.sessionGeneration() !== generation ||
      xPrivateClient.viewerId() !== draft.profile.id) { throw new Error('account_changed'); }
  }

  private accepted(result: XPrivateResult): void {
    if (!result.ok) { throw new Error('profile_save_failed'); }
  }

  async save(draft: ProfileEditDraft, generation: number): Promise<UserProfile> {
    this.check(draft, generation);
    if (!draft.valid()) { throw new Error('invalid_profile'); }
    if (draft.textChanged()) {
      const form: Record<string, Object | null> = { 'name': draft.name.trim(), 'description': draft.bio,
        'location': draft.location, 'url': draft.normalizedWebsite() };
      this.accepted(await xPrivateClient.accountManagementRequest('POST', '/1.1/account/update_profile.json', form, false, generation));
      this.check(draft, generation);
      // Remember acknowledged steps so a partial failure never resubmits them.
      draft.profile = JSON.parse(JSON.stringify(draft.profile)) as UserProfile;
      draft.profile.name = draft.name.trim(); draft.profile.description = draft.bio;
      draft.profile.location = draft.location; draft.profile.website = draft.website;
      draft.awaitingRefresh = true;
      publishEditedProfile(draft.profile);
    }
    if (draft.avatarUri.length > 0 && !draft.avatarApplied) {
      this.check(draft, generation);
      this.accepted(await xPrivateClient.updateProfilePhoto(draft.avatarUri, false, generation));
      this.check(draft, generation);
      draft.avatarApplied = true; draft.awaitingRefresh = true;
    }
    if (draft.bannerUri.length > 0 && !draft.bannerApplied) {
      this.check(draft, generation);
      this.accepted(await xPrivateClient.updateProfilePhoto(draft.bannerUri, true, generation));
      this.check(draft, generation);
      draft.bannerApplied = true; draft.awaitingRefresh = true;
    }
    this.check(draft, generation);
    const result: XPrivateResult = await xPrivateClient.userByRestId(draft.profile.id, true);
    this.check(draft, generation);
    const fresh: UserProfile | null = result.ok ? XUserParser.parse(result.body) : null;
    if (fresh === null || fresh.id !== draft.profile.id) { throw new Error('profile_refresh_failed'); }
    draft.profile = fresh;
    draft.name = fresh.name; draft.bio = fresh.description;
    draft.location = fresh.location ?? ''; draft.website = fresh.website ?? '';
    draft.avatarUri = ''; draft.bannerUri = ''; draft.avatarApplied = false; draft.bannerApplied = false;
    draft.awaitingRefresh = false;
    publishEditedProfile(fresh);
    return fresh;
  }
}

export const profileEditService: ProfileEditService = new ProfileEditService();
