// Reuse a destination only when both its route and content identity match.
export class NavigationGuard {
  public static pushPath<T>(pageStack: NavPathStack, info: NavPathInfo,
    identity: (param: T) => string): void {
    const names: string[] = pageStack.getAllPathName();
    const targetIdentity: string = identity(info.param as T);
    for (let index: number = names.length - 1; index >= 0; index--) {
      if (names[index] !== info.name) {
        continue;
      }
      const current: T | undefined = pageStack.getParamByIndex(index) as T | undefined;
      if (current !== undefined && identity(current) === targetIdentity) {
        if (index < names.length - 1) {
          pageStack.popToIndex(index);
        }
        return;
      }
    }
    pageStack.pushPath(info);
  }
}
