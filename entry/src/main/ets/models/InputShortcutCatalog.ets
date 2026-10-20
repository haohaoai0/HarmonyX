export class InputShortcut {
  id: string;
  key: string | FunctionKey;
  modifiers: ModifierKey[];
  keys: Resource;
  label: Resource;

  constructor(id: string, key: string | FunctionKey, modifiers: ModifierKey[], keys: Resource, label: Resource) {
    this.id = id;
    this.key = key;
    this.modifiers = modifiers;
    this.keys = keys;
    this.label = label;
  }
}

// The main page and the help destination share this catalog.
export const ROOT_INPUT_SHORTCUTS: InputShortcut[] = [
  new InputShortcut('home', '1', [ModifierKey.CTRL], $r('app.string.input_key_home'), $r('app.string.home_title')),
  new InputShortcut('explore', '2', [ModifierKey.CTRL], $r('app.string.input_key_explore'), $r('app.string.explore_title')),
  new InputShortcut('notifications', '3', [ModifierKey.CTRL], $r('app.string.input_key_notifications'), $r('app.string.tab_alerts')),
  new InputShortcut('messages', '4', [ModifierKey.CTRL], $r('app.string.input_key_messages'), $r('app.string.chat_title')),
  new InputShortcut('profile', '5', [ModifierKey.CTRL], $r('app.string.input_key_profile'), $r('app.string.side_profile')),
  new InputShortcut('search', 'k', [ModifierKey.CTRL], $r('app.string.input_key_search'), $r('app.string.search_action')),
  new InputShortcut('compose', 'n', [ModifierKey.CTRL], $r('app.string.input_key_compose'), $r('app.string.input_compose')),
  new InputShortcut('refresh', 'r', [ModifierKey.CTRL], $r('app.string.input_key_refresh'), $r('app.string.input_refresh')),
  new InputShortcut('settings', ',', [ModifierKey.CTRL], $r('app.string.input_key_settings'), $r('app.string.settings_title')),
  new InputShortcut('help', FunctionKey.F1, [], $r('app.string.input_key_help'), $r('app.string.input_help_title'))
];
