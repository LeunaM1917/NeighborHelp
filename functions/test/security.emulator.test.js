const { before, after, beforeEach, test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, getDocs, collection, query, where, or, and } = require('firebase/firestore');
const { ref, uploadBytes, getBytes } = require('firebase/storage');
let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-neighborhelp',
    firestore: {rules: fs.readFileSync(path.join(__dirname, '../../firebase/firestore.rules'), 'utf8')},
    storage: {rules: fs.readFileSync(path.join(__dirname, '../../firebase/storage.rules'), 'utf8')},
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore();
    for (const [uid,role] of [['customer','Customer'],['provider','Provider'],['admin','Administrator'],['stranger','Customer'],['agency','Verification Agency']])
      await setDoc(doc(db,'users',uid), {role, accountStatus:'Active',fullName:uid,email:`${uid}@example.test`});
    await setDoc(doc(db,'serviceProviders','provider'), {userId:'provider', isVerified:true, averageRating:4, acceptedBookings:1, certificationHistory:[], approvedCertificationIds:[]});
    await setDoc(doc(db,'bookings','booking'), {customerId:'customer',providerId:'provider',contractId:'contract',status:'Accepted',totalFee:100});
    await setDoc(doc(db,'contracts','contract'), {customerId:'customer',providerId:'provider',status:'active'});
    await setDoc(doc(db,'messages','message'), {bookingId:'booking',threadId:'customer_provider',senderId:'customer',receiverId:'provider',messageText:'hello',isRead:false});
    await setDoc(doc(db,'messages','reply'), {bookingId:'booking',threadId:'customer_provider',senderId:'provider',receiverId:'customer',messageText:'reply',isRead:false});
  });
});
test('customers cannot promote themselves, reactivate accounts or self-verify', async () => {
  const db = env.authenticatedContext('customer').firestore();
  for (const patch of [{role:'Administrator'}, {accountStatus:'Active',role:'Verification Agency'}, {isVerified:true}]) await assertFails(updateDoc(doc(db,'users','customer'),patch));
  await assertSucceeds(updateDoc(doc(db,'users','customer'), {fullName:'Updated'}));
});
test('registration cannot create a privileged user or verified identity', async () => {
  const db = env.authenticatedContext('new').firestore();
  await assertFails(setDoc(doc(db,'users','new'), {role:'Administrator',accountStatus:'Active'}));
  await assertFails(setDoc(doc(db,'users','new'), {role:'Customer',accountStatus:'Active',isVerified:true}));
  await assertSucceeds(setDoc(doc(db,'users','new'), {role:'Customer',accountStatus:'Active'}));
});
test('private profiles are hidden from unrelated users', async () => {
  await assertFails(getDoc(doc(env.authenticatedContext('stranger').firestore(),'users','customer')));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('admin').firestore(),'users','customer')));
});
test('booking participants cannot alter fees, participants, status or create bookings directly', async () => {
  const db = env.authenticatedContext('customer').firestore();
  await assertSucceeds(getDoc(doc(db,'bookings','booking')));
  for (const patch of [{totalFee:1}, {status:'Completed'}, {providerId:'stranger'}]) await assertFails(updateDoc(doc(db,'bookings','booking'),patch));
  await assertFails(setDoc(doc(db,'bookings','new'), {customerId:'customer'}));
});
test('providers cannot forge ratings or certificate approval; legacy agency cannot review', async () => {
  const db = env.authenticatedContext('provider').firestore();
  for (const patch of [{averageRating:5}, {isVerified:true,acceptedBookings:999}, {approvedCertificationIds:['fake']}]) await assertFails(updateDoc(doc(db,'serviceProviders','provider'),patch));
  await assertFails(updateDoc(doc(env.authenticatedContext('agency').firestore(),'serviceProviders','provider'), {isVerified:true}));
});
test('messages require the actual other booking participant; read receipts cannot rewrite content', async () => {
  const db = env.authenticatedContext('customer').firestore();
  const payload = {bookingId:'booking', senderId:'customer',receiverId:'provider',messageType:'Text',messageText:'hello',isRead:false};
  await assertSucceeds(setDoc(doc(db,'messages','valid'),payload));
  await assertFails(setDoc(doc(db,'messages','invalid'), {...payload, receiverId:'stranger'}));
  const receiver = env.authenticatedContext('provider').firestore();
  await assertFails(updateDoc(doc(receiver,'messages','message'),{messageText:'rewritten',isRead:true}));
  await assertSucceeds(updateDoc(doc(receiver,'messages','message'),{isRead:true}));
});
test('audit records cannot be fabricated or erased, even by client administrators', async () => {
  await assertFails(setDoc(doc(env.authenticatedContext('admin').firestore(),'auditLogs','fake'), {action:'fake'}));
});

test('customer and provider conversation queries can read both directions without exposing strangers', async () => {
  for (const uid of ['customer','provider']) {
    const db = env.authenticatedContext(uid).firestore();
    const participant = or(where('senderId','==',uid),where('receiverId','==',uid));
    for (const scope of [where('threadId','==','customer_provider'),where('bookingId','in',['booking'])]) {
      const rows = await assertSucceeds(getDocs(query(collection(db,'messages'),and(scope,participant))));
      require('node:assert/strict').equal(rows.size,2);
    }
    await assertSucceeds(getDocs(query(collection(db,'messages'),where('receiverId','==',uid),where('isRead','==',false))));
  }
  const stranger = env.authenticatedContext('stranger').firestore();
  await assertFails(getDocs(query(collection(stranger,'messages'),where('threadId','==','customer_provider'))));
  await assertFails(getDoc(doc(stranger,'messages','message')));
});

test('booking and contract list queries are authorized for participants and restricted after suspension', async () => {
  for (const [uid,field] of [['customer','customerId'],['provider','providerId']]) {
    const db = env.authenticatedContext(uid).firestore();
    for (const name of ['bookings','contracts']) {
      const rows = await assertSucceeds(getDocs(query(collection(db,name),where(field,'==',uid))));
      require('node:assert/strict').equal(rows.size,1);
    }
    await assertSucceeds(getDocs(query(collection(db,'bookings'),and(where('contractId','==','contract'),
      or(where('customerId','==',uid),where('providerId','==',uid))))));
  }
  await env.withSecurityRulesDisabled(c => updateDoc(doc(c.firestore(),'users','customer'),{accountStatus:'Suspended'}));
  const blocked=env.authenticatedContext('customer').firestore();
  await assertFails(getDocs(query(collection(blocked,'bookings'),where('customerId','==','customer'))));
  await assertFails(getDocs(query(collection(blocked,'messages'),where('receiverId','==','customer'))));
});
test('certificate documents are private and immutable; chat images require participation', async () => {
  const bytes = new Uint8Array([137,80,78,71]);
  const providerStorage = env.authenticatedContext('provider').storage();
  const cert = ref(providerStorage, 'certificates/provider/cert/proof.png');
  await assertSucceeds(uploadBytes(cert,bytes,{contentType:'image/png'}));
  await assertFails(uploadBytes(cert,bytes,{contentType:'image/png'}));
  await assertFails(getBytes(ref(env.authenticatedContext('stranger').storage(), 'certificates/provider/cert/proof.png')));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('admin').storage(), 'certificates/provider/cert/proof.png')));
  await assertFails(uploadBytes(ref(env.authenticatedContext('stranger').storage(),'messages/booking/stranger/image.png'), bytes, {contentType:'image/png'}));
});

test('profile photos allow owner image uploads but reject cross-account writes, large files and non-images', async () => {
  const owner=env.authenticatedContext('customer').storage();
  const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64');
  const image=ref(owner,'users/customer/profile-test.png');
  await assertSucceeds(uploadBytes(image,png,{contentType:'image/png'}));
  await assertSucceeds(getBytes(image));
  await assertFails(uploadBytes(ref(env.authenticatedContext('stranger').storage(),'users/customer/profile-test.png'),png,{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(owner,'users/customer/too-big.jpg'),new Uint8Array(5*1024*1024+1),{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(ref(owner,'users/customer/file.txt'),png,{contentType:'text/plain'}));
});
