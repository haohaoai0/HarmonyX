import { curves } from '@kit.ArkUI';

// One place to tune shared-element timing. Select one curve below at build time.
export const SHARED_ELEMENT_DURATION: number = 380;
export const SHARED_ELEMENT_AGILE = curves.interpolatingSpring(0, 1.4, 200, 20);
export const SHARED_ELEMENT_BALANCED = curves.springMotion();
export const SHARED_ELEMENT_ELEGANT = curves.interpolatingSpring(0, 0.5, 167, 30);
export const SHARED_ELEMENT_CURVE = SHARED_ELEMENT_ELEGANT;

// Row-to-page expansion, still used by the reply rows on the post page: the
// tapped row follows the destination page, and the row announces the press
// before the page pushes. Spring parameters match the official
// transitions-collection sample (ListLongTakeTransition). Every other post
// entry point uses the platform's own page transition instead.
export const LIST_ITEM_PRESS_CURVE = curves.interpolatingSpring(0, 1, 350, 35);
export const LIST_ITEM_PRESS_SCALE: number = 0.95;
export const LIST_EXPAND_PUSH_CURVE = curves.interpolatingSpring(0, 1, 328, 36);
export const LIST_EXPAND_BACK_CURVE = curves.interpolatingSpring(0, 1, 342, 38);
