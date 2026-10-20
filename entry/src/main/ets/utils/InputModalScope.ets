export const STORAGE_KEY_INPUT_MODAL_BLOCKED: string = 'harmonyx.input_modal_blocked';
let nextInputModalScope: number = 0;
const inputModalScopes: Set<number> = new Set<number>();

// A cached row owns its own lease. Closing one of several open surfaces must
// not enable main-page shortcuts until the last modal has released focus.
export class InputModalScope {
  private id: number = 0;

  constructor() {
    nextInputModalScope += 1;
    this.id = nextInputModalScope;
  }

  setActive(active: boolean): void {
    if (active) { inputModalScopes.add(this.id); }
    else { inputModalScopes.delete(this.id); }
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_INPUT_MODAL_BLOCKED, inputModalScopes.size > 0);
  }
}
