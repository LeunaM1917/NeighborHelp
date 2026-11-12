'use strict';
const {GeoPoint,Timestamp,getFirestore}=require('firebase-admin/firestore');
const {before,after,beforeEach,test}=require('node:test');
const assert=require('node:assert/strict');
const admin=require('firebase-admin'),functions=require('firebase-functions/v1');
const {initializeTestEnvironment}=require('@firebase/rules-unit-testing');
const {assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc}=require('firebase/firestore');
const {credentials,certificate,offer,futureWorkStart}=require('./marketplace_fixtures');
let env,app,db,inquiry,booking,review;
const auth=uid=>({auth:{uid,token:{email_verified:true}}});
before(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Demo emulator required');
  env=await initializeTestEnvironment({projectId:'demo-neighborhelp'});
  app=admin.initializeApp({projectId:'demo-neighborhelp'},'marketplace-tests');db=getFirestore(app);
  inquiry=require('../inquiry_commands')({db,functions});booking=require('../booking_commands')({db,admin,functions});review=require('../certificate_commands')({db,functions});
});
after(async()=>{await require('firebase-admin/app').deleteApp(app);await env?.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore();
  for(const [id,role] of [['c','Customer'],['c2','Customer'],['p','Provider'],['p2','Provider'],['a','Administrator'],['agency','Verification Agency']]) await db.doc(`users/${id}`).set({role,accountStatus:'Active',fullName:`Test ${id}`,contactNumber:'09123456789',address:'New Visayas, Panabo City',isVerified:role==='Customer'});
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
async function payload(extra={}) {return {bookingId:'offer',serviceId:'p',inquiryId:await discuss(),serviceLocation:'Panabo City complete address',location:{latitude:7.3,longitude:125.6},scheduledDate:futureWorkStart(),...offer(),...extra};}
async function create(data) {
  const preview=await booking({action:'preview',...data},auth('c'));
  await booking({action:'create',...data,agreementHash:preview.agreement.hash},auth('c'));
  return (await db.doc(`bookings/${data.bookingId}`).get()).data();
}
async function accept(id='offer') {const b=(await db.doc(`bookings/${id}`).get()).data();return booking({action:'accept',bookingId:id,acceptAgreement:true,agreementHash:b.agreement.hash},auth('p'));}

const proposalData=(extra={})=>({action:'submit',serviceTitle:'Deep Upholstery Cleaning',category:'Cleaning',
  description:'Clean fabric furniture using domestic cleaning methods. No regulated or specialist work.',certificationEntryId:'cert',...extra});
const proposals=()=>require('../service_proposal_commands')({db,functions});
const proposalReview=(id,action='approve',extra={})=>({action,proposalId:id,notes:'Scope checked against the authenticated TESDA qualification.',scopeConfirmed:true,...extra});
test('service proposals require verified providers and current approved certificates; duplicate retries are safe',async()=>{
  const command=proposals();
  await assert.rejects(command(proposalData(),auth('c')),{code:'permission-denied'});
  await assert.rejects(command(proposalData({serviceTitle:'House Cleaning',category:'Construction'}),auth('p')),{code:'failed-precondition'});
  await assert.rejects(command(proposalData({certificationEntryId:'someone-elses-cert'}),auth('p')),{code:'failed-precondition'});
  const result=await command(proposalData(),auth('p'));
  assert.equal((await command(proposalData(),auth('p'))).duplicate,true);
  assert.equal((await db.collection('serviceProposals').get()).size,1);
  assert.equal((await db.collection('notifications').get()).size,1);
  const own=env.authenticatedContext('p').firestore(),other=env.authenticatedContext('p2').firestore();
  await assertSucceeds(getDoc(doc(own,'serviceProposals',result.proposalId)));
  await assertFails(getDoc(doc(other,'serviceProposals',result.proposalId)));
  await assertFails(updateDoc(doc(own,'serviceProposals',result.proposalId),{status:'Approved'}));
  await assertFails(updateDoc(doc(own,'serviceProviders','p'),{approvedServiceProposals:{forged:{status:'Approved'}}}));
  await db.doc('users/new-provider').set({role:'Provider',accountStatus:'Active'});
  const fresh=env.authenticatedContext('new-provider').firestore(),newProfile={userId:'new-provider',isVerified:false,verificationStatus:'Pending'};
  await assertFails(setDoc(doc(fresh,'serviceProviders','new-provider'),{...newProfile,approvedServiceProposals:{forged:{status:'Approved'}}}));
  await assertSucceeds(setDoc(doc(fresh,'serviceProviders','new-provider'),newProfile));
  await command(proposalData({serviceTitle:'Domestic Surface Sanitizing'}),auth('p'));
  await command(proposalData({serviceTitle:'Domestic Fabric Cleaning'}),auth('p'));
  await assert.rejects(command(proposalData({serviceTitle:'Fourth Pending Proposal'}),auth('p')),{code:'resource-exhausted'});
});
test('proposal approval creates a private bound draft; providers cannot publish, rename or clone its approval',async()=>{
  const command=proposals(),{proposalId}=await command(proposalData(),auth('p'));
  await assert.rejects(command(proposalReview(proposalId),auth('p')),{code:'permission-denied'});
  await assert.rejects(command(proposalReview(proposalId,'approve',{scopeConfirmed:false}),auth('a')),{code:'failed-precondition'});
  await db.doc('securityPolicy/admin').set({requireMfa:true});
  await assert.rejects(command(proposalReview(proposalId),auth('a')),{code:'permission-denied'});
  await db.doc('securityPolicy/admin').delete();
  await command(proposalReview(proposalId),auth('a'));
  const id='proposed_'+proposalId,service=(await db.doc('services/'+id).get()).data();
  assert.equal(service.approvalStatus,'Draft');assert.equal(service.isActive,false);
  assert.equal(service.estimatedPrice,0);assert.equal(service.requiredQualification,'Domestic Work NC II');
  await db.doc('serviceProviders/p').update({locationPolicyVersion:1});
  const client=env.authenticatedContext('p').firestore();
  await assertSucceeds(updateDoc(doc(client,'services',id),{estimatedPrice:700,approvalStatus:'Pending',isActive:false}));
  await assertFails(updateDoc(doc(client,'services',id),{approvalStatus:'Approved',isActive:true}));
  await assertFails(updateDoc(doc(client,'services',id),{serviceTitle:'House Cleaning',category:'Construction'}));
  await assertFails(setDoc(doc(client,'services','cloned-approval'),{...service,createdAt:service.createdAt.toDate(),updatedAt:service.updatedAt.toDate()}));
  await assert.rejects(command(proposalReview(proposalId),auth('a')),{code:'failed-precondition'});
});
test('reviewed custom services support inquiry, contract and certificate revocation end to end',async()=>{
  const command=proposals(),{proposalId}=await command(proposalData(),auth('p'));
  await command(proposalReview(proposalId),auth('a'));
  const serviceId='proposed_'+proposalId;
  await assert.rejects(inquiry({action:'open',serviceId},auth('c')),{code:'failed-precondition'});
  await db.doc('services/'+serviceId).update({approvalStatus:'Approved',isActive:true,estimatedPrice:700});
  await db.doc('serviceProviders/p').update({locationPolicyVersion:1});
  const published=(await db.doc('services/'+serviceId).get()).data();
  const ops=require('../platform_operations')({db,admin,functions,region:'us-central1'});
  await ops.auditServices.run({before:{exists:true,data:()=>({...published,approvalStatus:'Pending',isActive:false})},
    after:{exists:true,data:()=>published}},{params:{id:serviceId},eventId:'custom-service-published'});
  const projection=(await db.doc('publicProviders/p').get()).data();
  assert.ok(projection.eligibleServiceIds.includes(serviceId));assert.ok(projection.eligibleServiceExpiries[serviceId]>Date.now());
  const inquiryId=(await inquiry({action:'open',serviceId},auth('c'))).inquiryId;
  for(const uid of ['c','p'])await inquiry({action:'send',inquiryId,messageId:uid,text:'Discuss the custom cleaning scope, price and schedule.'},auth(uid));
  const data={bookingId:'custom-offer',serviceId,inquiryId,serviceLocation:'New Visayas, Panabo City complete address',
    location:{latitude:7.3,longitude:125.6},scheduledDate:futureWorkStart(),...offer()};
  await create(data);await accept('custom-offer');
  assert.equal((await db.doc('bookings/custom-offer').get()).data().status,'Accepted');
  await db.doc('serviceProviders/p').update({approvedCertificationIds:[]});
  await assert.rejects(inquiry({action:'open',serviceId},auth('c')),{code:'failed-precondition'});
  await assert.rejects(booking({action:'start',bookingId:'custom-offer'},auth('p')),{code:'failed-precondition'});
  await db.doc('serviceProviders/p').update({approvedCertificationIds:['cert']});
  await db.doc('services/'+serviceId).delete();
  await assert.rejects(command({action:'restoreDraft',proposalId},auth('p2')),{code:'permission-denied'});
  assert.equal((await command({action:'restoreDraft',proposalId},auth('p'))).status,'Approved');
  assert.equal((await db.doc('services/'+serviceId).get()).data().isActive,false);
});
test('rejected proposals retain feedback and may be revised; an expired credential cannot receive approval',async()=>{
  const command=proposals(),{proposalId}=await command(proposalData(),auth('p'));
  await command(proposalReview(proposalId,'reject',{notes:'Clarify the work boundaries and cleaning methods.'}),auth('a'));
  assert.match((await db.doc('serviceProposals/'+proposalId).get()).data().reviewNotes,/boundaries/);
  await command(proposalData({description:'Revised: domestic upholstery surface cleaning only, excluding specialist restoration.'}),auth('p'));
  await db.doc('serviceProviders/p').update({certificationHistory:[{...certificate(),expirationDate:'2020-01-01'}]});
  await assert.rejects(command(proposalReview(proposalId),auth('a')),{code:'failed-precondition'});
  await command(proposalReview(proposalId,'reject'),auth('a'));
  assert.equal((await db.doc('serviceProposals/'+proposalId).get()).data().status,'Rejected');
});
test('an additional TESDA NC qualification can be registry-reviewed but unlocks no service without scope approval',async()=>{
  const c={...certificate('Shielded Metal Arc Welding NC II'),status:'Pending',url:'gs://test/certificates/p/cert/file.pdf'};
  await db.doc('serviceProviders/p').update({certificationHistory:[c],approvedCertificationIds:[]});
  await review({providerId:'p',certificationEntryId:'cert',decision:'Approved',registryChecked:true,notes:'Holder, qualification, number and validity checked in the TESDA registry.'},auth('a'));
  const {hasMatchingCertificate}=require('../domain');
  assert.equal(hasMatchingCertificate((await db.doc('serviceProviders/p').get()).data(),'Cleaning','House Cleaning'),false);
  const command=proposals(),{proposalId}=await command(proposalData({serviceTitle:'Household Metal Furniture Welding',category:'Construction'}),auth('p'));
  assert.equal(hasMatchingCertificate((await db.doc('serviceProviders/p').get()).data(),'Construction','Household Metal Furniture Welding'),false);
  await command(proposalReview(proposalId),auth('a'));
  assert.equal(hasMatchingCertificate((await db.doc('serviceProviders/p').get()).data(),'Construction','Household Metal Furniture Welding'),true);
});

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
test('legacy hourly requests can be accepted without a contract and retain their price',async()=>{
  const legacy={customerId:'c',providerId:'p',serviceId:'p',status:'Pending',pricingType:'hourly',hourlyRate:123,totalFee:246,durationHours:2,location:new GeoPoint(7.3,125.6),scheduledDate:Timestamp.fromMillis(futureWorkStart())};
  await db.doc('bookings/legacy').set(legacy);await booking({action:'accept',bookingId:'legacy'},auth('p'));
  assert.equal((await db.doc('bookings/legacy').get()).data().totalFee,246);
  assert.equal((await db.doc('bookings/legacy').get()).data().status,'Accepted');
  assert.equal((await db.collection('contracts').get()).size,0);
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
