// Presentation-only data. The host owns eligibility, cached media and navigation.
export class SplashAdCreative {
  appId: string = '';
  destination: string = '';
  icon: ResourceStr = '';
  duration: number = 3;
  artwork: ResourceStr = '';
  images: ResourceStr[] = [];
  advertiser: ResourceStr = '';
  eyebrow: ResourceStr = '';
  title: ResourceStr = '';
  description: ResourceStr = '';
  action: ResourceStr = $r('app.string.xxauth_experience');
}
