'use strict';
const {before,after,beforeEach,test}=require('node:test'),assert=require('node:assert/strict');
const {GeoPoint,Timestamp,FieldValue,getFirestore}=require('firebase-admin/firestore');
const admin=require('firebase-admin'),functions=require('firebase-functions/v1');
const {initializeTestEnvironment}=require('@firebase/rules-unit-testing');
const {credentials,offer}=require('./marketplace_fixtures');
let env,app,db,booking,inquiry,amendment,payment,availability,report;
const auth=uid=>({auth:{uid,token:{email_verified:true}}}), stamp=ms=>Timestamp.fromMillis(ms);
const future=()=>{const day=new Date(Date.now()+2*86400000+8*3600000);return Date.UTC(day.getUTCFullYear(),day.getUTCMonth(),day.getUTCDate(),1);};
before(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Demo emulator required.');
  env=await initializeTestEnvironment({projectId:'demo-neighborhelp'});
  app=admin.initializeApp({projectId:'demo-neighborhelp'},'improvement-tests');db=getFirestore(app);
  booking=require('../booking_commands')({db,admin,functions});
  inquiry=require('../inquiry_commands')({db,functions});amendment=require('../agreement_commands')({db,functions});payment=require('../payment_commands')({db,functions});
  availability=require('../availability_command')({db,functions});report=require('../report_commands')({db,functions});
});
after(async()=>{await require('firebase-admin/app').deleteApp(app);await env?.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore();
  for(const [uid,role] of [['c','Customer'],['p','Provider'],['stranger','Customer'],['a','Administrator']])await db.doc(`users/${uid}`).set({role,accountStatus:'Active',fullName:uid});
  await db.doc('serviceProviders/p').set({isVerified:true,...credentials(),location:new GeoPoint(7.3,125.6),serviceRadiusKm:15,acceptedBookings:0,completedBookings:0});
  await db.doc('publicProviders/p').set({isVerified:true});
  await db.doc('services/s').set({providerId:'p',category:'Cleaning',serviceTitle:'House Cleaning',isActive:true,approvalStatus:'Approved'});
});
async function conversation(){const {inquiryId}=await inquiry({action:'open',serviceId:'s'},auth('c'));
  await inquiry({action:'send',inquiryId,messageId:'c',text:'Please clean the agreed rooms.'},auth('c'));
  await inquiry({action:'send',inquiryId,messageId:'p',text:'I agree to discuss the work.'},auth('p'));return inquiryId;
}
async function accepted(extra={}) {
  const data={...offer(),bookingId:'b',serviceId:'s',serviceLocation:'Test address, Panabo City',location:{latitude:7.3,longitude:125.6},inquiryId:await conversation(),scheduledDate:future(),...extra};
  const preview=await booking({action:'preview',...data},auth('c'));
  await booking({action:'create',...data,agreementHash:preview.agreement.hash},auth('c'));
  await booking({action:'accept',bookingId:'b',acceptAgreement:true,agreementHash:preview.agreement.hash},auth('p'));
  return (await db.doc('bookings/b').get()).data();
}
async function proposal(extra={},uid='c',revisionId='r') {
  const b=(await db.doc('bookings/b').get()).data(),data={...offer(),bookingId:'b',revisionId,expectedHash:b.agreement.hash,reason:'Add the agreed extra room and cleaning supplies.',scheduledDate:b.scheduledDate.toMillis(),proposedRate:150,...extra};
  const preview=await amendment({action:'preview',...data},auth(uid));
  await amendment({action:'propose',...data,agreementHash:preview.agreement.hash},auth(uid));
  return preview;
}
test('changed weekly hours prevent accepting an earlier valid offer',async()=>{
  const data={...offer(),bookingId:'b',serviceId:'s',serviceLocation:'Test address, Panabo City',location:{latitude:7.3,longitude:125.6},inquiryId:await conversation(),scheduledDate:future()};
  const preview=await booking({action:'preview',...data},auth('c'));await booking({action:'create',...data,agreementHash:preview.agreement.hash},auth('c'));
  await db.doc('serviceProviders/p').update({weeklyAvailability:Object.fromEntries(Object.keys(credentials().weeklyAvailability).map(d=>[d,{enabled:false}]))});
  await assert.rejects(booking({action:'accept',bookingId:'b',acceptAgreement:true,agreementHash:preview.agreement.hash},auth('p')),/working hours/);
  await assert.rejects(booking({action:'preview',...data,bookingId:'other'},auth('c')),/working hours/);
});
test('fixed-price completion can be early but only the customer confirms and earns completion credit once',async()=>{
  await accepted();await db.doc('bookings/b').update({scheduledDate:stamp(Date.now()-60000)});
  await booking({action:'start',bookingId:'b'},auth('p'));
  await booking({action:'complete',bookingId:'b'},auth('p'));
  let b=(await db.doc('bookings/b').get()).data();assert.equal(b.status,'Awaiting Confirmation');assert.equal(b.completedAt,undefined);
  assert.equal((await db.doc('serviceProviders/p').get()).data().completedBookings,0);
  await assert.rejects(booking({action:'confirmCompletion',bookingId:'b',confirmDeliverables:true},auth('p')),/customer/);
  await assert.rejects(require('../contract_commands')({db,functions})({contractId:'b'},auth('c')),/outstanding/);
  await booking({action:'requestCorrections',bookingId:'b',reason:'Please clean the missed kitchen surfaces.'},auth('c'));
  b=(await db.doc('bookings/b').get()).data();assert.equal(b.status,'In Progress');assert.equal(b.correctionRounds,1);
  await booking({action:'complete',bookingId:'b'},auth('p'));
  await booking({action:'confirmCompletion',bookingId:'b',confirmDeliverables:true},auth('c'));
  await assert.rejects(booking({action:'confirmCompletion',bookingId:'b',confirmDeliverables:true},auth('c')),/reported completion/);
  assert.equal((await db.doc('serviceProviders/p').get()).data().completedBookings,1);
  assert.equal((await db.collection('bookings/b/workEvents').get()).size,4);
});
test('daily work cannot report finished before its period, and amendments must be resolved first',async()=>{
  await accepted({pricingType:'daily'});await db.doc('bookings/b').update({status:'In Progress',startedAt:stamp(Date.now()-60000)});
  await assert.rejects(booking({action:'complete',bookingId:'b'},auth('p')),/work period/);
  await proposal();await assert.rejects(booking({action:'complete',bookingId:'b'},auth('p')),/amendment/);
});
test('both parties accept an amendment; original records and hashes remain immutable',async()=>{
  const original=await accepted(),preview=await proposal();
  assert.equal((await db.doc('bookings/b').get()).data().totalFee,100);
  const data={action:'accept',bookingId:'b',revisionId:'r',acceptAgreement:true,agreementHash:preview.agreement.hash};
  await assert.rejects(amendment(data,auth('c')),/other participant/);
  await assert.rejects(amendment({...data,agreementHash:'tampered'},auth('p')),/exact amendment/);
  await amendment(data,auth('p'));
  const b=(await db.doc('bookings/b').get()).data();assert.equal(b.totalFee,150);assert.equal(b.agreementRevision,1);assert.equal(b.customerAcceptedHash,b.providerAcceptedHash);
  assert.equal((await db.doc('bookings/b/agreementVersions/0').get()).data().agreement.hash,original.agreement.hash);
  assert.equal((await db.doc('contracts/b').get()).data().agreement.hash,original.agreement.hash);
  assert.equal(b.originalAgreement.hash,original.agreement.hash);
  await assert.rejects(amendment(data,auth('p')),/no longer/);
});
test('amendment acceptance rechecks concurrent jobs, and decline keeps old terms',async()=>{
  const old=await accepted(),preview=await proposal({numberOfDays:2});
  await db.doc('bookings/conflict').set({providerId:'p',status:'Accepted',scheduledDate:stamp(old.scheduledDate.toMillis()+86400000),durationHours:1});
  await assert.rejects(amendment({action:'accept',bookingId:'b',revisionId:'r',acceptAgreement:true,agreementHash:preview.agreement.hash},auth('p')),/conflicts/);
  await amendment({action:'decline',bookingId:'b',revisionId:'r'},auth('p'));
  assert.equal((await db.doc('bookings/b').get()).data().agreement.hash,old.agreement.hash);
});
test('ongoing work cannot be moved or shortened and cancellation supersedes pending amendments',async()=>{
  await accepted({numberOfDays:2});await db.doc('bookings/b').update({status:'In Progress',startedAt:stamp(Date.now())});
  await assert.rejects(proposal({numberOfDays:1}),/Ongoing/);
  await proposal({numberOfDays:3});
  await booking({action:'cancel',bookingId:'b',reason:'Both parties agreed to cancel unfinished work.'},auth('c'));
  assert.equal((await db.doc('bookings/b/amendments/r').get()).data().status,'Superseded by cancellation');
});
test('payments are partial, independently acknowledged, exactly once and separate from job status',async()=>{
  await accepted();
  await payment({action:'report',bookingId:'b',paymentId:'p1',amount:40,method:'Cash'},auth('c'));
  await payment({action:'report',bookingId:'b',paymentId:'p1',amount:40,method:'Cash'},auth('c'));
  await assert.rejects(payment({action:'report',bookingId:'b',paymentId:'over',amount:61,method:'Cash'},auth('c')),/exceeds/);
  await assert.rejects(payment({action:'confirm',bookingId:'b',paymentId:'p1',confirmReceived:true},auth('c')),/provider/);
  const results=await Promise.allSettled([1,2].map(()=>payment({action:'confirm',bookingId:'b',paymentId:'p1',confirmReceived:true},auth('p'))));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  let b=(await db.doc('bookings/b').get()).data();assert.equal(b.confirmedPaymentCents,4000);assert.equal(b.pendingPaymentCents,0);assert.equal(b.status,'Accepted');
  await payment({action:'report',bookingId:'b',paymentId:'p2',amount:30,method:'GCash'},auth('c'));
  await payment({action:'dispute',bookingId:'b',paymentId:'p2',reason:'The transfer did not reach my account.'},auth('p'));
  b=(await db.doc('bookings/b').get()).data();assert.equal(b.pendingPaymentCents,0);assert.equal(b.confirmedPaymentCents,4000);
  await assert.rejects(proposal({proposedRate:39}),/payment records/);
});
test('concurrent payment reports cannot reserve more than the agreed total',async()=>{
  await accepted();const results=await Promise.allSettled(['one','two'].map(paymentId=>payment({action:'report',bookingId:'b',paymentId,amount:60,method:'Cash'},auth('c'))));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal((await db.doc('bookings/b').get()).data().pendingPaymentCents,6000);
});
test('blocking stops both directions, uploads and new contracts; the other user cannot remove a block',async()=>{
  const id=await conversation();await inquiry({action:'block',inquiryId:id},auth('c'));
  await inquiry({action:'unblock',inquiryId:id},auth('p'));
  for(const uid of ['c','p'])await assert.rejects(inquiry({action:'send',inquiryId:id,messageId:'blocked',text:'Cannot bypass block'},auth(uid)),/blocked/);
  await assert.rejects(inquiry({action:'authorizeUpload',inquiryId:id,permitId:'image',extension:'png'},auth('c')),/blocked/);
  await assert.rejects(accepted(),/blocked/);
  await inquiry({action:'read',inquiryId:id},auth('c'));
  await inquiry({action:'report',inquiryId:id,reportId:'r',reason:'Please investigate inappropriate messages.'},auth('c'));
  const r=(await db.doc('bookingUserReports/r').get()).data();assert.equal(r.reportedUserId,'p');assert.equal(r.evidence.length,2);
});
test('message retries are free but excessive sends and repeated photo uploads are limited',async()=>{
  const id=await conversation();
  for(let n=0;n<2;n++)await inquiry({action:'send',inquiryId:id,messageId:`m${n}`,text:'A permitted message.'},auth('c'));
  for(const bucket of [Math.floor(Date.now()/60000),Math.floor(Date.now()/60000)+1])await db.doc(`rateLimits/c_messages_60000_${bucket}`).set({count:30});
  await inquiry({action:'send',inquiryId:id,messageId:'m0',text:'A permitted message.'},auth('c'));
  assert.equal((await db.doc(`inquiries/${id}`).get()).data().customerMessageCount,3);
  await assert.rejects(inquiry({action:'send',inquiryId:id,messageId:'overflow',text:'Too many sends.'},auth('c')),/Too many messages/);
  await inquiry({action:'authorizeUpload',inquiryId:id,permitId:'photo',extension:'png'},auth('p'));
  for(const bucket of [Math.floor(Date.now()/3600000),Math.floor(Date.now()/3600000)+1])await db.doc(`rateLimits/p_photo_uploads_3600000_${bucket}`).set({count:20});
  await inquiry({action:'authorizeUpload',inquiryId:id,permitId:'photo',extension:'png'},auth('p'));
  await assert.rejects(inquiry({action:'authorizeUpload',inquiryId:id,permitId:'overflow',extension:'png'},auth('p')),/photo_uploads/);
});
test('only an authorized unexpired photo permit can be attached once',async()=>{
  const id=await conversation();
  await assert.rejects(inquiry({action:'send',inquiryId:id,messageId:'x',mediaUrl:`gs://test/inquiries/${id}/c/unapproved.png`},auth('c')),/permission/);
  await inquiry({action:'authorizeUpload',inquiryId:id,permitId:'photo',extension:'png'},auth('c'));
  await inquiry({action:'send',inquiryId:id,messageId:'photo-message',mediaUrl:`gs://test/inquiries/${id}/c/photo.png`},auth('c'));
  await assert.rejects(inquiry({action:'send',inquiryId:id,messageId:'again',mediaUrl:`gs://test/inquiries/${id}/c/photo.png`},auth('c')),/permission/);
});
test('availability exposes no booking details and rejects travel-buffer conflicts',async()=>{
  const b=await accepted();
  const response=await availability({scheduledDate:b.scheduledDate.toMillis()+3600000+14*60000,numberOfDays:1,hoursPerDay:1,providerIds:['p']},auth('c'));
  assert.equal(response.providers.p.available,false);assert.deepEqual(Object.keys(response.providers.p).sort(),['available','reason']);
  const free=await availability({scheduledDate:b.scheduledDate.toMillis()+3600000+15*60000,numberOfDays:1,hoursPerDay:1,providerIds:['p']},auth('c'));assert.equal(free.providers.p.available,true);
});
test('booking reports derive participants and only administrators can resolve with retained notes',async()=>{
  await accepted();await assert.rejects(report({action:'reportBooking',bookingId:'b',reason:'Please investigate.'},auth('stranger')),/participants/);
  const r=await report({action:'reportBooking',bookingId:'b',reportedUserId:'stranger',reason:'Please investigate.'},auth('c'));
  assert.equal((await db.doc(`bookingUserReports/${r.reportId}`).get()).data().reportedUserId,'p');
  await assert.rejects(report({action:'resolve',reportId:r.reportId,status:'dismissed',adminNotes:'Reviewed the report details.'},auth('c')),/Administrator/);
  await report({action:'resolve',reportId:r.reportId,status:'resolved',adminNotes:'Reviewed and recorded the administrative decision.'},auth('a'));
  assert.equal((await db.doc(`bookingUserReports/${r.reportId}`).get()).data().status,'resolved');
});
