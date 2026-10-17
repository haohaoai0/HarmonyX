const fs = require('node:fs');
const path = require('node:path');
const strings = {
  chat_group_info: ['群组信息', 'Group info'],
  chat_group_edit: ['编辑群组', 'Edit group'],
  chat_group_description: ['描述', 'Description'],
  chat_group_description_hint: ['输入此群组的描述，所有成员可见。', 'Describe this group. All members can see this.'],
  chat_group_avatar_edit: ['更改群头像', 'Change group photo'],
  chat_group_invite: ['群组邀请链接', 'Group invite link'],
  chat_group_invite_hint: ['生成供用户加入此聊天的链接。禁用后，即使持有链接，用户也无法加入。', 'Create a link to join this chat. When disabled, people cannot join using the link.'],
  chat_group_invite_privacy: ['任何收到此链接的用户均可查看群组名称、头像及成员数。', 'Anyone with this link can see the group name, photo and member count.'],
  chat_group_copy_link: ['复制链接', 'Copy link'],
  chat_group_link_copied: ['链接已复制', 'Link copied'],
  chat_group_permissions: ['权限', 'Permissions'],
  chat_group_admins: ['管理员', 'Admins'],
  chat_group_admin: ['管理员', 'Admin'],
  chat_group_admin_only: ['仅管理员', 'Admins only'],
  chat_group_all_send: ['所有人均可发送信息', 'Everyone can send messages'],
  chat_group_all_send_hint: ['关闭此项后，仅管理员可以发送消息，其他成员只能查看群组。', 'When off, only admins can send messages. Other members can read the chat.'],
  chat_group_add_members: ['添加成员', 'Add members'],
  chat_group_edit_info: ['编辑群组信息', 'Edit group info'],
  chat_group_start_call: ['发起群组通话', 'Start group calls'],
  chat_group_add_admin: ['添加为管理员', 'Make admin'],
  chat_group_remove_admin: ['移除管理员身份', 'Remove admin role'],
  chat_group_remove_member: ['从组中删除', 'Remove from group'],
  chat_group_member_dm: ['私信此用户', 'Message this user'],
  chat_group_member_nickname: ['设置昵称', 'Set nickname'],
  chat_group_nickname_local: ['昵称仅在此设备的当前账号中显示。', 'This nickname is visible only to this account on this device.'],
  chat_group_members_count: ['%d 位成员', '%d members'],
  chat_group_add: ['添加', 'Add'],
  chat_group_leave: ['离开对话', 'Leave conversation'],
  chat_group_leave_confirm: ['离开后将无法继续接收此群聊的新消息。确定离开？', 'You will stop receiving new messages from this group. Leave conversation?'],
  chat_group_remove_confirm: ['确定将此成员从群组中删除？', 'Remove this member from the group?'],
  chat_group_saved: ['已保存', 'Saved'],
  chat_group_load_failed: ['群组信息加载失败，点击重试', 'Could not load group info. Tap to retry'],
  chat_group_no_permission: ['此操作仅对管理员开放', 'Only admins can perform this action'],
  chat_group_select_admin: ['选择管理员', 'Select admins'],
  chat_group_edit_failed: ['群组操作未获服务器确认，请重试。', 'The server did not confirm the group change. Please retry.'],
  chat_group_capture_hint: ['阻止此群聊内容被截屏或录屏。由服务器同步给群组成员。', 'Prevent screen captures and recordings of this conversation. This setting is shared with group members.'],
  chat_group_ttl_hint: ['开启后，新消息将在指定时间后消失。', 'New messages disappear after the selected time.'],
  chat_group_avatar_failed: ['群头像暂时无法解密，点击重试', 'Could not decrypt the group photo. Tap to retry'],
  chat_group_empty_name: ['请输入群组名称', 'Enter a group name']
};
const root = 'entry/src/main/resources';
for (const locale of fs.readdirSync(root)) {
  const file = path.join(root,locale,'element/string.json');
  if (!fs.existsSync(file)) continue;
  const data = JSON.parse(fs.readFileSync(file,'utf8'));
  const chinese = locale==='base'||locale==='zh_CN'||locale==='zh_TW'||locale==='zh_HK';
  for(const [name,values] of Object.entries(strings)) {
    const value=values[chinese?0:1];
    const old=data.string.find(s=>s.name===name);
    if(old) old.value=value; else data.string.push({name,value});
  }
  fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');
}
