const {credentials,offer,futureWorkStart}=require('./marketplace_fixtures');
const { GeoPoint, getFirestore } = require('firebase-admin/firestore');
const {before, after, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');
const {initializeTestEnvironment} = require('@firebase/rules-unit-testing');
let env, app, db, command;
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Use the demo Firestore emulator.');
  env = await initializeTestEnvironment({projectId:'demo-neighborhelp'});
  app = admin.initializeApp({projectId:'demo-neighborhelp'}, 'booking-tests');
  db = getFirestore(app);
  command = require('../booking_commands')({db,admin,functions});
});
after(async () => { await require('firebase-admin/app').deleteApp(app); await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  for (const [id, role] of [['customer','Customer'],['second','Customer'],['provider','Provider'],['admin','Administrator']]) await db.collection('users').doc(id).set({role,accountStatus:'Active'});
  await db.collection('serviceProviders').doc('provider').set({userId:'provider',isVerified:true,location:new GeoPoint(7.3,125.6),serviceRadiusKm:10,acceptedBookings:0,completedBookings:0,...credentials()});
  await db.collection('services').doc('cleaning').set({providerId:'provider',category:'Cleaning',serviceTitle:'House cleaning',isActive:true,approvalStatus:'Approved',estimatedPrice:100,priceType:'Hourly'});
});
const auth = uid => ({auth:{uid,token:{email_verified:true}}});
const start = () => futureWorkStart();
async function create(id, uid='customer', at=start()) {
  const inquiryId=require('node:crypto').createHash('sha256').update(JSON.stringify([uid,'provider'])).digest('hex');
  await db.doc('inquiries/'+inquiryId).set({customerId:uid,providerId:'provider',participantIds:[uid,'provider'],customerMessageCount:1,providerMessageCount:1});
  const data={bookingId:id,serviceId:'cleaning',inquiryId,serviceLocation:'Panabo City, test address',location:{latitude:7.3,longitude:125.6},scheduledDate:at,...offer()};
  const preview=await command({action:'preview',...data},auth(uid));
  return command({action:'create',...data,agreementHash:preview.agreement.hash},auth(uid));
}
async function respond(bookingId,uid='provider') {
  const b=(await db.doc('bookings/'+bookingId).get()).data();
  return command({action:'accept',bookingId,acceptAgreement:true,agreementHash:b.agreement.hash},auth(uid));
}

test('creation validates identity, coverage, schedule, service approval and server fee', async () => {
  await create('one');
  const b = (await db.doc('bookings/one').get()).data();
  assert.equal(b.totalFee,100); assert.equal(b.status,'Pending');
  assert.equal((await db.collection('auditLogs').get()).size,1);
  await assert.rejects(create('past','customer',1),/future/);
  await db.doc('serviceProviders/provider').update({isVerified:false});
  await assert.rejects(create('blocked'),/eligible/);
});
test('two concurrent accepts cannot double-book the same provider', async () => {
  const at=start(); await create('one','customer',at); await create('two','second',at);
  const results = await Promise.allSettled(['one','two'].map(bookingId=> respond(bookingId)));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.filter(r=>r.status==='rejected').length,1);
  assert.equal((await db.doc('serviceProviders/provider').get()).data().acceptedBookings,1);
});
test('status transitions and counters cannot be replayed or performed by another user', async () => {
  await create('one');
  await assert.rejects(command({action:'accept',bookingId:'one'},auth('customer')),/provider/);
  await respond('one');
  await assert.rejects(respond('one'),/pending/);
  await assert.rejects(command({action:'complete',bookingId:'one'},auth('provider')),/Start/);
  await assert.rejects(command({action:'start',bookingId:'one'},auth('provider')),/start time/);
  await assert.rejects(command({action:'cancel',bookingId:'one',reason:'Unauthorized cancellation'},auth('second')),/another/);
  await command({action:'cancel',bookingId:'one',reason:'Customer needs to cancel this appointment.'},auth('customer'));
  assert.equal((await db.doc('bookings/one').get()).data().cancelledByRole,'customer');
});
test('legacy rescheduling keeps the original schedule until the provider agrees and rejects conflicts', async () => {
  const at=start(); await create('one','customer',at); await respond('one');
  await db.doc('bookings/one').update({agreement:require('firebase-admin/firestore').FieldValue.delete()});
  const later=at+4*3600000;
  await command({action:'requestReschedule',bookingId:'one',scheduledDate:later},auth('customer'));
  assert.equal((await db.doc('bookings/one').get()).data().scheduledDate.toMillis(),at);
  await command({action:'approveReschedule',bookingId:'one'},auth('provider'));
  const b=(await db.doc('bookings/one').get()).data(); assert.equal(b.scheduledDate.toMillis(),later); assert.equal(b.rescheduleRequest,undefined);
  await create('two','second',at); await respond('two');
  await db.doc('bookings/two').update({agreement:require('firebase-admin/firestore').FieldValue.delete()});
  await command({action:'requestReschedule',bookingId:'two',scheduledDate:later},auth('second'));
  await assert.rejects(command({action:'approveReschedule',bookingId:'two'},auth('provider')),/already has/);
});
test('a missing or unrelated certificate blocks technical service bookings', async () => {
  await db.doc('services/cleaning').update({category:'Home Repair',serviceTitle:'Carpentry'});
  await assert.rejects(create('one'),/certificate/);
});
