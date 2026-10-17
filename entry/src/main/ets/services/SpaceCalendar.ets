import { common } from '@kit.AbilityKit';
import { calendarManager } from '@kit.CalendarKit';
import { SpaceRoom } from '../models/Space';

// The system editor asks the user to save. It requires no calendar read/write permission.
export async function addSpaceToCalendar(context: common.UIAbilityContext, room: SpaceRoom): Promise<boolean> {
  if (!room.isScheduled() || room.scheduledStart <= Date.now()) { return false; }
  const event: calendarManager.Event = {
    type: calendarManager.EventType.NORMAL,
    title: room.title || context.resourceManager.getStringSync($r('app.string.spaces_untitled')),
    startTime: room.scheduledStart,
    endTime: room.scheduledStart + 3600000,
    description: 'https://x.com/i/spaces/' + room.id,
    reminderTime: [10]
  };
  const id: number = await calendarManager.getCalendarManager(context).editEvent(event);
  return id > 0;
}
