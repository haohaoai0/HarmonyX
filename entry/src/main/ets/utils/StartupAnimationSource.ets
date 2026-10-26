// The default artwork is product identity; every alternate selection has the
// same mapping in both products. Keep the supplied filenames intact.
export function startupAnimationName(iconName: string, dark: boolean, bundleName: string): string {
  const suffix: string = dark ? '_dark' : '_light';
  switch (iconName) {
    case 'classic': return 'launch_classic' + suffix;
    case 'spectrum': return 'launch_spectrum' + suffix;
    case 'outline': return 'launch_outline' + suffix;
    case 'brush': return 'launch_brush' + suffix;
    case 'blossom': return 'launch_blossom' + suffix;
    case 'blue_bird': return 'launch_blue_bird' + suffix;
    case 'twitter_blue': return dark ? 'launch_twitter_dark' : 'launch_twitter_blue';
    case 'twitter_white': return dark ? 'launch_twitter_dark' : 'launch_twitter_white';
    case 'x_black':
    case 'x_white': return 'launch_x' + suffix;
    case 'frog_white':
    case 'frog_black': return 'launch_blue_frog' + suffix;
    case 'milk_frog_white':
    case 'milk_frog_black': return 'launch_milk_frog' + suffix;
    case 'zombie_x': return 'launch_zombie_x' + suffix;
    case 'mid_autumn': return 'launch_mid_autumn' + suffix;
    default: return (bundleName === 'com.haohaoai0.CroakX' ? 'launch_blue_frog' : 'launch_classic') + suffix;
  }
}
