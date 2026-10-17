import util from '@ohos.util';
import { xPrivateClient } from './XPrivateClient';

export class ImmersiveEventNamespace {
  client: string = 'm5';
  page: string = 'gallery';
  section: string = 'immersive';
  component: string = '';
  action: string = '';
}

export class ImmersiveEventDetails {
  session_id: string = '';
  immersive_session_card_index?: number;
}

export class ImmersiveEventItem {
  id: string = '';
  immersive_details: ImmersiveEventDetails = new ImmersiveEventDetails();
}

export class ImmersiveClientEvent {
  _category_: string = 'client_event';
  format_version: number = 2;
  client_app_id: string = '3033300';
  triggered_on: number = 0;
  client_event_sequence_start_timestamp: number = 0;
  client_event_sequence_number: number = 0;
  event_namespace: ImmersiveEventNamespace = new ImmersiveEventNamespace();
  immersive_details: ImmersiveEventDetails = new ImmersiveEventDetails();
  items?: ImmersiveEventItem[];
}

// The official gallery/immersive namespace, session/card details, event
// envelope and flow/timeline form transport come from the captured web client.
export class VideoViewingSession {
  private id: string = util.generateRandomUUID();
  private startedAt: number = Date.now();
  private sequence: number = 0;
  private generation: number = xPrivateClient.sessionGeneration();
  private events: ImmersiveClientEvent[] = [];
  private timer: number = -1;
  private closed: boolean = false;
  private previousIndex: number = -1;
  private previousTweetId: string = '';

  constructor() { this.record('impression'); }

  viewed(tweetId: string, index: number): void {
    if (this.closed || tweetId === this.previousTweetId && index === this.previousIndex) { return; }
    if (this.previousIndex >= 0 && index !== this.previousIndex) {
      this.record(index > this.previousIndex ? 'next' : 'previous', tweetId, index, 'feed');
    }
    this.record('impression', tweetId, index);
    this.previousIndex = index; this.previousTweetId = tweetId;
  }

  private record(action: string, tweetId: string = '', index: number = -1, component: string = ''): void {
    if (this.generation !== xPrivateClient.sessionGeneration()) { this.events = []; return; }
    const event: ImmersiveClientEvent = new ImmersiveClientEvent();
    event.triggered_on = Date.now(); event.client_event_sequence_start_timestamp = this.startedAt;
    event.client_event_sequence_number = this.sequence++;
    event.event_namespace.action = action; event.event_namespace.component = component;
    event.immersive_details.session_id = this.id;
    if (tweetId.length > 0) {
      const item: ImmersiveEventItem = new ImmersiveEventItem();
      item.id = tweetId; item.immersive_details.session_id = this.id;
      item.immersive_details.immersive_session_card_index = index;
      event.items = [item];
    }
    this.events.push(event);
    if (this.timer < 0) { this.timer = setTimeout((): void => { this.timer = -1; this.flush(); }, 3000); }
  }

  flush(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    const events: ImmersiveClientEvent[] = this.events.splice(0);
    if (events.length === 0 || this.generation !== xPrivateClient.sessionGeneration()) { return; }
    // Telemetry never controls playback/pagination and never crosses accounts.
    void xPrivateClient.immersiveVideoEvents(events, this.generation).catch((): void => {});
  }

  close(): void {
    if (this.closed) { return; }
    this.closed = true; this.record('navigate'); this.flush();
  }
}
