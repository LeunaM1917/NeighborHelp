'use strict';
const {before,after,beforeEach,test}=require('node:test');
const assert=require('node:assert/strict');
const admin=require('firebase-admin');
const functions=require('firebase-functions/v1');
const {getFirestore,Timestamp,GeoPoint}=require('firebase-admin/firestore');
const {initializeTestEnvironment}=require('@firebase/rules-unit-testing');
const {credentials,futureWorkStart}=require('./marketplace_fixtures');
let env,app,db,book,amend,available;
const auth=uid=>({auth:{uid,token:{email_verified:true}}});
before(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw new Error('Demo emulator required.');
  env=await initializeTestEnvironment({projectId:'demo-neighborhelp'});
  app=admin.initializeApp({projectId:'demo-neighborhelp'},'booking-estimates-tests');db=getFirestore(app);
  book=require('../booking_commands')({db,admin,functions});amend=require('../agreement_commands')({db,functions});available=require('../availability_command')({db,functions});
});
after(async()=>{await require('firebase-admin/app').deleteApp(app);await env?.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore();
  for(const [id,role] of [['customer','Customer'],['second','Customer'],['provider','Provider'],['stranger','Customer']])
    await db.doc(`users/${id}`).set({role,accountStatus:'Active',fullName:`Test ${id}`,contactNumber:'09123456789',address:'New Visayas, Panabo City',isVerified:true});
  await db.doc('serviceProviders/provider').set({...credentials(),userId:'provider',isVerified:true,location:new GeoPoint(7.3,125.6),acceptedBookings:0,completedBookings:0});
  await db.doc('services/service').set({providerId:'provider',category:'Cleaning',serviceTitle:'House cleaning',approvalStatus:'Approved',isActive:true,estimatedPrice:125.5,priceType:'hourly',estimatedDuration:'1 hour 30 minutes'});
});
const at=()=>futureWorkStart();
async function request(id='one',uid='customer',extra={}) {
  return book({action:'create',bookingId:id,requestVersion:2,serviceId:'service',scheduledDate:at(),
    serviceLocation:'New Visayas, Panabo City',location:{latitude:7.3,longitude:125.6},notes:'Clean the living room and kitchen.',...extra},auth(uid));
}
async function propose(id='one',revisionId='estimate-one',extra={}) {
  const payload={bookingId:id,revisionId,scheduledDate:at(),durationHours:2.25,pricingType:'hourly',proposedRate:125.55,
    reason:'Provider has reviewed the job and estimated the required work.',acceptAgreement:true,...extra};
  const preview=await amend({action:'preview',...payload},auth('provider'));
  await amend({action:'propose',...payload,agreementHash:preview.agreement.hash},auth('provider'));
  return {action:'accept',bookingId:id,revisionId,agreementHash:preview.agreement.hash,acceptAgreement:true};
}
async function confirmed() {await request();await amend(await propose(),auth('customer'));}

test('new requests ignore customer duration and price; only customer approval of provider terms confirms work',async()=>{
  await request('one','customer',{totalFee:.01,durationHours:20,scheduledEndDate:at()+20*3600000,pricingType:'fixed'});
  let b=(await db.doc('bookings/one').get()).data();
  assert.equal(b.totalFee,188.25);assert.equal(b.durationHours,1.5);assert.equal(b.pricingType,'hourly');assert.equal(b.status,'Pending');
  await assert.rejects(book({action:'accept',bookingId:'one'},auth('provider')),/customer approval/);
  await assert.rejects(amend({action:'preview',bookingId:'one',revisionId:'customer-change'},auth('customer')),/Only the provider/);
  const approval=await propose();b=(await db.doc('bookings/one').get()).data();
  assert.equal(b.status,'Changes Requested');assert.equal(b.totalFee,188.25);assert.equal(b.durationHours,1.5);
  await assert.rejects(amend(approval,auth('provider')),/customer/);
  await assert.rejects(amend({...approval,agreementHash:'wrong'},auth('customer')),/exact provider estimate/);
  await amend(approval,auth('customer'));await amend(approval,auth('customer'));
  b=(await db.doc('bookings/one').get()).data();
  assert.equal(b.status,'Accepted');assert.equal(b.totalFee,282.49);assert.equal(b.durationHours,2.25);
  assert.equal(b.customerAcceptedHash,b.providerAcceptedHash);assert.equal(b.confirmedTerms.hash,approval.agreementHash);
  assert.equal(b.pendingAmendmentId,undefined);assert.equal(b.preferredScheduledDate.toMillis(),at());
  assert.equal((await db.doc('serviceProviders/provider').get()).data().acceptedBookings,1);
  assert.equal((await db.collection('bookings/one/agreementVersions').get()).size,1);
  const notifications=await db.collection('notifications').where('notificationType','==','Booking Estimate').get();
  assert.equal(notifications.size,4);assert.ok(notifications.docs.some(d=>d.data().userId==='customer'));assert.ok(notifications.docs.some(d=>d.data().userId==='provider'));
});
test('concurrent customer approvals cannot reserve overlapping provider windows',async()=>{
  await request('one');await request('two','second');
  const first=await propose('one','one-estimate'),second=await propose('two','two-estimate');
  const results=await Promise.allSettled([amend(first,auth('customer')),amend(second,auth('second'))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.filter(r=>r.status==='rejected').length,1);
  assert.equal((await db.doc('serviceProviders/provider').get()).data().acceptedBookings,1);
});
test('declining and withdrawing revised estimates preserve every confirmed term and history',async()=>{
  await confirmed();const original=(await db.doc('bookings/one').get()).data();
  const next=await propose('one','next',{scheduledDate:at()+4*3600000,pricingType:'fixed',proposedRate:675.25});
  let b=(await db.doc('bookings/one').get()).data();assert.equal(b.totalFee,original.totalFee);assert.equal(b.scheduledDate.toMillis(),original.scheduledDate.toMillis());
  await amend({...next,action:'decline'},auth('customer'));
  const other=await propose('one','other',{scheduledDate:at()+4*3600000});
  await amend({...other,action:'withdraw'},auth('provider'));
  b=(await db.doc('bookings/one').get()).data();assert.equal(b.status,'Accepted');assert.equal(b.confirmedTerms.hash,original.confirmedTerms.hash);assert.equal(b.pendingAmendmentId,undefined);
  assert.equal((await db.collection('bookings/one/amendments').get()).size,3);
});
test('approval rechecks unavailable dates, working hours and competing accepted jobs',async()=>{
  await request();const approval=await propose();
  await db.doc('serviceProviders/provider').update({timeOff:[{start:Timestamp.fromMillis(at()),end:Timestamp.fromMillis(at()+4*3600000)}]});
  await assert.rejects(amend(approval,auth('customer')),/working hours or time off/);
  await db.doc('serviceProviders/provider').set({...credentials(),isVerified:true},{merge:true});
  await db.doc('serviceProviders/provider').update({timeOff:[]});
  const disabled=Object.fromEntries(Object.entries(credentials().weeklyAvailability).map(([day,hours])=>[day,{...hours,enabled:false}]));
  await db.doc('serviceProviders/provider').update({weeklyAvailability:disabled});
  await assert.rejects(amend(approval,auth('customer')),/working hours or time off/);
  await db.doc('serviceProviders/provider').update({weeklyAvailability:credentials().weeklyAvailability});
  await db.doc('bookings/competing').set({providerId:'provider',customerId:'second',status:'Accepted',scheduledDate:Timestamp.fromMillis(at()),scheduledEndDate:Timestamp.fromMillis(at()+3600000)});
  await assert.rejects(amend(approval,auth('customer')),/overlaps/);
  assert.equal((await db.doc('bookings/one').get()).data().status,'Changes Requested');
});
test('slot responses expose only available starts and customers cannot override duration or exclude other jobs',async()=>{
  await request('one','second');await amend(await propose(),auth('second'));
  const midnight=Math.floor((at()+8*3600000)/86400000)*86400000-8*3600000;
  const payload={action:'slots',providerIds:['provider'],serviceId:'service',startDay:midnight,days:2};
  const result=await available(payload,auth('customer'));
  assert.equal(result.timezone,'Asia/Manila');assert.equal(result.estimatedDurationHours,1.5);
  assert.ok(!result.days[0].starts.includes(at()));
  assert.equal(JSON.stringify(result).includes('customerId'),false);assert.equal(JSON.stringify(result).includes('bookingId'),false);
  await assert.rejects(available({...payload,durationHours:.25},auth('customer')),/Only the provider/);
  await assert.rejects(available({...payload,excludeBookingId:'one'},auth('customer')),/participant/);
});
test('working hours cannot invalidate accepted work, and reschedules require revised customer approval',async()=>{
  await confirmed();
  const disabled=Object.fromEntries(Object.entries(credentials().weeklyAvailability).map(([day,hours])=>[day,{...hours,enabled:false}]));
  await assert.rejects(available({action:'saveSchedule',providerIds:['provider'],weeklyAvailability:disabled},auth('provider')),/exclude accepted work/);
  await book({action:'requestReschedule',bookingId:'one',scheduledDate:at()+4*3600000},auth('customer'));
  await assert.rejects(book({action:'approveReschedule',bookingId:'one'},auth('provider')),/revised provider estimate/);
  const revised=await propose('one','reschedule',{scheduledDate:at()+4*3600000,pricingType:'fixed',proposedRate:675.25});
  assert.equal((await db.doc('bookings/one').get()).data().scheduledDate.toMillis(),at());
  await amend(revised,auth('customer'));
  let b=(await db.doc('bookings/one').get()).data();assert.equal(b.scheduledDate.toMillis(),at()+4*3600000);assert.equal(b.totalFee,675.25);assert.equal(b.termsRevision,2);
  await db.doc('bookings/one').update({status:'Awaiting Confirmation'});
  await book({action:'confirmCompletion',bookingId:'one',confirmDeliverables:true},auth('customer'));
  b=(await db.doc('bookings/one').get()).data();assert.equal(b.finalFee,675.25);
});

test('legacy direct amendments retain previous terms and replace obsolete daily reservation fields',async()=>{
  await db.doc('bookings/one').set({providerId:'provider',customerId:'customer',serviceId:'service',status:'Accepted',
    scheduledDate:Timestamp.fromMillis(at()),scheduledEndDate:Timestamp.fromMillis(at()+25*3600000),
    pricingType:'daily',numberOfDays:2,hoursPerDay:1,durationHours:2,proposedRate:100,totalFee:200,
    serviceLocation:'New Visayas, Panabo City',location:new GeoPoint(7.3,125.6),notes:'Legacy accepted job description.'});
  const approval=await propose();await amend(approval,auth('customer'));
  const b=(await db.doc('bookings/one').get()).data();
  assert.equal(b.numberOfDays,undefined);assert.equal(b.hoursPerDay,undefined);assert.equal(b.proposedRate,undefined);
  assert.equal((await db.doc('bookings/one/agreementVersions/legacy-direct-0').get()).exists,true);
  assert.equal((await db.collection('bookings/one/agreementVersions').get()).size,2);
  await assert.rejects(request('overlap','second',{scheduledDate:at()+2*3600000}),/already has an accepted booking/);
});
