'use strict';
const {before,after,beforeEach,test}=require('node:test'),assert=require('node:assert/strict');
const {getFirestore,Timestamp,GeoPoint}=require('firebase-admin/firestore');
const admin=require('firebase-admin'),functions=require('firebase-functions/v1');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc,getDocs,collection,query,where,GeoPoint:ClientGeoPoint,Timestamp:ClientTimestamp}=require('firebase/firestore');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
const {credentials,offer,futureWorkStart}=require('./marketplace_fixtures');
const catalog=require('../panabo_barangays.json').barangays,area=require('../provider_area');
let env,app,db,inquiry,timeOff,booking,ops;
const auth=uid=>({auth:{uid,token:{email_verified:true}}}),stamp=n=>Timestamp.fromMillis(n);
before(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Demo emulator required');
  env=await initializeTestEnvironment({projectId:'demo-neighborhelp'});app=admin.initializeApp({projectId:'demo-neighborhelp'},'discovery-safety');db=getFirestore(app);
  inquiry=require('../inquiry_commands')({db,functions});timeOff=require('../time_off_commands')({db,functions});booking=require('../booking_commands')({db,admin,functions});
  ops=require('../platform_operations')({db,admin,functions,region:'us-central1'});
});
after(async()=>{await require('firebase-admin/app').deleteApp(app);await env.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore();
  for(const [id,role] of [['c','Customer'],['p','Provider'],['s','Customer'],['a','Administrator']])await db.doc(`users/${id}`).set({role,accountStatus:'Active',fullName:`Test ${id}`,contactNumber:'09123456789',address:'New Visayas, Panabo City',isVerified:role==='Customer'});
  await db.doc('serviceProviders/p').set({userId:'p',isVerified:true,...credentials(),location:new GeoPoint(7.3,125.6),serviceArea:'Private street address',timeOff:[]});
  await db.doc('services/s').set({providerId:'p',category:'Cleaning',serviceTitle:'House Cleaning',isActive:true,approvalStatus:'Approved'});
});
async function legacy(status='Completed') {
  await db.doc('bookings/b').set({customerId:'c',providerId:'p',serviceId:'s',status,location:new GeoPoint(7.3,125.6),serviceLocation:'Historical private job address',scheduledDate:stamp(Date.now()+86400000),createdAt:stamp(10000),updatedAt:stamp(10000),agreement:{text:'Historical terms'}});
}
async function createOffer() {
  const id=(await inquiry({action:'open',serviceId:'s'},auth('c'))).inquiryId;
  for(const uid of ['c','p'])await inquiry({action:'send',inquiryId:id,messageId:uid,text:'We agree to discuss the job details.'},auth(uid));
  const payload={bookingId:'new',serviceId:'s',inquiryId:id,serviceLocation:'Panabo City complete job address',location:{latitude:7.3,longitude:125.6},scheduledDate:futureWorkStart(),...offer()};
  const preview=await booking({action:'preview',...payload},auth('c'));
  await booking({action:'create',...payload,agreementHash:preview.agreement.hash},auth('c'));
  return (await db.doc('bookings/new').get()).data();
}
test('public areas are catalog centers, never the supplied GPS or street address; time-off reasons stay private',async()=>{
  const start=Date.now()+86400000,end=start+3600000;
  await db.doc('serviceProviders/p').update({timeOff:[{start:stamp(start),end:stamp(end),label:'Private medical appointment',id:'private'}]});
  const p=(await ops.getPublicProviders.run({},auth('c'))).records[0],base=area.base(credentials());
  assert.deepEqual(p.location,{latitude:base.latitude,longitude:base.longitude});assert.equal(p.locationPolicyVersion,1);assert.equal(p.marketplacePolicyVersion,3);
  assert.notEqual(p.serviceArea,'Private street address');assert.deepEqual(p.timeOff,[{startMs:start,endMs:end}]);
  await db.doc('serviceProviders/p').update({baseBarangayId:null});assert.equal((await ops.getPublicProviders.run({},auth('c'))).records.length,0);
});
test('provider area command accepts catalog selections only and clears the old user home pin',async()=>{
  const command=area.command({db,functions});await db.doc('users/p').update({location:new GeoPoint(7.3,125.6),address:'Home street'});
  await assert.rejects(command({baseBarangayId:'fake',serviceBarangayIds:['fake']},auth('p')),/Choose/);
  await assert.rejects(command({baseBarangayId:catalog[0].id,serviceBarangayIds:[catalog[0].id]},auth('c')),/provider/);
  await command({baseBarangayId:catalog[0].id,serviceBarangayIds:[catalog[1].id]},auth('p'));
  assert.equal((await db.doc('users/p').get()).data().location,undefined);assert.deepEqual((await db.doc('serviceProviders/p').get()).data().serviceBarangayIds,[catalog[1].id]);
  assert.equal((await db.doc('users/p').get()).data().address,'Home street');
});

test('complete customer and provider addresses stay private and survive later barangay selections',async()=>{
  const address='House 12-A, Purok 3, New Visayas, Panabo City, Davao del Norte';
  const customer=env.authenticatedContext('c').firestore(),provider=env.authenticatedContext('p').firestore();
  await assertSucceeds(updateDoc(doc(customer,'users/c'),{address}));
  await assertSucceeds(updateDoc(doc(provider,'users/p'),{address}));
  assert.equal((await getDoc(doc(customer,'users/c'))).data().address,address);
  await area.command({db,functions})({baseBarangayId:catalog[0].id,serviceBarangayIds:[catalog[1].id]},auth('p'));
  assert.equal((await getDoc(doc(provider,'users/p'))).data().address,address);
  await assertFails(getDoc(doc(customer,'users/p')));
  await assertFails(getDoc(doc(provider,'users/c')));
  assert.equal(area.publicArea((await db.doc('serviceProviders/p').get()).data()).serviceArea.includes('House 12-A'),false);
});
test('old public records and direct owner location/time-off/legacy-message writes are denied',async()=>{
  const c=env.authenticatedContext('c').firestore(),p=env.authenticatedContext('p').firestore();
  await db.doc('publicProviders/p').set({location:new GeoPoint(7.3,125.6)});
  await assertFails(getDoc(doc(c,'publicProviders/p')));await assertSucceeds(getDocs(query(collection(c,'publicProviders'),where('locationPolicyVersion','==',1))));
  for(const patch of [{location:new ClientGeoPoint(7.31,125.61)},{baseBarangayId:catalog[0].id},{timeOff:[]}]) {
    // Changing an empty time-off array to the same value is not a write to a protected field.
    if(patch.timeOff)patch.timeOff=[{start:ClientTimestamp.fromMillis(Date.now()),end:ClientTimestamp.fromMillis(Date.now()+1000)}];
    await assertFails(updateDoc(doc(p,'serviceProviders/p'),patch));
  }
  await assertSucceeds(updateDoc(doc(p,'users/p'),{address:'House 12, Private home street, Panabo City'}));
  await assertFails(getDoc(doc(c,'users/p')));
  await assertFails(updateDoc(doc(p,'users/p'),{location:new ClientGeoPoint(7.3,125.6)}));
  await legacy();await assertFails(setDoc(doc(c,'messages/new'),{bookingId:'b',senderId:'c',receiverId:'p',messageText:'Bypass',isRead:false,messageType:'Text'}));
});
test('location migration scrubs current provider pins, hides unselected providers and preserves historical terms',async()=>{
  await legacy();await db.doc('serviceProviders/p').update({baseBarangayId:null});await db.doc('users/p').update({address:'Home address',location:new GeoPoint(7.3,125.6)});
  await db.doc('publicProviders/p').set({location:new GeoPoint(7.3,125.6)});
  const migrate=require('../provider_location_migration');assert.equal((await migrate(db)).scrubbed,0);
  await migrate(db,{apply:true});await migrate(db,{apply:true});
  assert.equal((await db.doc('publicProviders/p').get()).exists,false);assert.equal((await db.doc('serviceProviders/p').get()).data().location,undefined);assert.equal((await db.doc('users/p').get()).data().address,'Home address');
  const b=(await db.doc('bookings/b').get()).data();assert.equal(b.serviceLocation,'Historical private job address');assert.equal(b.agreement.text,'Historical terms');
});
test('legacy chat imports valid history exactly once, preserves blocks and joins the existing inquiry',async()=>{
  await legacy();const id=(await inquiry({action:'open',serviceId:'s'},auth('c'))).inquiryId;
  await inquiry({action:'block',inquiryId:id},auth('p'));
  await db.doc('messages/one').set({bookingId:'b',senderId:'c',receiverId:'p',messageText:'Original message',sentAt:stamp(12345),isRead:false});
  await db.doc('messages/two').set({bookingId:'b',senderId:'s',receiverId:'p',messageText:'Forged participant',sentAt:stamp(12346)});
  await assert.rejects(inquiry({action:'bookingThread',bookingId:'b'},auth('s')),/another/);
  for(let n=0;n<2;n++)assert.equal((await inquiry({action:'bookingThread',bookingId:'b'},auth('c'))).inquiryId,id);
  const messages=await db.collection(`inquiries/${id}/messages`).get();assert.equal(messages.size,1);assert.equal(messages.docs[0].data().sentAt.toMillis(),12345);
  const t=(await db.doc(`inquiries/${id}`).get()).data();assert.equal(t.providerUnreadCount,1);assert.equal(t.customerMessageCount,1);assert.deepEqual(t.blockedBy,['p']);
  await assert.rejects(inquiry({action:'send',inquiryId:id,messageId:'new',text:'Bypass blocked booking'},auth('c')),/blocked/);
  await assert.rejects(inquiry({action:'authorizeUpload',inquiryId:id,permitId:'photo',extension:'png'},auth('c')),/blocked/);
  await inquiry({action:'read',inquiryId:id},auth('p'));await inquiry({action:'bookingThread',bookingId:'b'},auth('p'));assert.equal((await db.doc(`inquiries/${id}`).get()).data().providerUnreadCount,0);
});
test('history imports continue after 100 messages and inbox sync includes historical-only conversations',async()=>{
  await legacy();const batch=db.batch();for(let i=0;i<105;i++)batch.set(db.doc(`messages/m${String(i).padStart(3,'0')}`),{bookingId:'b',senderId:'c',receiverId:'p',messageText:'Historical discussion',sentAt:stamp(100+i),isRead:true});await batch.commit();
  const first=await inquiry({action:'syncBookings'},auth('c'));assert.equal(first.hasMore,true);
  const second=await inquiry({action:'syncBookings',cursor:first.cursor},auth('c'));assert.equal(second.hasMore,false);
  const id=(await db.doc('bookings/b').get()).data().inquiryId;assert.equal((await db.collection(`inquiries/${id}/messages`).get()).size,105);
});
test('historical photos remain participant-readable while the old upload path is closed',async()=>{
  await legacy();const bytes=new Uint8Array([137,80,78,71]);
  await env.withSecurityRulesDisabled(async context=>{await uploadBytes(ref(context.storage(),'messages/b/c/original.png'),bytes,{contentType:'image/png'});});
  await assertSucceeds(getBytes(ref(env.authenticatedContext('p').storage(),'messages/b/c/original.png')));
  await assertFails(getBytes(ref(env.authenticatedContext('s').storage(),'messages/b/c/original.png')));
  await assertFails(uploadBytes(ref(env.authenticatedContext('c').storage(),'messages/b/c/new.png'),bytes,{contentType:'image/png'}));
});
test('time off rejects overlapping accepted work and concurrent acceptance cannot slip through',async()=>{
  const b=await createOffer(),start=b.scheduledDate.toMillis(),end=start+3600000;
  const results=await Promise.allSettled([timeOff({action:'add',blockId:'leave',start,end},auth('p')),booking({action:'accept',bookingId:'new',acceptAgreement:true,agreementHash:b.agreement.hash},auth('p'))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const current=(await db.doc('bookings/new').get()).data();
  if(current.status==='Accepted')await assert.rejects(timeOff({action:'add',blockId:'leave2',start,end},auth('p')),/overlaps/);
  else {await assert.rejects(booking({action:'accept',bookingId:'new',acceptAgreement:true,agreementHash:b.agreement.hash},auth('p')),/hours/);await timeOff({action:'remove',blockId:'leave'},auth('p'));await booking({action:'accept',bookingId:'new',acceptAgreement:true,agreementHash:b.agreement.hash},auth('p'));}
});
test('new offers have a bounded deadline; expired offers cannot be accepted or amended and sweeping is idempotent',async()=>{
  const b=await createOffer(),expiry=require('../offer_expiry');assert.equal(b.offerExpiresAt.toMillis(),b.scheduledDate.toMillis());
  await db.doc('bookings/new').update({offerExpiresAt:stamp(Date.now()-1)});
  await assert.rejects(booking({action:'accept',bookingId:'new',acceptAgreement:true,agreementHash:b.agreement.hash},auth('p')),/expired/);
  await assert.rejects(booking({action:'requestChanges',bookingId:'new',reason:'Please revise the work schedule.'},auth('p')),/expired/);
  assert.equal(await expiry.expire(db,'new'),true);assert.equal(await expiry.expire(db,'new'),false);
  const after=(await db.doc('bookings/new').get()).data();assert.equal(after.status,'Expired');assert.deepEqual(after.agreement,b.agreement);assert.equal((await db.collection('contracts').get()).size,0);
  await ops.onBookingUpdated.run({before:{data:()=>b},after:{id:'new',data:()=>after}},{eventId:'expired-trigger'});
  await ops.onBookingUpdated.run({before:{data:()=>b},after:{id:'new',data:()=>after}},{eventId:'expired-trigger-retry'});
  assert.equal((await db.collection('notifications').where('title','==','Contract offer expired').get()).size,2);
  assert.equal((await db.collection('notifications').where('title','==','Booking Expired').get()).size,0);
});
test('sweep expires legacy unanswered offers without completing work or creating a contract',async()=>{
  await legacy('Pending');await db.doc('bookings/b').update({scheduledDate:stamp(Date.now()-1000)});await require('../offer_expiry').sweep(db);
  assert.equal((await db.doc('bookings/b').get()).data().status,'Expired');assert.equal((await db.collection('contracts').get()).size,0);
});
