export const LOGO_BLUE_AVATAR_COUNT: number = 8;

// The four polygons follow the supplied 1024px HarmonyX mark. Coordinates
// stay independent of the window; resizing only rebuilds this bounded scene.
export class LogoPoint {
  x: number;
  y: number;
  constructor(x: number, y: number) { this.x = x; this.y = y; }
}

export class LogoParticle {
  id: string = '';
  index: number = 0;
  blue: boolean = false;
  avatar: number = -1;
  x: number = 0;
  y: number = 0;
  size: number = 0;
  phase: number = 0;
  drift: number = 0;
  opacity: number = 1;
  polygon: LogoPoint[] = [];
  sourceY: number = 0;
  lane: number = 0.5;
  ratio: number = 1;
  originX: number = 0;
  originY: number = 0;
  firstY: number = 206;
  lastY: number = 805;
  self: boolean = false;
}

export class LogoParticleFrame {
  x: number = 0;
  y: number = 0;
  scale: number = 1;
  opacity: number = 1;
}

const BLUE_ARROW: LogoPoint[] = [new LogoPoint(158, 206), new LogoPoint(268, 206),
  new LogoPoint(471, 502), new LogoPoint(251, 805), new LogoPoint(142, 805), new LogoPoint(362, 502)];
const WHITE_STEM: LogoPoint[] = [new LogoPoint(346, 206), new LogoPoint(459, 206),
  new LogoPoint(655, 502), new LogoPoint(441, 805), new LogoPoint(330, 805), new LogoPoint(545, 502)];
const WHITE_TOP: LogoPoint[] = [new LogoPoint(756, 206), new LogoPoint(866, 206),
  new LogoPoint(694, 434), new LogoPoint(642, 355)];
const WHITE_BOTTOM: LogoPoint[] = [new LogoPoint(693, 568), new LogoPoint(863, 805),
  new LogoPoint(750, 805), new LogoPoint(635, 648)];

function containsLogoPoint(x: number, y: number, polygon: LogoPoint[]): boolean {
  let inside: boolean = false;
  let previous: number = polygon.length - 1;
  for (let i: number = 0; i < polygon.length; i++) {
    const a: LogoPoint = polygon[i];
    const b: LogoPoint = polygon[previous];
    if ((a.y > y) !== (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
    previous = i;
  }
  return inside;
}

export function logoZoneAt(x: number, y: number): number {
  if (containsLogoPoint(x, y, BLUE_ARROW)) { return 1; }
  if (containsLogoPoint(x, y, WHITE_STEM) || containsLogoPoint(x, y, WHITE_TOP) ||
    containsLogoPoint(x, y, WHITE_BOTTOM)) { return 2; }
  return 0;
}

function logoNoise(seed: number): number {
  const value: number = Math.sin(seed * 127.1 + 311.7) * 43758.5453;
  return value - Math.floor(value);
}

function logoSlice(polygon: LogoPoint[], y: number): LogoPoint {
  let left: number = 1024;
  let right: number = 0;
  let previous: number = polygon.length - 1;
  for (let i: number = 0; i < polygon.length; i++) {
    const a: LogoPoint = polygon[i];
    const b: LogoPoint = polygon[previous];
    if ((a.y > y) !== (b.y > y)) {
      const x: number = a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y);
      left = Math.min(left, x);
      right = Math.max(right, x);
    }
    previous = i;
  }
  return new LogoPoint(left, right);
}

export function createLogoConstellation(width: number, height: number): LogoParticle[] {
  const particles: LogoParticle[] = [];
  if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) { return particles; }
  const side: number = Math.min(Math.max(1, width - 40), Math.max(1, (height - 80) / 0.828), 640);
  const ratio: number = side / 724;
  const left: number = (width - side) / 2;
  const top: number = (height - side * 599 / 724) / 2;
  let blueIndex: number = 0;
  let avatarCount: number = 0;
  for (let row: number = 0; row < 19; row++) {
    for (let column: number = 0; column < 23; column++) {
      const seed: number = row * 31 + column;
      const x: number = 151 + column * 32 + (logoNoise(seed) - 0.5) * 22;
      const y: number = 217 + row * 32 + (logoNoise(seed + 17) - 0.5) * 22;
      const zone: number = logoZoneAt(x, y);
      if (zone === 0) { continue; }
      const particle: LogoParticle = new LogoParticle();
      particle.index = particles.length;
      particle.id = 'logo-' + row.toString() + '-' + column.toString();
      particle.blue = zone === 1;
      if (particle.blue) {
        if (blueIndex % 2 === 0) { particle.avatar = avatarCount++ % LOGO_BLUE_AVATAR_COUNT; }
        blueIndex++;
      }
      const noise: number = logoNoise(seed + 43);
      particle.size = (particle.avatar >= 0 ? 40 + noise * 9 : 13 + noise * 14) * ratio;
      particle.x = left + (x - 142) * ratio - particle.size / 2;
      particle.y = top + (y - 206) * ratio - particle.size / 2;
      particle.phase = logoNoise(seed + 91) * Math.PI * 2;
      particle.polygon = particle.blue ? BLUE_ARROW : containsLogoPoint(x, y, WHITE_STEM) ? WHITE_STEM :
        containsLogoPoint(x, y, WHITE_TOP) ? WHITE_TOP : WHITE_BOTTOM;
      particle.sourceY = y;
      particle.ratio = ratio;
      particle.originX = left;
      particle.originY = top;
      particle.firstY = particle.polygon === WHITE_BOTTOM ? 568 : 206;
      particle.lastY = particle.polygon === WHITE_TOP ? 434 : 805;
      const slice: LogoPoint = logoSlice(particle.polygon, y);
      particle.lane = Math.max(0.08, Math.min(0.92, (x - slice.x) / Math.max(1, slice.y - slice.x)));
      // Particles on an edge breathe in place; interior particles drift freely.
      const inset: boolean = logoZoneAt(x - 12, y) === zone && logoZoneAt(x + 12, y) === zone &&
        logoZoneAt(x, y - 12) === zone && logoZoneAt(x, y + 12) === zone;
      particle.drift = (inset ? 6 + noise * 4 : 1.5) * ratio;
      particle.opacity = particle.avatar >= 0 ? 0.92 : 0.5 + noise * 0.43;
      particles.push(particle);
    }
  }
  return particles;
}

export function logoParticleFrame(particle: LogoParticle, progress: number): LogoParticleFrame {
  const bounded: number = Number.isFinite(progress) ? progress % 1 : 0;
  const angle: number = bounded * Math.PI * 2 + particle.phase;
  const frame: LogoParticleFrame = new LogoParticleFrame();
  // Like the reference icon lanes, neighbouring streams roll in opposite
  // directions on one clock. Cross-sections retain the exact arrow/X silhouette.
  const length: number = particle.lastY - particle.firstY;
  const direction: number = particle.lane < 0.5 ? -1 : 1;
  const travel: number = (particle.sourceY - particle.firstY + bounded * length * direction) / length;
  const phaseY: number = ((travel % 1) + 1) % 1;
  const y: number = particle.firstY + 0.1 + phaseY * (length - 0.2);
  const slice: LogoPoint = logoSlice(particle.polygon, y);
  const x: number = slice.x + (slice.y - slice.x) * particle.lane;
  frame.x = particle.originX + (x - 142) * particle.ratio - particle.size / 2 + Math.sin(angle) * particle.drift;
  frame.y = particle.originY + (y - 206) * particle.ratio - particle.size / 2 +
    Math.cos(angle * 2 - particle.phase) * particle.drift * 1.3;
  frame.scale = 1 + Math.sin(angle + particle.phase) * (particle.avatar >= 0 ? 0.045 : 0.12);
  const edgeFade: number = Math.min(1, phaseY / 0.035, (1 - phaseY) / 0.035);
  frame.opacity = particle.opacity * (0.86 + Math.sin(angle * 2) * 0.14) * edgeFade;
  return frame;
}

export class LogoInteraction {
  assembly: number = 0;
  pointerX: number = 0;
  pointerY: number = 0;
  windX: number = 0;
  windY: number = 0;
  join: number = 1;
  focus: number = 0;
  width: number = 0;
  height: number = 0;
}

export function personalizeLogo(particles: LogoParticle[], width: number, height: number): void {
  let nearest: LogoParticle | undefined = undefined;
  let distance: number = Number.MAX_VALUE;
  for (let i: number = 0; i < particles.length; i++) {
    const p: LogoParticle = particles[i];
    if (p.blue || p.firstY !== 206 || p.lastY !== 805) { continue; }
    const score: number = Math.pow(p.x - width * 0.59, 2) + Math.pow(p.y - height * 0.5, 2);
    if (score < distance) { nearest = p; distance = score; }
  }
  if (nearest !== undefined) {
    const previous: number = nearest.size;
    nearest.size = Math.max(24, Math.min(36, previous * 2.2));
    nearest.x -= (nearest.size - previous) / 2;
    nearest.y -= (nearest.size - previous) / 2;
    nearest.avatar = LOGO_BLUE_AVATAR_COUNT;
    nearest.self = true;
  }
}

export function interactiveLogoFrame(particle: LogoParticle, progress: number,
  interaction: LogoInteraction): LogoParticleFrame {
  const frame: LogoParticleFrame = logoParticleFrame(particle, progress);
  const assembly: number = Math.max(0, Math.min(1, interaction.assembly));
  frame.x += (particle.x - frame.x) * assembly;
  frame.y += (particle.y - frame.y) * assembly;
  frame.opacity += (particle.opacity - frame.opacity) * assembly;
  const distance: number = Math.hypot(frame.x - interaction.pointerX, frame.y - interaction.pointerY);
  const influence: number = Math.exp(-distance * distance / (110 * 110));
  frame.x += interaction.windX * influence * (1 - assembly);
  frame.y += interaction.windY * influence * (1 - assembly);
  if (particle.self) {
    const join: number = Math.max(0, Math.min(1, interaction.join));
    const eased: number = 1 - Math.pow(1 - join, 3);
    frame.x = (interaction.width / 2 - particle.size / 2) * (1 - eased) + frame.x * eased;
    frame.y = (interaction.height + 30) * (1 - eased) + frame.y * eased;
    frame.opacity = Math.max(frame.opacity, 0.95) * Math.min(1, join * 4);
    frame.scale *= 1 + interaction.focus * 0.65;
    frame.y -= interaction.focus * 18;
  }
  return frame;
}
