export class SpaceParticipant {
  id: string = '';
  name: string = '';
  username: string = '';
  avatarUrl: string = '';
  description: string = '';
  verified: boolean = false;
  verifiedType: string = '';
  avatarShape: string = '';
  protected: boolean = false;
  role: string = 'listener';
  muted: boolean | undefined = undefined;
}

export class SpaceRoom {
  id: string = '';
  title: string = '';
  state: string = '';
  mediaKey: string = '';
  participantCount: number = 0;
  scheduledStart: number = 0;
  startedAt: number = 0;
  endedAt: number = 0;
  replayCount: number = 0;
  totalListenerCount: number = 0;
  replayAvailable: boolean = false;
  host: SpaceParticipant = new SpaceParticipant();
  participants: SpaceParticipant[] = [];

  isLive(): boolean { return this.state.toLowerCase() === 'running' || this.state.toLowerCase() === 'live'; }
  isScheduled(): boolean {
    const state: string = this.state.toLowerCase().replace(/_/g, '');
    return state === 'notstarted' || state === 'scheduled' || state === 'prepublished';
  }
  canListen(): boolean {
    return this.mediaKey.length > 0 && (this.isLive() || (!this.isScheduled() && this.replayAvailable));
  }
}

export class SpacePresence {
  spaceId: string = '';
  role: string = '';
}

export class SpaceUserPresence {
  userId: string = '';
  spaceId: string = '';
}

export class SpacePresencePage {
  users: SpaceUserPresence[] = [];
  refreshAfterMs: number = 30000;
}

export interface SpaceRouteParam { spaceId: string; room?: SpaceRoom; }

export interface SpaceInfoRouteParam { kind: string; room?: SpaceRoom; listenAfter?: boolean; }
