'use strict';
const {GeoPoint,Timestamp,getFirestore}=require('firebase-admin/firestore');
const {before,after,beforeEach,test}=require('node:test');
const assert=require('node:assert/strict');
const admin=require('firebase-admin'),functions=require('firebase-functions/v1');
const {initializeTestEnvironment}=require('@firebase/rules-unit-testing');
const {credentials,certificate,offer}=require('./marketplace_fixtures');
let env,app,db,inquiry,booking,review;
const auth=uid=>({auth:{uid}});
before(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Demo emulator required');
  env=await initializeTestEnvironment({projectId:'demo-neighborhelp'});
  app=admin.initializeApp({projectId:'demo-neighborhelp'},'marketplace-tests');db=getFirestore(app);
  inquiry=require('../inquiry_commands')({db,functions});booking=require('../booking_commands')({db,admin,functions});review=require('../certificate_commands')({db,functions});
});
after(async()=>{await require('firebase-admin/app').deleteApp(app);await env?.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore();
  for(const [id,role] of [['c','Customer'],['c2','Customer'],['p','Provider'],['p2','Provider'],['a','Administrator'],['agency','Verification Agency']]) await db.doc(`users/${id}`).set({role,accountStatus:'Active',fullName:id});
  for(const id of ['p','p2']) {
    await db.doc(`serviceProviders/${id}`).set({userId:id,isVerified:true,location:new GeoPoint(7.3,125.6),serviceRadiusKm:10,acceptedBookings:0,...credentials()});
    await db.doc(`services/${id}`).set({providerId:id,category:'Cleaning',serviceTitle:'House Cleaning',isActive:true,approvalStatus:'Approved',estimatedPrice:999,priceType:'hourly'});
  }
});
async function open(provider='p',customer='c') {return (await inquiry({action:'open',serviceId:provider},auth(customer))).inquiryId;}
async function discuss(provider='p',customer='c') {
  const id=await open(provider,customer);
  await inquiry({action:'send',inquiryId:id,messageId:'customer-text',text:'Please clean these rooms. Can we agree scope and price?'},auth(customer));
  await inquiry({action:'send',inquiryId:id,messageId:'provider-text',text:'Yes, let us agree the materials, work and schedule.'},auth(provider));
  return id;
}
async function payload(extra={}) {return {bookingId:'offer',serviceId:'p',inquiryId:await discuss(),serviceLocation:'Panabo City complete address',location:{latitude:7.3,longitude:125.6},scheduledDate:Date.now()+86400000,...offer(),...extra};}
async function create(data) {
  const preview=await booking({action:'preview',...data},auth('c'));
  await booking({action:'create',...data,agreementHash:preview.agreement.hash},auth('c'));
  return (await db.doc(`bookings/${data.bookingId}`).get()).data();
}
async function accept(id='offer') {const b=(await db.doc(`bookings/${id}`).get()).data();return booking({action:'accept',bookingId:id,acceptAgreement:true,agreementHash:b.agreement.hash},auth('p'));}

test('inquiries require no booking and support separate comparison conversations',async()=>{
  const first=await open(),second=await open('p2');assert.notEqual(first,second);assert.equal(await open(),first);
  assert.equal((await db.collection('bookings').get()).size,0);
  await assert.rejects(inquiry({action:'send',inquiryId:first,messageId:'x',text:'Intrusion'},auth('c2')),/another/);
  await inquiry({action:'send',inquiryId:first,messageId:'x',text:'Requirements'},auth('c'));
  await inquiry({action:'send',inquiryId:first,messageId:'x',text:'Requirements'},auth('c'));
  const t=(await db.doc(`inquiries/${first}`).get()).data();assert.equal(t.customerMessageCount,1);assert.equal(t.providerUnreadCount,1);
  await inquiry({action:'read',inquiryId:first},auth('p'));assert.equal((await db.doc(`inquiries/${first}`).get()).data().providerUnreadCount,0);
  await assert.rejects(inquiry({action:'send',inquiryId:first,messageId:'bad-image',mediaUrl:'gs://test/inquiries/other/c/image.png'},auth('c')),/Upload/);
});
test('one-way contact cannot create an offer; a photo alone does not count as discussion',async()=>{
  const id=await open();const data={...await payload(),inquiryId:id};
  await db.doc(`inquiries/${id}`).update({providerMessageCount:0});
  await assert.rejects(booking({action:'preview',...data},auth('c')),/Both parties/);
});
test('fixed and daily fees use the customer proposal and preserve accepted text in a separate contract',async()=>{
  const data=await payload({pricingType:'daily',proposedRate:750.25,numberOfDays:3,hoursPerDay:6});
  const b=await create(data);assert.equal(b.totalFee,2250.75);assert.equal(b.durationHours,18);
  assert.equal(b.scheduledEndDate.toMillis()-b.scheduledDate.toMillis(),54*3600000);
  assert.match(b.agreement.text,/750.25 per day/);assert.match(b.agreement.text,/2250.75/);
  await accept();const c=(await db.doc('contracts/offer').get()).data();assert.equal(c.agreement.hash,b.agreement.hash);assert.equal(c.providerAcceptedHash,c.customerAcceptedHash);
  const fixed=await create({...data,bookingId:'fixed',pricingType:'fixed',proposedRate:1500});assert.equal(fixed.totalFee,1500);
});
test('changed previews, unsupported hourly pricing, negative amounts and fractional days fail closed',async()=>{
  const data=await payload(),preview=await booking({action:'preview',...data},auth('c'));
  await assert.rejects(booking({action:'create',...data,proposedRate:1,agreementHash:preview.agreement.hash},auth('c')),/changed/);
  for(const patch of [{pricingType:'hourly'},{proposedRate:0},{proposedRate:NaN},{numberOfDays:1.5},{hoursPerDay:9}]) await assert.rejects(booking({action:'preview',...data,...patch},auth('c')));
  assert.equal((await db.collection('bookings').get()).size,0);
});
test('providers must consent to the same fingerprint; administrators cannot accept for them',async()=>{
  await create(await payload());
  await assert.rejects(booking({action:'accept',bookingId:'offer',acceptAgreement:true,agreementHash:'wrong'},auth('p')),/Review/);
  await assert.rejects(booking({action:'adminStatus',bookingId:'offer',status:'Accepted'},auth('a')),/Only the provider/);
  await assert.rejects(booking({action:'start',bookingId:'offer'},auth('p')),/accepted/);
  await accept();await assert.rejects(accept(),/pending/);
});
test('requesting changes keeps the prior offer and requires a new acceptance',async()=>{
  const first=await create(await payload());
  await booking({action:'requestChanges',bookingId:'offer',reason:'Please include the cleaning materials in the scope.'},auth('p'));
  await assert.rejects(accept(),/pending/);
  const revised=await create(await payload({bookingId:'revised',proposedRate:250}));
  assert.equal((await db.doc('bookings/offer').get()).data().agreement.hash,first.agreement.hash);assert.notEqual(revised.agreement.hash,first.agreement.hash);
});
test('pending offers do not reserve time and multi-day accepted work prevents overlap',async()=>{
  const data=await payload({numberOfDays:3});await create(data);await create({...data,bookingId:'second'});
  await accept();await assert.rejects(accept('second'),/already has/);
});
test('accepted terms cannot be silently rescheduled and cancelled evidence is retained',async()=>{
  const b=await create(await payload());await accept();
  await assert.rejects(booking({action:'requestReschedule',bookingId:'offer',scheduledDate:Date.now()+3*86400000},auth('c')),/part of the agreement/);
  await booking({action:'cancel',bookingId:'offer',reason:'We agreed to prepare a revised scope and date.'},auth('c'));
  assert.equal((await db.doc('bookings/offer').get()).data().agreement.hash,b.agreement.hash);
});
test('closing a contract requires resolving outstanding work and preserves acceptance evidence',async()=>{
  const close=require('../contract_commands')({db,functions});
  await create(await payload());await accept();
  await assert.rejects(close({contractId:'offer'},auth('c')),/outstanding work/);
  await assert.rejects(close({contractId:'offer'},auth('c2')),/participants/);
  const before=(await db.doc('contracts/offer').get()).data();
  await booking({action:'cancel',bookingId:'offer',reason:'We agreed to cancel the scheduled work.'},auth('c'));
  await close({contractId:'offer'},auth('c'));
  const after=(await db.doc('contracts/offer').get()).data();assert.equal(after.status,'ended');assert.equal(after.agreement.hash,before.agreement.hash);
});
test('legacy hourly amounts remain unchanged and legacy pending requests cannot bypass new consent',async()=>{
  const legacy={customerId:'c',providerId:'p',serviceId:'p',status:'Pending',pricingType:'hourly',hourlyRate:123,totalFee:246,durationHours:2,scheduledDate:Timestamp.fromMillis(Date.now()+86400000)};
  await db.doc('bookings/legacy').set(legacy);await assert.rejects(booking({action:'accept',bookingId:'legacy'},auth('p')),/Legacy pending/);
  assert.equal((await db.doc('bookings/legacy').get()).data().totalFee,246);
});
test('only the System Administrator can review; opening TESDA alone never approves',async()=>{
  await db.doc('serviceProviders/p').update({certificationHistory:[{...certificate(),url:'gs://test/certificates/p/cert/proof.pdf',status:'Pending'}],approvedCertificationIds:[]});
  const data={providerId:'p',certificationEntryId:'cert',decision:'Approved',registryChecked:true,notes:'Holder, certificate number, qualification and validity matched in TESDA.'};
  for(const uid of ['p','c','agency']) await assert.rejects(review(data,auth(uid)),/Administrator/);
  await assert.rejects(review({...data,registryChecked:false},auth('a')),/Confirm/);
  await review({...data,decision:'Pending',registryChecked:false,notes:'No matching result yet; follow up with TESDA.'},auth('a'));
  assert.deepEqual((await db.doc('serviceProviders/p').get()).data().approvedCertificationIds,[]);
  await review(data,auth('a'));assert.deepEqual((await db.doc('serviceProviders/p').get()).data().approvedCertificationIds,['cert']);
  await review({...data,decision:'Rejected',notes:'Certificate details do not match the submitted holder.'},auth('a'));
  await assert.rejects(open(),/certificate/);
});
test('unsupported custom work, PRC-only work and unrelated or expired certificates cannot be offered',async()=>{
  for(const patch of [{category:'Custom Services',serviceTitle:'Anything'},{category:'Repair and Technical Services',serviceTitle:'Electrical Repair'}]) {
    await db.doc('services/p').update(patch);await assert.rejects(open(),/certificate/);
  }
  await db.doc('services/p').update({category:'Cleaning',serviceTitle:'House Cleaning'});
  await db.doc('serviceProviders/p').update(credentials('Carpentry NC II'));await assert.rejects(open(),/certificate/);
  await db.doc('serviceProviders/p').update({...credentials(),certificationHistory:[{...certificate(),expirationDate:'2020-01-01'}]});await assert.rejects(open(),/certificate/);
});
