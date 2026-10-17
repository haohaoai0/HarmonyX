import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { motion } from '@kit.MultimodalAwarenessKit';

const PREFERENCE_NAME: string = 'harmonyx_fab_preferences';
const LAST_HAND_KEY: string = 'harmonyx_fab_last_hand';
const GRIP_HAND_ENABLED_KEY: string = 'harmonyx_grip_hand_enabled';
const PREFERRED_HAND_KEY: string = 'harmonyx_fab_preferred_hand';

class GripHandSubscriber {
  key: string = '';
  callback: (hand: string) => void = () => {
  };

  constructor(key: string, callback: (hand: string) => void) {
    this.key = key;
    this.callback = callback;
  }
}

/**
 * MiniBeerHall's intelligent-handedness model, scoped to Harmony X's
 * draggable compose button. Unsupported devices simply keep the last side.
 */
export class GripHandManager {
  private static instance: GripHandManager | null = null;
  private lastHand: string = 'right';
  private preferredHand: string = 'right';
  private loadTask: Promise<void> | null = null;
  private gripHandEnabled: boolean = true;
  private subscribed: boolean = false;
  private subscribers: GripHandSubscriber[] = [];
  private motionHandler: ((status: motion.HoldingHandStatus) => void) | null = null;

  private constructor() {
  }

  public static getInstance(): GripHandManager {
    if (GripHandManager.instance === null) {
      GripHandManager.instance = new GripHandManager();
    }
    return GripHandManager.instance;
  }

  public async load(context: common.Context): Promise<void> {
    if (this.loadTask === null) {
      this.loadTask = this.loadPreferences(context);
    }
    await this.loadTask;
  }

  private async loadPreferences(context: common.Context): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCE_NAME);
      const storedHand: preferences.ValueType = await store.get(LAST_HAND_KEY, 'right');
      this.lastHand = storedHand === 'left' ? 'left' : 'right';
      // The legacy last-hand value came from motion, not an explicit preference.
      const storedPreference: preferences.ValueType = await store.get(PREFERRED_HAND_KEY, 'right');
      this.preferredHand = storedPreference === 'left' ? 'left' : 'right';
      const storedEnabled: preferences.ValueType = await store.get(GRIP_HAND_ENABLED_KEY, true);
      this.gripHandEnabled = storedEnabled as boolean;
    } catch (error) {
      this.lastHand = 'right';
      this.preferredHand = 'right';
      this.gripHandEnabled = true;
    }
  }

  public getLastHand(): string {
    return this.gripHandEnabled ? this.lastHand : this.preferredHand;
  }

  public getPreferredHand(): string {
    return this.preferredHand;
  }

  public async savePreferredHand(context: common.Context, hand: string): Promise<void> {
    this.preferredHand = hand === 'left' ? 'left' : 'right';
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCE_NAME);
      await store.put(PREFERRED_HAND_KEY, this.preferredHand);
      await store.flush();
    } catch (error) {
    }
  }

  public isGripHandEnabled(): boolean {
    return this.gripHandEnabled;
  }

  public async saveGripHandEnabled(context: common.Context, enabled: boolean): Promise<void> {
    this.gripHandEnabled = enabled;
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCE_NAME);
      await store.put(GRIP_HAND_ENABLED_KEY, enabled);
      await store.flush();
    } catch (error) {
    }
  }

  public start(onHandChanged: (hand: string) => void): void {
    this.startFor('default', onHandChanged);
  }

  public startFor(key: string, onHandChanged: (hand: string) => void): void {
    this.removeSubscriber(key);
    if (!this.gripHandEnabled) {
      return;
    }
    this.subscribers.push(new GripHandSubscriber(key, onHandChanged));
    if (this.subscribed) {
      return;
    }
    try {
      this.motionHandler = (status: motion.HoldingHandStatus): void => {
        this.onMotionEvent(status);
      };
      motion.on('holdingHandChanged', this.motionHandler);
      this.subscribed = true;
    } catch (error) {
      this.subscribed = false;
      this.motionHandler = null;
      this.removeSubscriber(key);
    }
  }

  public stop(): void {
    this.stopFor('default');
  }

  public stopFor(key: string): void {
    this.removeSubscriber(key);
    if (this.subscribers.length > 0 || !this.subscribed) {
      return;
    }
    if (!this.subscribed) {
      return;
    }
    try {
      motion.off('holdingHandChanged');
    } catch (error) {
    }
    this.subscribed = false;
    this.motionHandler = null;
  }

  private onMotionEvent(status: motion.HoldingHandStatus): void {
    if (!this.gripHandEnabled) {
      return;
    }
    let hand: string = '';
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      hand = 'left';
    } else if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      hand = 'right';
    }
    if (hand.length === 0 || hand === this.lastHand) {
      return;
    }
    this.lastHand = hand;
    for (let index: number = 0; index < this.subscribers.length; index++) {
      this.subscribers[index].callback(hand);
    }
  }

  private removeSubscriber(key: string): void {
    const next: GripHandSubscriber[] = [];
    for (let index: number = 0; index < this.subscribers.length; index++) {
      const subscriber: GripHandSubscriber = this.subscribers[index];
      if (subscriber.key !== key) {
        next.push(subscriber);
      }
    }
    this.subscribers = next;
  }
}
