const {credentials}=require('./marketplace_fixtures');
const { Timestamp, GeoPoint, getFirestore } = require('firebase-admin/firestore');
const {before, after, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');
const {initializeTestEnvironment} = require('@firebase/rules-unit-testing');
let env, app, db, ops;
const sent = [];
const auth = uid => ({auth:{uid,token:{email_verified:false}}});
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Demo emulator required.');
  env = await initializeTestEnvironment({projectId:'demo-neighborhelp'});
  app = admin.initializeApp({projectId:'demo-neighborhelp'}, 'platform-tests');
  db = getFirestore(app);
  const messaging = ()=>({sendEachForMulticast:async payload => {
    sent.push(payload); return {responses:payload.tokens.map(token => token === 'expired' ? {success:false,error:{code:'messaging/registration-token-not-registered'}} : {success:true})};
  }});
  ops = require('../platform_operations')({db,admin,functions,messaging,region:'us-central1'});
});
after(async () => {await require('firebase-admin/app').deleteApp(app);await env?.cleanup();});
beforeEach(async () => {
  await env.clearFirestore(); sent.length=0;
  for (const [uid,role] of [['admin','Administrator'],['customer','Customer'],['provider','Provider']]) await db.doc(`users/${uid}`).set({role,accountStatus:'Active',email:'private@example.test',contactNumber:'private',fullName:uid,diditSessionId:'private-session'});
});
test('booking notifications are idempotent and preserve read receipts on event retries', async () => {
  const before={status:'In Progress',customerId:'customer',providerId:'provider',scheduledDate:Timestamp.now()};
  const after={...before,status:'Milestone Complete',updatedBy:'provider'};
  const change={before:{data:()=>before},after:{data:()=>after,id:'booking'}};
  await ops.onBookingUpdated.run(change,{eventId:'complete-event'});
  const notifications=await db.collection('notifications').get(); assert.equal(notifications.size,3);
  await notifications.docs[0].ref.update({isRead:true});
  await ops.onBookingUpdated.run(change,{eventId:'complete-event'});
  assert.equal((await db.collection('notifications').get()).size,3);
  assert.equal((await notifications.docs[0].ref.get()).data().isRead,true);
});
test('appointment reminders are created once for each participant and schedule', async () => {
  await db.doc('bookings/soon').set({customerId:'customer',providerId:'provider',status:'Accepted',scheduledDate:Timestamp.fromMillis(Date.now()+30*60000)});
  await ops.appointmentReminders.run({}); await ops.appointmentReminders.run({});
  assert.equal((await db.collection('notifications').get()).size,2);
});
test('push delivery uses stored device tokens and cleans up invalid registrations', async () => {
  await db.doc('users/customer/devices/a').set({token:'valid'});
  await db.doc('users/customer/devices/b').set({token:'expired'});
  await ops.deliverPushNotification.run({id:'n',data:()=>({userId:'customer',title:'Booking accepted',message:'Ready',relatedBookingId:'b'})});
  assert.deepEqual(sent[0].tokens,['valid','expired']);
  assert.equal((await db.doc('users/customer/devices/b').get()).exists,false);
});
test('public profile projections never expose email, contact details or identity session IDs', async () => {
  const directory=await ops.getPublicDirectory.run({},auth('customer'));
  assert.equal(directory.records.length,3);
  for (const row of directory.records) for (const key of ['email','contactNumber','diditSessionId']) assert.equal(row[key],undefined);
});

test('customer map pins stay private while an eligible provider service base reaches its public projection', async () => {
  const customer=(await db.doc('users/customer').get()).data();
  const afterCustomer={...customer,location:new GeoPoint(7.3,125.6),updatedBy:'customer'};
  await db.doc('users/customer').set(afterCustomer);
  await ops.auditUsers.run({before:{exists:true,data:()=>customer},after:{exists:true,data:()=>afterCustomer}},
    {params:{id:'customer'},eventId:'customer-pin'});
  assert.equal((await db.doc('publicProfiles/customer').get()).data().location,undefined);
  const profile={...credentials(),userId:'provider',isVerified:true,verificationStatus:'Approved',location:new GeoPoint(14.5995,120.9842)};
  const updated={...profile,location:new GeoPoint(7.31,125.61),updatedBy:'provider'};
  await db.doc('serviceProviders/provider').set(updated);
  await db.doc('services/clean').set({providerId:'provider',serviceTitle:'House cleaning',category:'Cleaning',isActive:true,approvalStatus:'Approved'});
  await ops.auditServiceProviders.run({before:{exists:true,data:()=>profile},after:{exists:true,data:()=>updated}},
    {params:{id:'provider'},eventId:'provider-pin'});
  const projection=(await db.doc('publicProviders/provider').get()).data();
  const base=require('../provider_area').base(updated);
  assert.deepEqual(projection.location,{latitude:base.latitude,longitude:base.longitude});
});
test('a device moves to its current signed-in user and cannot be unregistered by another account', async () => {
  const data={token:'test-device-token-with-sufficient-length',platform:'web'};
  const first=await ops.registerPushDevice.run(data,auth('customer'));
  await ops.registerPushDevice.run({...data,action:'unregister'},auth('provider'));
  assert.equal((await db.doc(`users/customer/devices/${first.id}`).get()).exists,true);
  await ops.registerPushDevice.run(data,auth('provider'));
  assert.equal((await db.doc(`users/customer/devices/${first.id}`).get()).exists,false);
  assert.equal((await db.doc(`users/provider/devices/${first.id}`).get()).exists,true);
});
test('provider discovery returns only eligible services and omits verification evidence', async () => {
  await db.doc('serviceProviders/provider').set({...credentials(),userId:'provider',isVerified:true,verificationStatus:'Approved',diditSessionId:'private',governmentIdTypeCode:'ID',location:new GeoPoint(7.3,125.6),serviceArea:'Panabo City',serviceRadiusKm:5});
  await db.doc('services/service').set({providerId:'provider',serviceTitle:'House cleaning',category:'Cleaning',isActive:true,approvalStatus:'Approved'});
  const result=await ops.getPublicProviders.run({},auth('customer'));
  assert.equal(result.records.length,1);
  assert.deepEqual(result.records[0].eligibleServiceIds,['service']);
  assert.equal(result.records[0].diditSessionId,undefined);
  assert.equal(result.records[0].governmentIdTypeCode,undefined);
  await db.doc('users/provider').update({accountStatus:'Suspended'});
  assert.equal((await ops.getPublicProviders.run({},auth('customer'))).records.length,0);
});
test('policy maintenance hides unsupported listings and refreshes expiry-bound projections without deleting history',async()=>{
  await db.doc('serviceProviders/provider').set({...credentials(),userId:'provider',isVerified:true,verificationStatus:'Approved'});
  await db.doc('services/valid').set({providerId:'provider',category:'Cleaning',serviceTitle:'House Cleaning',isActive:true,approvalStatus:'Approved'});
  await db.doc('services/unsupported').set({providerId:'provider',category:'Tutoring',serviceTitle:'Math Tutoring',isActive:true,approvalStatus:'Approved'});
  await db.doc('bookings/history').set({providerId:'provider',customerId:'customer',serviceId:'unsupported',status:'Completed',totalFee:500});
  await ops.enforceMarketplacePolicy.run({});
  assert.equal((await db.doc('services/unsupported').get()).data().isActive,false);
  assert.equal((await db.doc('bookings/history').get()).data().totalFee,500);
  const projection=(await db.doc('publicProviders/provider').get()).data();
  assert.equal(projection.marketplacePolicyVersion,3);assert.deepEqual(projection.eligibleServiceIds,['valid']);assert.ok(projection.eligibleServiceExpiries.valid>Date.now());
  await db.doc('serviceProviders/provider').update({approvedCertificationIds:[]});
  await ops.enforceMarketplacePolicy.run({});
  assert.equal((await db.doc('services/valid').get()).data().isActive,false);assert.equal((await db.doc('publicProviders/provider').get()).exists,false);
});
test('scheduled announcements are limited to the chosen active audience and sent once', async () => {
  const scheduled = await ops.queueAnnouncement.run({title:'Pilot update',message:'Please check your bookings.',audience:'Customers only',scheduledAt:Date.now()+60000},auth('admin'));
  await db.doc(`scheduledAnnouncements/${scheduled.id}`).update({scheduledAt:Timestamp.fromMillis(Date.now()-1000)});
  await ops.appointmentReminders.run({}); await ops.appointmentReminders.run({});
  const results=await db.collection('notifications').get();
  assert.equal(results.size,1); assert.equal(results.docs[0].data().userId,'customer');
});
test('retention operations reject active records and preserve old closed records during archive/restore', async () => {
  const old=Timestamp.fromMillis(Date.now()-200*86400000);
  await db.doc('bookings/old').set({status:'Completed',createdAt:old,updatedAt:old,customerId:'customer',providerId:'provider',totalFee:500});
  await db.doc('bookings/active').set({status:'Accepted',createdAt:old,updatedAt:old});
  const args={action:'archive',collection:'bookings',reason:'Retention review after the pilot evaluation period.'};
  await assert.rejects(ops.adminDataOperation.run({...args,ids:['old']},auth('customer')),/administrator/);
  await assert.rejects(ops.adminDataOperation.run({...args,ids:['old','active']},auth('admin')),/closed/);
  assert.equal((await db.doc('bookings/old').get()).data().archived,undefined);
  await ops.adminDataOperation.run({...args,ids:['old']},auth('admin'));
  assert.equal((await db.doc('bookings/old').get()).data().totalFee,500);
  assert.equal((await db.doc('bookings/old').get()).data().archived,true);
  await ops.adminDataOperation.run({...args,action:'restore',ids:['old']},auth('admin'));
  assert.equal((await db.doc('bookings/old').get()).data().archived,false);
  assert.equal((await db.collection('auditLogs').get()).size,2);
});
