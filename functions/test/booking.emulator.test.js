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
  for (const [id, role] of [['customer','Customer'],['second','Customer'],['provider','Provider'],['admin','Administrator']]) await db.collection('users').doc(id).set({role,accountStatus:'Active',fullName:`Test ${id}`,contactNumber:'09123456789',address:'New Visayas, Panabo City',isVerified:role==='Customer'});
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

test('profile completion and approved customer KYC cannot be bypassed by a direct offer call', async () => {
  for (const patch of [
    {isVerified:false,verificationStatus:'Pending',diditStatus:'Approved'},
    {isVerified:false,verificationStatus:'Rejected'},
    {contactNumber:''}, {fullName:''}, {address:''},
  ]) {
    const original=(await db.doc('users/customer').get()).data();
    await db.doc('users/customer').update(patch);
    await assert.rejects(create('blocked'), /Complete your profile and government ID verification/);
    await db.doc('users/customer').set(original);
  }
  await create('ready');
  await db.doc('users/customer').update({isVerified:false,verificationStatus:'Pending'});
  await assert.rejects(respond('ready'), /Both parties must complete account setup/);
  assert.equal((await db.doc('bookings/ready').get()).data().status,'Pending');
});

test('incomplete provider details block offers even when provider KYC is approved', async () => {
  await db.doc('users/provider').update({contactNumber:''});
  await assert.rejects(create('blocked'), /provider must complete/);
  await db.doc('users/provider').update({contactNumber:'09123456789'});
  await db.doc('serviceProviders/provider').update({serviceBarangayIds:[]});
  await assert.rejects(create('blocked'), /provider must complete/);
});

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

async function direct(id, extra = {}, uid = 'customer') {
  const at = start();
  return command({action: 'create', bookingId: id, serviceId: 'cleaning',
    serviceLocation: 'Panabo City, test address', location: {latitude: 7.3, longitude: 125.6},
    scheduledDate: at, scheduledEndDate: at + 3600000, pricingType: 'hourly', ...extra}, auth(uid));
}
test('direct booking works without chat or contracts through completion', async () => {
  await direct('direct', {pricingType: 'fixed', totalFee: 350.25});
  await command({action: 'accept', bookingId: 'direct'}, auth('provider'));
  let b = (await db.doc('bookings/direct').get()).data();
  assert.equal(b.status, 'Accepted');
  assert.equal(b.totalFee, 350.25);
  for (const field of ['agreement', 'contractId', 'inquiryId', 'milestoneNumber']) assert.equal(b[field], undefined);
  assert.equal((await db.collection('contracts').get()).size, 0);
  assert.equal((await db.doc('bookings/direct').collection('agreementVersions').get()).size, 0);
  // Advance the appointment to exercise real start/report/confirmation commands.
  const {Timestamp} = require('firebase-admin/firestore');
  await db.doc('bookings/direct').update({scheduledDate: Timestamp.fromMillis(Date.now() - 3600000),
    scheduledEndDate: Timestamp.fromMillis(Date.now() + 3600000)});
  await command({action: 'start', bookingId: 'direct'}, auth('provider'));
  await command({action: 'complete', bookingId: 'direct'}, auth('provider'));
  await assert.rejects(command({action: 'confirmCompletion', bookingId: 'direct', confirmDeliverables: true}, auth('second')), /another account/);
  await command({action: 'confirmCompletion', bookingId: 'direct', confirmDeliverables: true}, auth('customer'));
  b = (await db.doc('bookings/direct').get()).data();
  assert.equal(b.status, 'Completed');
  const p = (await db.doc('serviceProviders/provider').get()).data();
  assert.equal(p.acceptedBookings, 1); assert.equal(p.completedBookings, 1);
  await assert.rejects(command({action: 'confirmCompletion', bookingId: 'direct', confirmDeliverables: true}, auth('customer')), /reported completion/);
});
test('direct requests retain server pricing, response permissions and conflict protection', async () => {
  const at = start();
  await direct('one', {totalFee: 1, hourlyRate: 1});
  await direct('two', {}, 'second');
  assert.equal((await db.doc('bookings/one').get()).data().totalFee, 100);
  await assert.rejects(command({action: 'accept', bookingId: 'one'}, auth('customer')), /provider/);
  const outcomes = await Promise.allSettled(['one', 'two'].map(bookingId => command({action: 'accept', bookingId}, auth('provider'))));
  assert.equal(outcomes.filter(x => x.status === 'fulfilled').length, 1);
  const pending = (await db.collection('bookings').where('status', '==', 'Pending').get()).docs[0];
  await command({action: 'decline', bookingId: pending.id}, auth('provider'));
  assert.equal((await pending.ref.get()).data().status, 'Declined');
  assert.equal((await db.collection('contracts').get()).size, 0);
  await direct('reschedule', {scheduledDate: at + 4 * 3600000, scheduledEndDate: at + 5 * 3600000});
  await command({action: 'requestReschedule', bookingId: 'reschedule', scheduledDate: at + 6 * 3600000}, auth('customer'));
  assert.equal((await db.doc('bookings/reschedule').get()).data().scheduledDate.toMillis(), at + 4 * 3600000);
  await command({action: 'approveReschedule', bookingId: 'reschedule'}, auth('provider'));
  assert.equal((await db.doc('bookings/reschedule').get()).data().scheduledDate.toMillis(), at + 6 * 3600000);
});
test('direct requests cannot bypass coverage, verification or approval', async () => {
  await assert.rejects(direct('outside', {location: {latitude: 14.6, longitude: 121}}), /barangays/);
  await db.doc('users/customer').update({isVerified: false});
  await assert.rejects(direct('unverified'), /government ID/);
  await db.doc('users/customer').update({isVerified: true});
  await db.doc('services/cleaning').update({approvalStatus: 'Pending'});
  await assert.rejects(direct('unapproved'), /unavailable/);
});
test('direct bookings respect conversation blocks without requiring a chat', async () => {
  await direct('pending');
  const key = require('node:crypto').createHash('sha256').update(JSON.stringify(['customer', 'provider'])).digest('hex');
  await db.doc(`inquiries/${key}`).set({blockedBy: ['provider']});
  await assert.rejects(direct('blocked'), /blocked/);
  await assert.rejects(command({action: 'accept', bookingId: 'pending'}, auth('provider')), /blocked/);
  assert.equal((await db.doc('bookings/pending').get()).data().status, 'Pending');
});
test('an eligible citywide provider can accept a booking at the former city-center coverage gap', async () => {
  await direct('city-center', {location: {latitude: 7.3081, longitude: 125.6842}});
  await command({action: 'accept', bookingId: 'city-center'}, auth('provider'));
  assert.equal((await db.doc('bookings/city-center').get()).data().status, 'Accepted');
});
