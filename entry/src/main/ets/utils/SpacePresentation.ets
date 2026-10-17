import { common } from '@kit.AbilityKit';
import { SpaceParticipant, SpaceRoom } from '../models/Space';
import { TweetAuthor } from '../models/Tweet';
import { UserDetailRouteParam } from '../pages/UserDetail';

export function spaceRole(person: SpaceParticipant): Resource {
  return person.role === 'host' ? $r('app.string.spaces_host') : person.role === 'cohost' ?
    $r('app.string.spaces_cohost') : person.role === 'speaker' ? $r('app.string.spaces_speaker') :
      $r('app.string.spaces_listener');
}

export function spaceStatus(room: SpaceRoom): Resource {
  return room.isLive() ? $r('app.string.spaces_live') : room.isScheduled() ? $r('app.string.spaces_scheduled') :
    room.replayAvailable ? $r('app.string.spaces_replay') : $r('app.string.spaces_ended');
}

export function spaceTime(context: common.Context, timestamp: number): string {
  if (timestamp <= 0) { return ''; }
  const date: Date = new Date(timestamp);
  const today: Date = new Date();
  const tomorrow: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
  let day: string = date.toLocaleDateString();
  if (date.toDateString() === today.toDateString()) {
    day = context.resourceManager.getStringSync($r('app.string.spaces_today'));
  } else if (date.toDateString() === tomorrow.toDateString()) {
    day = context.resourceManager.getStringSync($r('app.string.spaces_tomorrow'));
  }
  return day + ' ' + String(date.getHours()).padStart(2, '0') + ':' + String(date.getMinutes()).padStart(2, '0');
}

export function spaceUserParam(person: SpaceParticipant): UserDetailRouteParam {
  const author: TweetAuthor = {
    id: person.id, name: person.name, username: person.username, avatarUrl: person.avatarUrl,
    avatarColor: '#7856FF', verified: person.verified
  };
  return { author: author, posts: [] };
}
