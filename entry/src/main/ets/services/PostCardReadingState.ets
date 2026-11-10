// Owned by the detail visit, rather than the lifetime of a lazy comment cell.
// Only reading choices survive leaving the viewport; native media is released.
export class PostCardReadingState {
  owner: number = 0;
  textExpanded: boolean = false;
  qualityExpanded: boolean = false;
  qualityShowingReasons: boolean = false;
  photoPageIndex: number = 0;
  mediaOffsets: Map<number, number> = new Map();
  translatedText: string = '';
  showingOriginal: boolean = false;
  translationWasAutomatic: boolean = false;
  translationRevision: number = -1;
  appLocale: string = '';
  accountRevision: number = -1;
}
