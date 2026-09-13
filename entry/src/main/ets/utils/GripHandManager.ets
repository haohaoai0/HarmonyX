import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { motion } from '@kit.MultimodalAwarenessKit';

const PREFERENCE_NAME: string = 'harmonyx_fab_preferences';
const LAST_HAND_KEY: string = 'harmonyx_fab_last_hand';
const GRIP_HAND_ENABLED_KEY: string = 'harmonyx_grip_hand_enabled';

/**
 * MiniBeerHall's intelligent-handedness model, scoped to Harmony X's
 * draggable compose button. Unsupported devices simply keep the last side.
 */
export class GripHandManager {
  private static instance: GripHandManager | null = null;
  private lastHand: string = 'right';
  private gripHandEnabled: boolean = true;
  private subscribed: boolean = false;
  private callback: ((hand: string) => void) | null = null;
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
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCE_NAME);
      const storedHand: preferences.ValueType = await store.get(LAST_HAND_KEY, 'right');
      this.lastHand = storedHand as string;
      const storedEnabled: preferences.ValueType = await store.get(GRIP_HAND_ENABLED_KEY, true);
      this.gripHandEnabled = storedEnabled as boolean;
    } catch (error) {
      this.lastHand = 'right';
      this.gripHandEnabled = true;
    }
  }

  public getLastHand(): string {
    return this.lastHand;
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
    this.stop();
    this.callback = onHandChanged;
    try {
      this.motionHandler = (status: motion.HoldingHandStatus): void => {
        this.onMotionEvent(status);
      };
      motion.on('holdingHandChanged', this.motionHandler);
      this.subscribed = true;
    } catch (error) {
      this.subscribed = false;
      this.callback = null;
      this.motionHandler = null;
    }
  }

  public stop(): void {
    if (!this.subscribed) {
      return;
    }
    try {
      motion.off('holdingHandChanged');
    } catch (error) {
    }
    this.subscribed = false;
    this.callback = null;
    this.motionHandler = null;
  }

  public async saveLastHand(context: common.Context, hand: string): Promise<void> {
    this.lastHand = hand;
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, PREFERENCE_NAME);
      await store.put(LAST_HAND_KEY, hand);
      await store.flush();
    } catch (error) {
    }
  }

  private onMotionEvent(status: motion.HoldingHandStatus): void {
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
    if (this.callback !== null) {
      this.callback(hand);
    }
  }
}
