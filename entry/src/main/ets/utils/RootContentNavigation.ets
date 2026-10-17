import { NavigationGuard } from './NavigationGuard';

// A selection in the left feed owns one branch in the right pane. Nested
// links within a destination still use the usual push/back navigation.
export class RootContentNavigation {
  static open(stack: NavPathStack, path: NavPathInfo, replaceBranch: boolean,
    matches: (param: Object) => boolean): void {
    if (replaceBranch && stack.size() > 0) {
      const names: string[] = stack.getAllPathName();
      const existing: Object | undefined = stack.getParamByIndex(0) as Object | undefined;
      if (names[0] === path.name && ((existing === undefined && path.param === undefined) ||
        (existing !== undefined && matches(existing)))) {
        if (stack.size() > 1) { stack.popToIndex(0, false); }
        return;
      }
      if (stack.size() > 1) { stack.popToIndex(0, false); }
      stack.replacePath(path, false);
      return;
    }
    NavigationGuard.pushPathMatching(stack, path, matches, !replaceBranch);
  }
}
