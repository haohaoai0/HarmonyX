function identityObject(value: Object | undefined): Record<string, Object> {
  return value !== null && typeof value === 'object' && !(value instanceof Array) ? value as Record<string, Object> : {};
}

export function normalizedVerifiedType(value: string): string {
  const type: string = value.toLowerCase();
  return type === 'business' || type === 'gold' ? 'Business' :
    type === 'government' || type === 'gray' || type === 'grey' ? 'Government' : type === 'blue' ? 'Blue' : '';
}

export function userVerifiedType(value: Object | undefined): string {
  const user: Record<string, Object> = identityObject(value);
  const verification: Record<string, Object> = identityObject(user['verification']);
  const legacy: Record<string, Object> = identityObject(user['legacy']);
  const type: string = normalizedVerifiedType(String(verification['verified_type'] ?? user['verified_type'] ?? legacy['verified_type'] ?? ''));
  if (type.length > 0) { return type; }
  return verification['is_verified_organization'] === true || user['is_verified_organization'] === true ? 'Business' : '';
}

export function userIsVerified(value: Object | undefined): boolean {
  const user: Record<string, Object> = identityObject(value);
  const verification: Record<string, Object> = identityObject(user['verification']);
  const legacy: Record<string, Object> = identityObject(user['legacy']);
  return userVerifiedType(value).length > 0 || verification['is_blue_verified'] === true || user['is_blue_verified'] === true ||
    verification['verified'] === true || user['verified'] === true || legacy['verified'] === true;
}

export function userAvatarShape(value: Object | undefined): string {
  const user: Record<string, Object> = identityObject(value);
  const legacy: Record<string, Object> = identityObject(user['legacy']);
  const avatar: Record<string, Object> = identityObject(user['avatar']);
  const shape: string = String(user['profile_image_shape'] ?? user['avatar_shape'] ?? avatar['shape'] ?? legacy['profile_image_shape'] ?? '');
  return shape.toLowerCase() === 'square' ? 'Square' : shape.toLowerCase() === 'circle' ? 'Circle' : '';
}

export function userAvatarRadius(size: number, radius: number, verifiedType: string = '', avatarShape: string = ''): number {
  return normalizedVerifiedType(verifiedType) === 'Business' || avatarShape.toLowerCase() === 'square' ? size * 0.12 : radius;
}

export function verificationBadgeColor(verifiedType: string, blue: ResourceColor): ResourceColor {
  const type: string = normalizedVerifiedType(verifiedType);
  return type === 'Business' ? $r('app.color.follow_badge_gold') : type === 'Government' ? $r('app.color.text_secondary') : blue;
}
