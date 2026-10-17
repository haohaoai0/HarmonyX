const assert=require('node:assert/strict');
const test=require('node:test');
const {load}=require('./post-card-fixture.cjs');
const {XCommunityParser}=load('services/XCommunityParser');
const {XTimelineParser}=load('services/XTimelineParser');
function user(id='42') { return {rest_id:id,legacy:{name:'Member',screen_name:'member',profile_image_url_https:'https://image.test/a.jpg'}}; }
function community(extra={}) { return {__typename:'Community',rest_id:'123',name:'Flowers',member_count:140000,join_policy:'Open',rules:[{rest_id:'r',name:'Be kind',description:'Respect everyone'}],...extra}; }
function post(extra={}) { return {__typename:'Tweet',rest_id:'456',legacy:{full_text:'Hello',created_at:'2026-10-06',favorite_count:2},core:{user_results:{result:user()}},...extra}; }
test('directory preserves both banner formats, real member facepile, topic, creator and rules',()=>{
 const row=XCommunityParser.parse(JSON.stringify({data:{community:community({
 custom_banner_media_results:{result:{media_info:{original_img:{url:'https://image.test/banner.jpg'}}}},
 members_facepile_results:[{result:user()}], primary_community_topic:{topic_id:'2',name:'Photography'},
 creator_results:{result:user('9')},created_at:1700000000000
 })}})).communities[0];
 assert.equal(row.bannerUrl,'https://image.test/banner.jpg');
 assert.equal(row.members[0].username,'member');
 assert.equal(row.creator.id,'9');
 assert.equal(row.topicName,'Photography');
 assert.equal(row.rules[0].description,'Respect everyone');
 const old=XCommunityParser.parse(JSON.stringify({data:{community:community({
 default_banner_media:{media_info:{original_img_url:'https://image.test/old.jpg'}}
 })}})).communities[0];
 assert.equal(old.bannerUrl,'https://image.test/old.jpg');
});
test('pending and non-member roles never grant posting membership',()=>{
 for(const role of ['None','NonMember','Pending','Requested','NotAMember']) {
  assert.equal(XCommunityParser.parse(JSON.stringify({data:community({role})})).communities[0].joined,false,role);
 }
 for(const role of ['Member','Moderator','Admin','Owner']) {
  assert.equal(XCommunityParser.parse(JSON.stringify({data:community({role})})).communities[0].joined,true,role);
 }
});
test('Android topic_name and subtopics decode independently from the community directory',()=>{
 const body=JSON.stringify({data:{fetch_community_topics:{community_topics:[
  {__typename:'CommunityTopic',topic_id:'1',topic_name:'体育',subtopics:[{topic_id:'11',topic_name:'足球'}]},
  {__typename:'CommunityTopic',rest_id:'2',name:'技术'}]}}});
 assert.deepEqual(XCommunityParser.parseTopics(body).map(x=>x.name),['体育','技术']);
 assert.equal(XCommunityParser.parse(body).communities.length,0);
});
test('deep URT discovery rows and slice cursors remain usable',()=>{
 let item=community();for(let i=0;i<18;i++)item={result:item};
 const page=XCommunityParser.parse(JSON.stringify({data:{items:[item],next_cursor:'NEXT'}}));
 assert.equal(page.communities[0].id,'123');assert.equal(page.nextToken,'NEXT');
});
test('bottom cursor and duplicate directory rows are handled',()=>{
 const page=XCommunityParser.parse(JSON.stringify({data:{entries:[community(),community(),
 {content:{cursorType:'Top',value:'REFRESH'}},{content:{cursor_type:'Bottom',value:'NEXT'}}]}}));
 assert.equal(page.communities.length,1);assert.equal(page.nextToken,'NEXT');
});
test('community origin survives classic and visibility-wrapped tweet payloads',()=>{
 const p=post({community_results:{result:community()}});
 const parsed=XTimelineParser.parseTweetItemContent({tweet_results:{result:p}});
 assert.equal(parsed.communityId,'123');assert.equal(parsed.communityName,'Flowers');
 const wrapped=XTimelineParser.parseTweetItemContent({tweet_results:{result:{__typename:'TweetWithVisibilityResults',tweet:p}}});
 assert.equal(wrapped.communityName,'Flowers');
});
test('item-level community source overrides missing tweet metadata and excludes quoted sources',()=>{
 const item=XTimelineParser.parseTweetItemContent({tweet_results:{result:post()},community_results:{result:community()}});
 assert.equal(item.communityId,'123');
 const ordinary=XTimelineParser.parseTweetItemContent({tweet_results:{result:post({
 quoted_status_result:{result:post({rest_id:'other',community_results:{result:community()}})}
 })}});
 assert.equal(ordinary.communityId,'');
});
test('native media singular user_result wins over viewer and community creator identities',()=>{
 const actual={rest_id:'77',legacy:{name:'Actual author',screen_name:'actual',profile_image_url_https:'https://image.test/actual_normal.jpg'},verification:{is_blue_verified:true}};
 const item=XTimelineParser.parseTweetItemContent({tweetResult:{result:post({
  community:community({creator_results:{result:user('9')},members_facepile_results:[{result:user('42')}]}),
  viewer_results:{result:user('42')},legacy:{full_text:'Their photo',user_id_str:'77'},
  core:{user_result:{result:actual}}
 })}});
 assert.equal(item.author.id,'77');assert.equal(item.author.name,'Actual author');assert.equal(item.author.username,'actual');
 assert.equal(item.author.avatarUrl,'https://image.test/actual_400x400.jpg');assert.equal(item.author.verified,true);
});
test('missing author never falls back to the viewer, community member or quoted author',()=>{
 const item=XTimelineParser.parseTweetItemContent({tweet_results:{result:post({
  legacy:{full_text:'Unresolved author',user_id_str:'77'},core:{user_results:{result:user('42')}},
  community:community({creator_results:{result:user('9')}}),
  quoted_status_result:{result:post({rest_id:'quoted'})}
 })}});
 assert.equal(item.author.id,'77');assert.equal(item.author.name,'X User');assert.equal(item.author.avatarUrl,'');
});
test('author side table resolves by matching user ID instead of first user in payload',()=>{
 const body=JSON.stringify({data:{viewer:user('42'),users:[user('9'),{rest_id:'77',legacy:{name:'Actual',screen_name:'actual'}}],
  timeline_response:{timeline:{instructions:[{entries:[{entryId:'tweet-456',content:{itemContent:{tweet_results:{result:post({core:{},legacy:{full_text:'A photo',user_id_str:'77'}})}}}}]}]}}}});
 const parsed=XTimelineParser.parse(body,false);
 assert.equal(parsed.tweets[0].author.id,'77');assert.equal(parsed.tweets[0].author.username,'actual');
});

