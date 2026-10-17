const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

// Contract fixture: official dm-core-Cmtg_7cS.js, SHA-256
// 83829309569451e86adddf7925f6b409334883968be9d7f84334a079d32c1ffa.
// Source and field-level evidence: outputs/group-chat-web-contracts-2026-10-15.md.
const rows = JSON.parse(fs.readFileSync('entry/src/main/resources/rawfile/x-operations.json', 'utf8')).operations;
function operation(name) {
  const found = rows.filter(row => row.operation === name);
  assert.equal(found.length, 1, `${name} must resolve to one contract`);
  assert.equal(found[0].http, 'POST');
  return found[0];
}
function variable(name, key, type, hasDefault = false) {
  assert.deepEqual(operation(name).variables.find(row => row.name === key), { name: key, type, hasDefault });
}

test('group detail loads complete members and encrypted description metadata using the current web query', () => {
  assert.equal(operation('GetInboxPageConversationDataQuery').query_id, 'Q0z8FP2vsR5jKyf9uFBgbQ');
  variable('GetInboxPageConversationDataQuery', 'conversation_ids', '[String!]!');
  variable('GetInboxPageConversationDataQuery', 'include_user_public_keys', 'Boolean!');
  variable('GetInboxPageConversationDataQuery', 'include_all_group_member_user_objects', 'Boolean!', true);
});

test('group key lookup, candidate search and inbox dependencies cannot fall back to stale duplicate contracts', () => {
  assert.equal(operation('GetUsersByIdsForXChat').query_id, '4zbPmRwsca859ORbYCLyzg');
  variable('GetUsersByIdsForXChat', 'with_social_proof', 'Boolean!', true);
  assert.equal(operation('TypeaheadXChatQuery').query_id, '0Ex6y7CV1-G5DaFSeMLTMQ');
  variable('TypeaheadXChatQuery', 'include_group_check', 'Boolean');
  assert.equal(operation('GetInitialXChatPageQuery').query_id, 'cE5eWXf3XEyopOC1gqUEMQ');
  assert.equal(operation('GetInboxPageRequestQuery').query_id, 'ozi1iZ_dhQVeRP017B6lbQ');
  variable('GetInboxPageRequestQuery', 'continue_cursor', 'XChatGetInboxPageContinueCursorInput!');
});

test('editing and adding group members retain key rotation and encrypted metadata wire fields', () => {
  assert.equal(operation('EditGroupConversationMutation').query_id, 'rmo8faqxHgM6s22FDQJETA');
  variable('EditGroupConversationMutation', 'conversation_key_version', 'NumericString!');
  variable('EditGroupConversationMutation', 'modified_fields', '[EditGroupFieldNameInput!]');
  variable('EditGroupConversationMutation', 'rotated_pmk_bundle', '[XChatApiPmkBundleEntryInput!]');
  assert.equal(operation('AddGroupMembersMutation').query_id, '9P3IK7zSYT-xmxE08NFu7A');
  variable('AddGroupMembersMutation', 'user_ids', '[NumericString!]!');
  variable('AddGroupMembersMutation', 'screen_capture_blocking_enabled', 'Boolean!');
  variable('AddGroupMembersMutation', 'encrypted_description', 'String');
  variable('AddGroupMembersMutation', 'rotated_pmk_bundle', '[XChatApiPmkBundleEntryInput!]');
  variable('RemoveFromGroupMutation', 'group_key_rotation_data', 'XChatGroupKeyRotationDataInput');
});

test('invites require a submitted URL and preserve signed expiration and public preview fields', () => {
  assert.equal(operation('EnableGroupInviteMutation').query_id, 'WlxTMdzK_uh-miHVHXv15g');
  variable('EnableGroupInviteMutation', 'invite_url', 'String!');
  variable('EnableGroupInviteMutation', 'validity_expiry_timestamp_msec', 'NumericString');
  variable('EnableGroupInviteMutation', 'decrypted_title', 'String');
  variable('EnableGroupInviteMutation', 'decrypted_avatar_url', 'String');
  variable('GroupInviteDetailsQuery', 'token', 'String!');
});

test('permission variables use web camelCase names with optional individual restrictions', () => {
  const name = 'UpdateGroupAdminSettingsMutation';
  assert.equal(operation(name).query_id, 'CWJ7NtJ8LbvqTrsDSTCHvA');
  variable(name, 'conversationId', 'String!');
  for (const key of ['addMember', 'editGroupInfo', 'sendMessage', 'startCall', 'editMessageTtl', 'blockScreenCapture']) {
    variable(name, key, 'Boolean');
  }
  variable(name, 'action_signatures', '[ActionSignatureInput!]');
});

test('private avatar upload and public invitation previews share current media initialization and finalization contracts', () => {
  assert.equal(operation('InitializeXChatMediaUploadMutation').query_id, '6M543IPabOfZm7-yyIczdw');
  variable('InitializeXChatMediaUploadMutation', 'total_bytes', 'NumericString!');
  variable('InitializeXChatMediaUploadMutation', 'is_public', 'Boolean');
  variable('InitializeXChatMediaUploadMutation', 'content_type', 'String');
  assert.equal(operation('FinalizeXChatMediaUploadMutation').query_id, '3O4jPQ2hwW9LbqCc-wFmqA');
  variable('FinalizeXChatMediaUploadMutation', 'num_parts', 'NumericString!');
  variable('FinalizeXChatMediaUploadMutation', 'is_public', 'Boolean');
});
