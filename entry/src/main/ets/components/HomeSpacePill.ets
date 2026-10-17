import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { SpaceParticipant, SpaceRoom } from '../models/Space';
import { formatCount } from '../models/Tweet';
import { MaterialButton } from './MaterialButton';
import { ProxyAvatar } from './ProxyAvatar';
import { SpaceWaveform } from './SpaceWaveform';
import { spaceSurfaceStore } from '../services/SpaceSurfaceStore';

@Component
export struct HomeSpacePill {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop room: SpaceRoom = new SpaceRoom();
  @Prop pillWidth: number = 360;
  @StorageProp('harmonyx.accent_color') accentColor: string = '#007DFF';
  onOpen: (room: SpaceRoom) => void = (): void => {};

  private faces(): SpaceParticipant[] {
    return this.room.participants.filter((person: SpaceParticipant): boolean => person.role !== 'listener').slice(0, 3);
  }
  private lines(): string[] {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const followed: SpaceParticipant[] = spaceSurfaceStore.followedParticipants(this.room);
    const listeners: SpaceParticipant[] = this.room.participants.filter((person: SpaceParticipant): boolean => person.role === 'listener');
    const people: string = (followed.filter((person: SpaceParticipant): boolean => person.role === 'listener').length > 0 ?
      followed.filter((person: SpaceParticipant): boolean => person.role === 'listener') : listeners)
      .slice(0, 2).map((person: SpaceParticipant): string => person.name || person.username).join('、');
    return [
      '+' + formatCount(Math.max(0, this.room.participantCount - this.faces().length)) + ' · ' +
        (this.room.title || context.resourceManager.getStringSync($r('app.string.spaces_untitled'))),
      people.length > 0 ? context.resourceManager.getStringSync($r('app.string.spaces_pill_people').id, people) :
        context.resourceManager.getStringSync($r('app.string.spaces_pill_host').id, this.room.host.name || this.room.host.username),
      context.resourceManager.getStringSync($r('app.string.spaces_pill_listen'))
    ];
  }
  private tint(): string { return '#66' + this.accentColor.replace(/^#(?:[A-Fa-f0-9]{2})?([A-Fa-f0-9]{6})$/, '$1'); }

  build(): void {
    MaterialButton({ buttonWidth: this.pillWidth, buttonHeight: 48, buttonRadius: 24,
      surfaceColor: this.accentColor, materialTint: this.tint(), materialLevel: 1, applyShadow: true,
      accessibilityLabel: this.lines()[0], onButtonClick: (): void => this.onOpen(this.room) }) {
      Row({ space: 10 }) {
        Row({ space: -10 }) {
          ForEach(this.faces(), (person: SpaceParticipant): void => {
            Stack() {
              ProxyAvatar({verifiedType: person.verifiedType ?? '', avatarShape: person.avatarShape ?? '',  url: person.avatarUrl, avatarSize: 38, radius: 19,
                fallbackText: person.name.substring(0, 1), fallbackColor: this.accentColor })
            }.width(42).height(42).borderRadius(21).border({ width: 2, color: this.accentColor })
          }, (person: SpaceParticipant): string => person.id)
        }
        Swiper() {
          ForEach(this.lines(), (line: string): void => {
            Text(line).fontFamily(this.appFontFamily).width('100%').fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }, (line: string, index: number): string => String(index) + line)
        }.layoutWeight(1).height(28).vertical(true).autoPlay(true).interval(3500).duration(420)
          .indicator(false).loop(true).disableSwipe(true).hitTestBehavior(HitTestMode.None)
        SpaceWaveform({ color: this.accentColor, waveformSize: 23 })
      }.width('100%').padding({ left: 4, right: 16 }).alignItems(VerticalAlign.Center)
    }
  }
}
