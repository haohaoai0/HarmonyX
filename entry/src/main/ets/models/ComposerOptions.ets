// Serializable choices shared by the editor, local drafts and request builders.
export class ComposerOptions {
  pollChoices: string[] = [];
  pollImages: string[] = [];
  pollDurationMinutes: number = 1440;
  scheduledAt: number = 0;
  replyMode: string = '';
  placeId: string = '';
  placeName: string = '';
  geoSearchRequestId: string = '';
  paidPartnership: boolean = false;
  madeWithAi: boolean = false;

  copy(): ComposerOptions {
    const next: ComposerOptions = new ComposerOptions();
    next.pollChoices = this.pollChoices.slice();
    next.pollImages = this.pollImages.slice();
    next.pollDurationMinutes = this.pollDurationMinutes;
    next.scheduledAt = this.scheduledAt;
    next.replyMode = this.replyMode;
    next.placeId = this.placeId;
    next.placeName = this.placeName;
    next.geoSearchRequestId = this.geoSearchRequestId;
    next.paidPartnership = this.paidPartnership;
    next.madeWithAi = this.madeWithAi;
    return next;
  }

  hasSettings(): boolean {
    return this.pollChoices.length > 0 || this.scheduledAt > 0 || this.replyMode.length > 0 ||
      this.placeId.length > 0 || this.paidPartnership || this.madeWithAi;
  }

  pollValid(): boolean {
    if (this.pollChoices.length === 0) { return true; }
    return this.pollChoices.length >= 2 && this.pollChoices.length <= 4 &&
      this.pollChoices.every((choice: string): boolean =>
        choice.trim().length > 0 && Array.from(choice).length <= 25) &&
      Number.isInteger(this.pollDurationMinutes) && this.pollDurationMinutes >= 5 &&
      this.pollDurationMinutes <= 10080;
  }

  needsWebSession(): boolean {
    return this.scheduledAt > 0 || this.replyMode === 'MyNetwork' ||
      this.pollImages.some((uri: string): boolean => uri.length > 0);
  }

  static restore(value: string): ComposerOptions {
    const options: ComposerOptions = new ComposerOptions();
    try {
      const raw: ComposerOptions = JSON.parse(value) as ComposerOptions;
      if (Array.isArray(raw.pollChoices)) {
        options.pollChoices = raw.pollChoices.filter((choice: string): boolean => typeof choice === 'string').slice(0, 4);
      }
      if (Array.isArray(raw.pollImages)) {
        options.pollImages = raw.pollImages.map((uri: string): string => typeof uri === 'string' ? uri : '')
          .slice(0, options.pollChoices.length);
      }
      if (Number.isInteger(raw.pollDurationMinutes)) { options.pollDurationMinutes = raw.pollDurationMinutes; }
      if (Number.isFinite(raw.scheduledAt) && raw.scheduledAt > 0) { options.scheduledAt = raw.scheduledAt; }
      if (['', 'Verified', 'Community', 'ByInvitation', 'MyNetwork'].indexOf(raw.replyMode) >= 0) {
        options.replyMode = raw.replyMode;
      }
      if (typeof raw.placeId === 'string') { options.placeId = raw.placeId; }
      if (typeof raw.placeName === 'string') { options.placeName = raw.placeName; }
      if (typeof raw.geoSearchRequestId === 'string') { options.geoSearchRequestId = raw.geoSearchRequestId; }
      options.paidPartnership = raw.paidPartnership === true;
      options.madeWithAi = raw.madeWithAi === true;
    } catch (error) {}
    return options;
  }
}

export interface ComposerPlace { id: string; name: string; full_name: string; country: string; geoSearchRequestId: string; }
export class ComposerCoordinates {
  latitude: number = 0;
  longitude: number = 0;
  accuracy: number = 0;
}
export interface ComposerScheduledPost { id: string; text: string; executeAt: number; }

export function replyModeLabel(mode: string): Resource {
  if (mode === 'Verified') { return $r('app.string.compose_reply_verified'); }
  if (mode === 'Community') { return $r('app.string.compose_reply_following'); }
  if (mode === 'ByInvitation') { return $r('app.string.compose_reply_mentioned'); }
  if (mode === 'MyNetwork') { return $r('app.string.compose_reply_network'); }
  return $r('app.string.compose_reply_everyone');
}
