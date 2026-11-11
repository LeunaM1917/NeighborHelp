'use strict';
const {before, after, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const functions = require('firebase-functions/v1');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc} = require('firebase/firestore');
let app, db, env, identity;
let calls, hosted, nextReference, failFetch, time;
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || process.env.GCLOUD_PROJECT && !process.env.GCLOUD_PROJECT.startsWith('demo-')) throw Error('Demo emulator required');
  env = await initializeTestEnvironment({projectId:'demo-neighborhelp'});
  app = initializeApp({projectId:'demo-neighborhelp'}, 'identity-tests'); db = getFirestore(app);
  process.env.IDANALYZER_API_KEY = 'synthetic-api-key';
  process.env.IDANALYZER_PROFILE_ID = 'synthetic-profile';
  process.env.IDANALYZER_WEBHOOK_SECRET = 'synthetic-secret';
  identity = require('../id_analyzer')({db,functions,projectId:'demo-neighborhelp',now:()=>time,fetchImpl:async (url, options) => {
    calls.push({url, options});
    if (failFetch) throw Error('synthetic network failure');
    if (options.method === 'POST') {
      const body = JSON.parse(options.body), reference = `reference-${++nextReference}`;
      hosted.set(reference, {reference,mode:body.mode,profileId:body.profile,customData:body.customData,reusable:0,url:`https://docupass.app/${reference}`});
      return {ok:true,json:async()=>({reference,url:`https://docupass.app/${reference}`,expiry:time/1000+86400})};
    }
    return {ok:true,json:async()=>hosted.get(url.split('/').pop())};
  }});
});
after(async()=>{await deleteApp(app); await env.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore(); calls=[]; hosted=new Map(); nextReference=0; failFetch=false; time=Date.now();
  await db.doc('users/customer').set({role:'Customer',accountStatus:'Active',verificationStatus:'Pending'});
  await db.doc('users/provider').set({role:'Provider',accountStatus:'Active'});
  await db.doc('users/admin').set({role:'Administrator',accountStatus:'Active'});
  await db.doc('serviceProviders/provider').set({userId:'provider',isVerified:false,verificationStatus:'Pending'});
});
const create = (uid='customer', extra={}) => identity.createSession(uid,{documentType:'ID',subject:uid,...extra});
async function finish(uid='customer', decision='accept') {
  const target = db.doc(`${uid === 'customer' ? 'users' : 'serviceProviders'}/${uid}`);
  const current=(await target.get()).data();
  const session=hosted.get(current.diditSessionId);
  Object.assign(session,{completedAt:time/1000,transactionId:'final-transaction',decision,finalTransaction:{decision,
    data:{documentType:[{value:'D'}],fullName:[{value:'SYNTHETIC TEST PERSON'}],documentNumber:[{value:'TEST-NOT-REAL'}]},warning:[]}});
  return {target,current,event:{event:'docupass_conclusive',transactionId:'final-transaction',profileId:'synthetic-profile'}};
}
async function webhook(key, event, valid=true) {
  const rawBody=Buffer.from(JSON.stringify(event)), timestamp=String(Math.floor(time/1000));
  const signature='v1='+crypto.createHmac('sha256',valid?'synthetic-secret':'wrong').update(timestamp+'.').update(rawBody).digest('hex');
  const req={method:'POST',rawBody,body:event,query:{session:key},get:n=>n==='X-IDA-Timestamp'?timestamp:signature};
  const res={code:200,status(code){this.code=code;return this;},json(value){this.value=value;return this;},send(value){this.value=value;return this;}};
  await identity.webhookHandler(req,res); return res;
}

test('authenticated session uses bound owner, ID type, signed webhook destination and no client-supplied profile',async()=>{
  const result=await create('customer',{documentType:'DL',profile:'attacker',customData:'other',callback:'http://localhost:59896/?nh_role=customer'});
  const body=JSON.parse(calls[0].options.body), profile=(await db.doc('users/customer').get()).data();
  assert.equal(body.mode,0);assert.equal(body.version,'3');assert.equal(body.profile,'synthetic-profile');
  assert.equal(body.customData,profile.identitySessionKey);
  assert.deepEqual(body.profileOverride.acceptedDocuments,{documentType:'D',documentCountry:'PH',documentState:''});
  assert.match(body.profileOverride.webhook,/idAnalyzerWebhook\?session=/);
  assert.equal(body.profileOverride.docupass.allowFileUpload,false);
  assert.equal(body.profileOverride.decisions.FACE_LIVENESS_ERR.reject,0);
  for(const code of ['UNRECOGNIZED_DOCUMENT','UNRECOGNIZED_BACK_DOCUMENT','LOW_TEXT_CONFIDENCE','IMAGE_TOO_BLURRY'])assert.equal(body.profileOverride.decisions[code].reject,0);
  assert.equal(profile.verificationProvider,'idanalyzer');assert.equal(profile.diditStatus,'In Progress');assert.equal(profile.isVerified,false);
  assert.equal(result.sessionId,profile.diditSessionId);
});

test('pending link is reused without spending new credits and already verified profiles cannot be reset',async()=>{
  const first=await create();assert.deepEqual(await create(),first);assert.equal(calls.length,1);
  await db.doc('users/customer').update({isVerified:true,verificationStatus:'Approved'});
  await assert.rejects(create(),{code:'failed-precondition'});assert.equal(calls.length,1);
});

test('role switching, inactive accounts, invalid documents and external redirects fail before calling ID Analyzer',async()=>{
  await assert.rejects(create('customer',{subject:'provider'}),{code:'permission-denied'});
  await assert.rejects(create('customer',{documentType:'made-up'}),{code:'invalid-argument'});
  await assert.rejects(create('customer',{callback:'https://evil.example'}),{code:'invalid-argument'});
  await db.doc('users/customer').update({accountStatus:'Suspended'});
  await assert.rejects(create(),{code:'permission-denied'});assert.equal(calls.length,0);
});

test('concurrent starts create only one charged session',async()=>{
  const results=await Promise.allSettled([create(),create()]);
  assert.ok(results.some(r=>r.status==='fulfilled'));assert.equal(calls.length,1);
});

test('network failure clears creation reservation but preserves the prior identity decision',async()=>{
  failFetch=true;await assert.rejects(create(),{code:'unavailable'});
  const p=(await db.doc('users/customer').get()).data();assert.equal(p.identitySessionRequestId,undefined);assert.equal(p.verificationStatus,'Pending');
});

for(const [uid,decision,status] of [['customer','accept','Approved'],['provider','review','Pending'],['provider','reject','Rejected']]) {
  test(`${uid} final ${decision} result maps to ${status}; duplicate callbacks do not rewrite profile`,async()=>{
    await create(uid);const {target,current,event}=await finish(uid,decision);
    const response=await webhook(current.identitySessionKey,event);assert.equal(response.code,200);
    const first=(await target.get()).data();assert.equal(first.verificationStatus,status);assert.equal(first.isVerified,decision==='accept');
    const duplicate=await webhook(current.identitySessionKey,event);assert.equal(duplicate.value.changed,false);
    assert.equal((await target.get()).data().verificationUpdatedAt.toMillis(),first.verificationUpdatedAt.toMillis());
  });
}

test('partial results, forged signatures and unrelated transactions never approve',async()=>{
  await create();const p=(await db.doc('users/customer').get()).data();
  assert.equal((await webhook(p.identitySessionKey,{event:'new',decision:'accept'})).code,200);
  assert.equal((await webhook(p.identitySessionKey,{event:'docupass_conclusive'},false)).code,401);
  await finish();await webhook(p.identitySessionKey,{event:'docupass_conclusive',transactionId:'other'});
  assert.equal((await db.doc('users/customer').get()).data().isVerified,false);
});

test('session ownership and completion are confirmed through the API, not callback decision data',async()=>{
  await create();const {current,event}=await finish();hosted.get(current.diditSessionId).customData='another-user';
  assert.equal((await webhook(current.identitySessionKey,event)).code,503);
  assert.equal((await db.doc('users/customer').get()).data().isVerified,false);
});

test('superseded sessions and inactive accounts cannot receive an approval',async()=>{
  await create();const old=await finish();
  time+=61000;await create('customer',{documentType:'P'});
  assert.equal((await webhook(old.current.identitySessionKey,old.event)).value.ignored,'superseded session');
  const latest=await finish();await db.doc('users/customer').update({accountStatus:'Suspended'});
  await webhook(latest.current.identitySessionKey,latest.event);
  assert.equal((await latest.target.get()).data().isVerified,false);
});

test('manual rejection survives later accept callbacks and reconciliation',async()=>{
  await create();const {target,current,event}=await finish();
  await target.update({verificationManualDecision:'Rejected',verificationStatus:'Rejected',isVerified:false});
  await webhook(current.identitySessionKey,event);await identity.refresh('customer','customer');
  assert.equal((await target.get()).data().verificationStatus,'Rejected');assert.equal((await target.get()).data().isVerified,false);
});

test('a hosted result completed after the platform deadline cannot approve',async()=>{
  await create();const {target,current,event}=await finish();
  hosted.get(current.diditSessionId).completedAt = time / 1000 + 86401;
  await webhook(current.identitySessionKey,event);
  assert.equal((await target.get()).data().verificationStatus,'Rejected');
});

test('clients cannot read/write session bindings or forge server session fields',async()=>{
  const client=env.authenticatedContext('customer').firestore();
  await assertFails(setDoc(doc(client,'identitySessions','forged'),{uid:'customer',reference:'anything'}));
  await assertFails(getDoc(doc(client,'identitySessions','private')));
  await assertFails(updateDoc(doc(client,'users','customer'),{identitySessionKey:crypto.randomUUID()}));
  await assertFails(updateDoc(doc(client,'users','customer'),{verificationDecision:'accept'}));
  await assertFails(updateDoc(doc(client,'users','customer'),{verificationRetakeRequired:false,verificationIssueCodes:[]}));
  const signup=env.authenticatedContext('new-user').firestore();
  await assertFails(setDoc(doc(signup,'users','new-user'),{role:'Customer',accountStatus:'Active',identitySessionKey:'forged'}));
});

for(const code of ['UNRECOGNIZED_DOCUMENT','UNRECOGNIZED_BACK_DOCUMENT','LOW_TEXT_CONFIDENCE','IMAGE_TOO_BLURRY']) {
  test(`${code} requires a retake even when hosted verification says accept`,async()=>{
    await create();const {target,current,event}=await finish();
    hosted.get(current.diditSessionId).finalTransaction.warning=[{code,decision:'accept'}];
    await webhook(current.identitySessionKey,event);
    const result=(await target.get()).data();
    assert.equal(result.isVerified,false);assert.equal(result.verificationRetakeRequired,true);
    assert.equal(result.verificationStatus,'Rejected');assert.ok(result.verificationIssueCodes.includes(code));
  });
}

const review=(data,uid='admin',token={})=>require('../identity_review_commands')({db,functions,refreshIdentity:identity.refresh})(data,{auth:{uid,token}});
const action=(name,subject='customer')=>({action:name,subject,userId:subject});
test('administrator can reject a submitted check without vendor availability and cannot impersonate a reviewer',async()=>{
  await create();failFetch=true;
  await review({...action('reject'),reviewedByUserId:'forged',reviewedByRole:'Customer'});
  const result=(await db.doc('users/customer').get()).data();
  assert.equal(result.verificationStatus,'Rejected');assert.equal(result.verificationReviewedBy,'admin');
  assert.equal(result.verificationReviewedByRole,'Administrator');assert.equal(result.isVerified,false);
  assert.equal((await db.collection('auditLogs').get()).size,1);
});
test('only an active administrator with required MFA can review identities',async()=>{
  await create();
  await assert.rejects(review(action('reject'),'customer'),{code:'permission-denied'});
  await db.doc('users/admin').update({accountStatus:'Suspended'});
  await assert.rejects(review(action('reject')),{code:'permission-denied'});
  await db.doc('users/admin').update({accountStatus:'Active'});
  await db.doc('securityPolicy/admin').set({requireMfa:true});
  await assert.rejects(review(action('reject')),{code:'permission-denied'});
  await review(action('reject'),'admin',{firebase:{sign_in_second_factor:'phone'}});
});
test('incomplete, unreadable and failed submissions cannot receive manual approval',async()=>{
  await create();await assert.rejects(review(action('approve')),e=>e.code==='failed-precondition'&&/readable/.test(e.message));
  const {current}=await finish();hosted.get(current.diditSessionId).finalTransaction.warning=[{code:'UNRECOGNIZED_BACK_DOCUMENT'}];
  await assert.rejects(review(action('approve')),e=>e.code==='failed-precondition'&&/retake/.test(e.message));
  assert.equal((await db.doc('users/customer').get()).data().isVerified,false);
});
for(const subject of ['customer','provider']) {
  test(`readable ${subject} review can be approved and survives duplicate vendor updates`,async()=>{
    await create(subject);await finish(subject,'review');
    await review(action('approve',subject));
    const target=db.doc(`${subject==='customer'?'users':'serviceProviders'}/${subject}`);
    assert.equal((await target.get()).data().isVerified,true);
    await identity.refresh(subject,subject);
    assert.equal((await target.get()).data().verificationStatus,'Approved');
    assert.equal((await review(action('approve',subject))).duplicate,true);
    assert.equal((await db.collection('auditLogs').get()).size,1);
  });
}
test('quality failures revoke a prior manual approval on the next authoritative refresh',async()=>{
  await create();const {current}=await finish('customer','review');await review(action('approve'));
  hosted.get(current.diditSessionId).finalTransaction.warning=[{code:'LOW_TEXT_CONFIDENCE',decision:'accept'}];
  await identity.refresh('customer','customer');
  const result=(await db.doc('users/customer').get()).data();
  assert.equal(result.isVerified,false);assert.equal(result.verificationStatus,'Rejected');assert.equal(result.verificationRetakeRequired,true);
});
test('legacy stray provider records report a role mismatch instead of a permissions error',async()=>{
  await db.doc('serviceProviders/customer').set({userId:'customer',diditStatus:'In Progress',verificationProvider:'idanalyzer'});
  await assert.rejects(review({action:'reject',subject:'provider',userId:'customer'}),e=>e.code==='failed-precondition'&&/account role/.test(e.message));
});
