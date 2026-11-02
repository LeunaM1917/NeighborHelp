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
  await db.collection('serviceProviders').doc('provider').set({userId:'provider',isVerified:true,location:new GeoPoint(7.3,125.6),serviceRadiusKm:10,acceptedBookings:0,completedBookings:0});
  await db.collection('services').doc('cleaning').set({providerId:'provider',category:'Cleaning',serviceTitle:'House cleaning',isActive:true,approvalStatus:'Approved',estimatedPrice:100,priceType:'Hourly'});
});
const auth = uid => ({auth:{uid}});
const start = () => Date.now() + 3 * 3600000;
async function create(id, uid='customer', at=start()) {
  return command({action:'create',bookingId:id,serviceId:'cleaning',serviceLocation:'Panabo City, test address',
    location:{latitude:7.3,longitude:125.6}, scheduledDate:at, scheduledEndDate:at+3600000},auth(uid));
}
test('creation validates identity, coverage, schedule, service approval and server fee', async () => {
  await create('one');
  const b = (await db.doc('bookings/one').get()).data();
  assert.equal(b.totalFee,100); assert.equal(b.status,'Pending');
  assert.equal((await db.collection('auditLogs').get()).size,1);
  await assert.rejects(command({action:'create',bookingId:'past',serviceId:'cleaning',location:{latitude:7.3,longitude:125.6},serviceLocation:'Address',scheduledDate:1,scheduledEndDate:100},auth('customer')),/future/);
  await db.doc('serviceProviders/provider').update({isVerified:false});
  await assert.rejects(create('blocked'),/eligible/);
});
test('two concurrent accepts cannot double-book the same provider', async () => {
  const at=start(); await create('one','customer',at); await create('two','second',at);
  const results = await Promise.allSettled(['one','two'].map(bookingId=> command({action:'accept',bookingId},auth('provider'))));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.filter(r=>r.status==='rejected').length,1);
  assert.equal((await db.doc('serviceProviders/provider').get()).data().acceptedBookings,1);
});
test('status transitions and counters cannot be replayed or performed by another user', async () => {
  await create('one');
  await assert.rejects(command({action:'accept',bookingId:'one'},auth('customer')),/provider/);
  await command({action:'accept',bookingId:'one'},auth('provider'));
  await assert.rejects(command({action:'accept',bookingId:'one'},auth('provider')),/pending/);
  await assert.rejects(command({action:'complete',bookingId:'one'},auth('provider')),/Start/);
  await assert.rejects(command({action:'start',bookingId:'one'},auth('provider')),/start time/);
  await assert.rejects(command({action:'cancel',bookingId:'one',reason:'Unauthorized cancellation'},auth('second')),/another/);
  await command({action:'cancel',bookingId:'one',reason:'Customer needs to cancel this appointment.'},auth('customer'));
  assert.equal((await db.doc('bookings/one').get()).data().cancelledByRole,'customer');
});
test('rescheduling keeps the original schedule until the provider agrees and rejects conflicts', async () => {
  const at=start(); await create('one','customer',at); await command({action:'accept',bookingId:'one'},auth('provider'));
  const later=at+4*3600000;
  await command({action:'requestReschedule',bookingId:'one',scheduledDate:later},auth('customer'));
  assert.equal((await db.doc('bookings/one').get()).data().scheduledDate.toMillis(),at);
  await command({action:'approveReschedule',bookingId:'one'},auth('provider'));
  const b=(await db.doc('bookings/one').get()).data(); assert.equal(b.scheduledDate.toMillis(),later); assert.equal(b.rescheduleRequest,undefined);
  await create('two','second',at); await command({action:'accept',bookingId:'two'},auth('provider'));
  await command({action:'requestReschedule',bookingId:'two',scheduledDate:later},auth('second'));
  await assert.rejects(command({action:'approveReschedule',bookingId:'two'},auth('provider')),/already has/);
});
test('a missing or unrelated certificate blocks technical service bookings', async () => {
  await db.doc('services/cleaning').update({category:'Home Repair',serviceTitle:'Carpentry'});
  await assert.rejects(create('one'),/certificate/);
});
