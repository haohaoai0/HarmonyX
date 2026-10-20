import { KeyCode } from '@kit.InputKit';

// Let native editors, buttons and scroll containers handle their own keys first.
// These helpers are used only on the focused input/control, never as key filters.
export function plainInputKey(event: KeyEvent): boolean {
  return event.getModifierKeyState?.(['Ctrl']) !== true &&
    event.getModifierKeyState?.(['Alt']) !== true &&
    event.getModifierKeyState?.(['Shift']) !== true && event.metaKey !== 1;
}

export function submitInputKey(event: KeyEvent, submit: () => void): boolean {
  if ((event.keyCode !== KeyCode.KEYCODE_ENTER && event.keyCode !== KeyCode.KEYCODE_NUMPAD_ENTER) ||
    event.getModifierKeyState?.(['Ctrl']) !== true ||
    event.getModifierKeyState?.(['Alt']) === true ||
    event.getModifierKeyState?.(['Shift']) === true || event.metaKey === 1) { return false; }
  // Consume both phases; submitting on release prevents key-repeat submissions.
  if (event.type === KeyType.Up) { submit(); }
  return true;
}

export function activateInputKey(event: KeyEvent, activate: () => void): boolean {
  if (!plainInputKey(event) || (event.keyCode !== KeyCode.KEYCODE_ENTER &&
    event.keyCode !== KeyCode.KEYCODE_NUMPAD_ENTER && event.keyCode !== KeyCode.KEYCODE_SPACE)) { return false; }
  if (event.type === KeyType.Up) { activate(); }
  return true;
}

export function backInputKey(event: KeyEvent, back: () => void): boolean {
  // Escape already goes through ArkUI's native back dispatch. Handling its
  // release here can pop the newly revealed destination a second time.
  const altLeft: boolean = event.keyCode === KeyCode.KEYCODE_DPAD_LEFT &&
    event.getModifierKeyState?.(['Alt']) === true &&
    event.getModifierKeyState?.(['Ctrl']) !== true && event.getModifierKeyState?.(['Shift']) !== true &&
    event.metaKey !== 1;
  if (!altLeft) { return false; }
  if (event.type === KeyType.Down) { back(); }
  return true;
}

export function contextInputMouse(event: MouseEvent, open: () => void): void {
  if (event.button !== MouseButton.Right) { return; }
  event.stopPropagation();
  if (event.action === MouseAction.Release) { open(); }
}
