// Traditional Chinese colours use a stable theme id, a single swatch colour,
// and separate light/dark accents.  The tint is ARGB rather than CSS RGBA so
// it can be passed directly to ArkUI colour APIs.
export class AccentPaletteEntry {
  id: string;
  common: string;
  light: string;
  dark: string;
  tint: string;

  constructor(id: string, common: string, light: string, dark: string, tint: string) {
    this.id = id;
    this.common = common;
    this.light = light;
    this.dark = dark;
    this.tint = tint;
  }
}

export const TRADITIONAL_ACCENT_PALETTE: AccentPaletteEntry[] = [
  new AccentPaletteEntry('cinnabar', '#DC3B2A', '#B82818', '#FF7366', '#26DC3B2A'),
  new AccentPaletteEntry('vermilion', '#D95829', '#B33E14', '#FF936B', '#26D95829'),
  new AccentPaletteEntry('amber', '#B86B11', '#915006', '#F5B056', '#26B86B11'),
  new AccentPaletteEntry('autumn_bamboo', '#7D8518', '#5F660D', '#C7D156', '#267D8518'),
  new AccentPaletteEntry('bamboo_green', '#1E8A5E', '#136E48', '#5CE0AA', '#261E8A5E'),
  new AccentPaletteEntry('azurite', '#147D8F', '#0D6170', '#59CFE3', '#26147D8F'),
  new AccentPaletteEntry('cloisonne', '#226CE0', '#1752B3', '#78B0FF', '#26226CE0'),
  new AccentPaletteEntry('indigo', '#4B5CC4', '#36449E', '#94A6FF', '#264B5CC4'),
  new AccentPaletteEntry('begonia', '#7A49B8', '#5E3296', '#C094FF', '#267A49B8'),
  new AccentPaletteEntry('rouge', '#C43668', '#9E224E', '#FF85AE', '#26C43668'),
  new AccentPaletteEntry('sandalwood', '#8C6354', '#6E4B3E', '#CFA291', '#268C6354'),
  new AccentPaletteEntry('mountain', '#636F7A', '#48525C', '#9EADB8', '#26636F7A')
];

// Representative colors sampled from the colorful app icons in the Huawei
// launcher reference. Each entry keeps the vivid icon color as its swatch,
// while using a readable light/dark accent for actual controls.
export const ICON_ACCENT_PALETTE: AccentPaletteEntry[] = [
  new AccentPaletteEntry('icon_blue', '#0B77FD', '#075BC8', '#72B0FF', '#260B77FD'),
  new AccentPaletteEntry('icon_red', '#F0243C', '#C3182D', '#FF788C', '#26F0243C'),
  new AccentPaletteEntry('icon_orange', '#F88008', '#C85E00', '#FFB15A', '#26F88008'),
  new AccentPaletteEntry('icon_yellow', '#F8D040', '#A57200', '#FFE38A', '#26F8D040'),
  new AccentPaletteEntry('icon_green', '#10B868', '#087D47', '#59E5A1', '#2610B868'),
  new AccentPaletteEntry('icon_pink', '#F86898', '#C53668', '#FFAAC7', '#26F86898'),
  new AccentPaletteEntry('icon_cyan', '#18B8D0', '#007E99', '#64D9EB', '#2618B8D0'),
  new AccentPaletteEntry('icon_navy', '#243878', '#1A2A5E', '#8EA8FF', '#26243878')
];

// Stable ids share the existing appearance preference. Primary colours mirror
// their resources because the application-wide accent contract is a hex string.
export const MIXED_ACCENT_PALETTE: AccentPaletteEntry[] = [
  new AccentPaletteEntry('mix_candy', '#FF8FB1', '#A73760', '#FFACCD', '#26FF8FB1'),
  new AccentPaletteEntry('mix_sky', '#76BEFF', '#2465AC', '#9AD0FF', '#2676BEFF'),
  new AccentPaletteEntry('mix_peach', '#FF9A9F', '#A34450', '#FFB0BA', '#26FF9A9F'),
  new AccentPaletteEntry('mix_lilac', '#BDA2F3', '#7050A6', '#CEB2FF', '#26BDA2F3'),
  new AccentPaletteEntry('mix_confetti', '#2864C8', '#2864C8', '#82B1FF', '#262864C8'),
  new AccentPaletteEntry('mix_coast', '#16717D', '#16717D', '#70D1D5', '#2616717D'),
  new AccentPaletteEntry('mix_sunset', '#7352AD', '#7352AD', '#C4A0F4', '#267352AD'),
  new AccentPaletteEntry('mix_forest', '#376A50', '#376A50', '#8DD1A5', '#26376A50'),
  new AccentPaletteEntry('mix_berry', '#A13E68', '#A13E68', '#F2A0C4', '#26A13E68'),
  new AccentPaletteEntry('mix_morandi', '#596C86', '#596C86', '#B0C2DC', '#26596C86')
];

export function isMixedAccentTheme(theme: string): boolean {
  return MIXED_ACCENT_PALETTE.some((entry: AccentPaletteEntry): boolean => entry.id === theme);
}

// Resources select light/dark variants through the existing application colour
// mode. Page roles stay stable when tabs are reordered, hidden, or mirrored.
export function mixedAccentRoleColor(theme: string, role: string, fallback: ResourceColor): ResourceColor {
  let colors: ResourceColor[] = [];
  if (theme === 'mix_confetti') {
    colors = [
      $r('app.color.mix_confetti_primary'), $r('app.color.mix_confetti_action'), $r('app.color.mix_confetti_home'),
      $r('app.color.mix_confetti_explore'), $r('app.color.mix_confetti_notifications'), $r('app.color.mix_confetti_messages'),
      $r('app.color.mix_confetti_profile'), $r('app.color.mix_confetti_on_action'), $r('app.color.mix_confetti_control'),
      $r('app.color.mix_confetti_surface'), $r('app.color.mix_confetti_ink'), $r('app.color.mix_confetti_on_control')
    ];
  } else if (theme === 'mix_candy') {
    colors = [
      $r('app.color.mix_candy_primary'), $r('app.color.mix_candy_action'), $r('app.color.mix_candy_home'),
      $r('app.color.mix_candy_explore'), $r('app.color.mix_candy_notifications'), $r('app.color.mix_candy_messages'),
      $r('app.color.mix_candy_profile'), $r('app.color.mix_candy_on_action'), $r('app.color.mix_candy_control'),
      $r('app.color.mix_candy_surface'), $r('app.color.mix_candy_ink'), $r('app.color.mix_candy_on_control')
    ];
  } else if (theme === 'mix_sky') {
    colors = [
      $r('app.color.mix_sky_primary'), $r('app.color.mix_sky_action'), $r('app.color.mix_sky_home'),
      $r('app.color.mix_sky_explore'), $r('app.color.mix_sky_notifications'), $r('app.color.mix_sky_messages'),
      $r('app.color.mix_sky_profile'), $r('app.color.mix_sky_on_action'), $r('app.color.mix_sky_control'),
      $r('app.color.mix_sky_surface'), $r('app.color.mix_sky_ink'), $r('app.color.mix_sky_on_control')
    ];
  } else if (theme === 'mix_peach') {
    colors = [
      $r('app.color.mix_peach_primary'), $r('app.color.mix_peach_action'), $r('app.color.mix_peach_home'),
      $r('app.color.mix_peach_explore'), $r('app.color.mix_peach_notifications'), $r('app.color.mix_peach_messages'),
      $r('app.color.mix_peach_profile'), $r('app.color.mix_peach_on_action'), $r('app.color.mix_peach_control'),
      $r('app.color.mix_peach_surface'), $r('app.color.mix_peach_ink'), $r('app.color.mix_peach_on_control')
    ];
  } else if (theme === 'mix_lilac') {
    colors = [
      $r('app.color.mix_lilac_primary'), $r('app.color.mix_lilac_action'), $r('app.color.mix_lilac_home'),
      $r('app.color.mix_lilac_explore'), $r('app.color.mix_lilac_notifications'), $r('app.color.mix_lilac_messages'),
      $r('app.color.mix_lilac_profile'), $r('app.color.mix_lilac_on_action'), $r('app.color.mix_lilac_control'),
      $r('app.color.mix_lilac_surface'), $r('app.color.mix_lilac_ink'), $r('app.color.mix_lilac_on_control')
    ];
  } else if (theme === 'mix_coast') {
    colors = [$r('app.color.mix_coast_primary'), $r('app.color.mix_coast_action'),
      $r('app.color.mix_coast_home'), $r('app.color.mix_coast_explore'),
      $r('app.color.mix_coast_notifications'), $r('app.color.mix_coast_messages'), $r('app.color.mix_coast_profile')];
  } else if (theme === 'mix_sunset') {
    colors = [$r('app.color.mix_sunset_primary'), $r('app.color.mix_sunset_action'),
      $r('app.color.mix_sunset_home'), $r('app.color.mix_sunset_explore'),
      $r('app.color.mix_sunset_notifications'), $r('app.color.mix_sunset_messages'), $r('app.color.mix_sunset_profile')];
  } else if (theme === 'mix_forest') {
    colors = [$r('app.color.mix_forest_primary'), $r('app.color.mix_forest_action'),
      $r('app.color.mix_forest_home'), $r('app.color.mix_forest_explore'),
      $r('app.color.mix_forest_notifications'), $r('app.color.mix_forest_messages'), $r('app.color.mix_forest_profile')];
  } else if (theme === 'mix_berry') {
    colors = [$r('app.color.mix_berry_primary'), $r('app.color.mix_berry_action'),
      $r('app.color.mix_berry_home'), $r('app.color.mix_berry_explore'),
      $r('app.color.mix_berry_notifications'), $r('app.color.mix_berry_messages'), $r('app.color.mix_berry_profile')];
  } else if (theme === 'mix_morandi') {
    colors = [$r('app.color.mix_morandi_primary'), $r('app.color.mix_morandi_action'),
      $r('app.color.mix_morandi_home'), $r('app.color.mix_morandi_explore'),
      $r('app.color.mix_morandi_notifications'), $r('app.color.mix_morandi_messages'), $r('app.color.mix_morandi_profile')];
  }
  const roles: string[] = ['primary', 'action', 'home', 'explore', 'notifications', 'messages', 'profile',
    'on_action', 'control', 'surface', 'ink', 'on_control'];
  const index: number = roles.indexOf(role);
  return index >= 0 && index < colors.length ? colors[index] : fallback;
}

export function accentPageRole(page: number): string {
  const roles: string[] = ['home', 'explore', 'notifications', 'messages', 'profile'];
  return page >= 0 && page < roles.length ? roles[page] : 'primary';
}

function paletteEntry(theme: string): AccentPaletteEntry | null {
  for (let i = 0; i < TRADITIONAL_ACCENT_PALETTE.length; i++) {
    const entry: AccentPaletteEntry = TRADITIONAL_ACCENT_PALETTE[i];
    if (entry.id === theme || entry.common === theme || entry.light === theme || entry.dark === theme) {
      return entry;
    }
  }
  for (let i = 0; i < ICON_ACCENT_PALETTE.length; i++) {
    const entry: AccentPaletteEntry = ICON_ACCENT_PALETTE[i];
    if (entry.id === theme || entry.common === theme || entry.light === theme || entry.dark === theme) {
      return entry;
    }
  }
  for (let i = 0; i < MIXED_ACCENT_PALETTE.length; i++) {
    if (MIXED_ACCENT_PALETTE[i].id === theme) { return MIXED_ACCENT_PALETTE[i]; }
  }
  return null;
}

// Accept both the stable id and an old saved light/common hex so preferences
// created before the palette was introduced keep working.
export function canonicalAccentTheme(theme: string): string {
  const entry: AccentPaletteEntry | null = paletteEntry(theme);
  return entry === null ? theme : entry.id;
}

export function isKnownAccentTheme(theme: string): boolean {
  return paletteEntry(theme) !== null || theme.length === 7;
}

export function resolveAccentColor(theme: string, dark: boolean): string {
  const entry: AccentPaletteEntry | null = paletteEntry(theme);
  if (entry === null) {
    return theme;
  }
  return dark ? entry.dark : entry.light;
}

export function accentSwatchColor(theme: string): string {
  const entry: AccentPaletteEntry | null = paletteEntry(theme);
  return entry === null ? theme : entry.common;
}

export function accentTintColor(theme: string): string {
  const entry: AccentPaletteEntry | null = paletteEntry(theme);
  if (entry !== null) {
    return entry.tint;
  }
  return theme.length === 7 ? '#26' + theme.substring(1) : '#00000000';
}

export function accentUsesDarkMode(displayMode: string, systemDark: boolean): boolean {
  if (displayMode === 'dark') {
    return true;
  }
  if (displayMode === 'light') {
    return false;
  }
  return systemDark;
}
