// Reuse a destination only when both its route and content identity match.
export class NavigationGuard {
  // A desktop category owns one root branch. Re-selecting it returns to the
  // existing root; selecting another category replaces that branch.
  public static selectRootPathMatching(pageStack: NavPathStack, info: NavPathInfo,
    matches: (param: Object) => boolean, animated: boolean = true): void {
    const names: string[] = pageStack.getAllPathName();
    if (names.length > 0 && names[0] === info.name) {
      const current: Object | undefined = pageStack.getParamByIndex(0) as Object | undefined;
      if ((current === undefined && info.param === undefined) || (current !== undefined && matches(current))) {
        if (names.length > 1) { pageStack.popToIndex(0, animated); }
        return;
      }
    }
    pageStack.clear(false);
    pageStack.pushPath(info, animated);
  }

  public static pushPath<T>(pageStack: NavPathStack, info: NavPathInfo,
    identity: (param: T) => string, animated: boolean = true): void {
    const targetIdentity: string = identity(info.param as T);
    NavigationGuard.pushPathMatching(pageStack, info,
      (param: Object): boolean => identity(param as T) === targetIdentity, animated);
  }

  public static pushPathMatching(pageStack: NavPathStack, info: NavPathInfo,
    matches: (param: Object) => boolean, animated: boolean = true): void {
    const names: string[] = pageStack.getAllPathName();
    for (let index: number = names.length - 1; index >= 0; index--) {
      if (names[index] !== info.name) {
        continue;
      }
      const current: Object | undefined = pageStack.getParamByIndex(index) as Object | undefined;
      if ((current === undefined && info.param === undefined) || (current !== undefined && matches(current))) {
        if (index < names.length - 1) {
          pageStack.popToIndex(index, animated);
        }
        return;
      }
    }
    pageStack.pushPath(info, animated);
  }
}
