const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./post-card-fixture.cjs');

const profile = () => ({id:'viewer',name:'Name',username:'viewer',description:'Bio',location:'Here',website:'',
  avatarUrl:'https://pbs.twimg.com/old.jpg',bannerUrl:'https://pbs.twimg.com/old',followersCount:2,followingCount:3,postCount:4,verified:false});

function fixture() {
  const events=[], storage=new Map(); let generation=7, viewer='viewer', fail='', fresh=profile();
  const client={isSignedIn:()=>true,sessionGeneration:()=>generation,viewerId:()=>viewer,
    accountManagementRequest:async(method,path,form,json,session)=>{
      events.push({step:'text',form,session});return {ok:fail!=='text'};
    },
    updateProfilePhoto:async(uri,banner,session)=>{
      const step=banner?'banner':'avatar';events.push({step,uri,session});return {ok:fail!==step};
    },
    userByRestId:async(id,bypass)=>{events.push({step:'read',id,bypass});return {ok:fail!=='read',body:'response'};}
  };
  const api=load('services/ProfileEditService',{'./XPrivateClient':{xPrivateClient:client},
    './XUserParser':{XUserParser:{parse:()=>fresh}}},storage);
  return {api,events,storage,client,draft:new api.ProfileEditDraft(profile()),
    fail:value=>{fail=value},fresh:value=>{fresh=value},switch:()=>{generation++;viewer='other'}};
}

test('profile draft validates limits, blank names, and web protocols while preserving bio whitespace',()=>{
  const f=fixture(),d=f.draft;assert.equal(d.hasChanges(),false);assert.equal(d.valid(),true);
  d.name=' ';assert.equal(d.valid(),false);d.name='😀'.repeat(50);assert.equal(d.valid(),true);
  d.name+='x';assert.equal(d.valid(),false);d.name='Name';d.bio='\n  poem\n';assert.equal(d.valid(),true);
  assert.equal(d.bio,'\n  poem\n');d.website='javascript:alert(1)';assert.equal(d.valid(),false);
  d.website='https://example.com/a';assert.equal(d.valid(),true);
  d.website='example.com/a';assert.equal(d.valid(),true);assert.equal(d.normalizedWebsite(),'https://example.com/a');
  d.location='x'.repeat(31);assert.equal(d.valid(),false);
});

test('saving text and photos uses the captured account then fetches an uncached profile and publishes it',async()=>{
  const f=fixture();f.draft.name=' New ';f.draft.bio='\n bio\n';f.draft.avatarUri='avatar';f.draft.bannerUri='banner';
  const fresh={...profile(),name:'New',description:'\n bio\n'};f.fresh(fresh);
  const result=await f.api.profileEditService.save(f.draft,7);
  assert.deepEqual(f.events.map(e=>e.step),['text','avatar','banner','read']);
  assert.deepEqual(f.events[0].form,{name:'New',description:'\n bio\n',location:'Here',url:''});
  assert.equal(f.events[3].bypass,true);assert.equal(result,fresh);assert.equal(f.draft.hasChanges(),false);
  assert.equal(f.api.lastEditedProfile(),fresh);assert.equal(f.storage.get(f.api.STORAGE_KEY_EDITED_PROFILE),2);
});

test('editing only a photo does not rewrite unchanged profile text',async()=>{
  const f=fixture();f.draft.avatarUri='avatar';await f.api.profileEditService.save(f.draft,7);
  assert.deepEqual(f.events.map(e=>e.step),['avatar','read']);
});

test('a partial banner failure retains the photo draft and retries only the remaining step',async()=>{
  const f=fixture();f.draft.name='New';f.draft.avatarUri='avatar';f.draft.bannerUri='banner';f.fail('banner');
  await assert.rejects(f.api.profileEditService.save(f.draft,7),/profile_save_failed/);
  assert.equal(f.draft.avatarApplied,true);assert.equal(f.draft.bannerApplied,false);assert.equal(f.draft.hasChanges(),true);
  f.events.length=0;f.fail('');await f.api.profileEditService.save(f.draft,7);
  assert.deepEqual(f.events.map(e=>e.step),['banner','read']);
});

test('a failed confirmation can be retried without uploading acknowledged photos again',async()=>{
  const f=fixture();f.draft.avatarUri='avatar';f.fail('read');
  await assert.rejects(f.api.profileEditService.save(f.draft,7),/profile_refresh_failed/);
  f.fail('');f.events.length=0;await f.api.profileEditService.save(f.draft,7);
  assert.deepEqual(f.events.map(e=>e.step),['read']);
});

test('failed text saves leave the draft unchanged and never start photo writes',async()=>{
  const f=fixture();f.draft.name='New';f.draft.avatarUri='avatar';f.fail('text');
  await assert.rejects(f.api.profileEditService.save(f.draft,7),/profile_save_failed/);
  assert.deepEqual(f.events.map(e=>e.step),['text']);assert.equal(f.draft.profile.name,'Name');
  assert.equal(f.storage.size,0);assert.equal(f.draft.hasChanges(),true);
});

test('account changes before a save block every write',async()=>{
  const f=fixture();f.draft.name='New';f.switch();
  await assert.rejects(f.api.profileEditService.save(f.draft,7),/account_changed/);assert.deepEqual(f.events,[]);
});

test('account changes between text and photo steps block later writes and publication',async()=>{
  const f=fixture();f.draft.name='New';f.draft.avatarUri='avatar';
  f.client.accountManagementRequest=async()=>{f.events.push({step:'text'});f.switch();return {ok:true}};
  await assert.rejects(f.api.profileEditService.save(f.draft,7),/account_changed/);
  assert.deepEqual(f.events.map(e=>e.step),['text']);assert.equal(f.storage.size,0);
});

test('a response for another user is never published as the saved profile',async()=>{
  const f=fixture();f.fresh({...profile(),id:'other'});
  await assert.rejects(f.api.profileEditService.save(f.draft,7),/profile_refresh_failed/);
  assert.equal(f.storage.size,0);
});
