const { before, after, beforeEach, test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, getDocs, collection, query, where, or, and, GeoPoint, Timestamp } = require('firebase/firestore');
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
      await setDoc(doc(db,'users',uid), {role, accountStatus:'Active',fullName:uid,email:`${uid}@example.test`,contactNumber:'09123456789'});
    await setDoc(doc(db,'serviceProviders','provider'), {userId:'provider', isVerified:true, averageRating:4, acceptedBookings:1, certificationHistory:[], approvedCertificationIds:[],locationPolicyVersion:1,baseBarangayId:'1102315026',serviceBarangayIds:['1102315026']});
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
  await assertSucceeds(getDoc(doc(env.authenticatedContext('admin',{email_verified:true}).firestore(),'users','customer')));
});

test('customers can save a private job pin; provider home pins cannot be written directly', async () => {
  const customer=env.authenticatedContext('customer').firestore();
  const provider=env.authenticatedContext('provider').firestore();
  await assertSucceeds(updateDoc(doc(customer,'users','customer'),{location:new GeoPoint(7.3,125.6),updatedBy:'customer'}));
  await assertFails(updateDoc(doc(provider,'serviceProviders','provider'),{location:new GeoPoint(7.31,125.61),updatedBy:'provider'}));
  await assertFails(updateDoc(doc(customer,'serviceProviders','provider'),{location:new GeoPoint(7.4,125.6),updatedBy:'customer'}));
  await assertFails(updateDoc(doc(provider,'users','customer'),{location:new GeoPoint(7.4,125.6),updatedBy:'provider'}));
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
test('old booking messages are read-only except recipient read receipts', async () => {
  const db = env.authenticatedContext('customer').firestore();
  const payload = {bookingId:'booking', senderId:'customer',receiverId:'provider',messageType:'Text',messageText:'hello',isRead:false};
  await assertFails(setDoc(doc(db,'messages','valid'),payload));
  await assertFails(setDoc(doc(db,'messages','invalid'), {...payload, receiverId:'stranger'}));
  const receiver = env.authenticatedContext('provider').firestore();
  await assertFails(updateDoc(doc(receiver,'messages','message'),{messageText:'rewritten',isRead:true}));
  await assertSucceeds(updateDoc(doc(receiver,'messages','message'),{isRead:true}));
});
test('audit records cannot be fabricated or erased, even by client administrators', async () => {
  await assertFails(setDoc(doc(env.authenticatedContext('admin',{email_verified:true}).firestore(),'auditLogs','fake'), {action:'fake'}));
});

test('customer and provider conversation queries can read both directions without exposing strangers', async () => {
  for (const uid of ['customer','provider']) {
    const db = env.authenticatedContext(uid,{email_verified:true}).firestore();
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
    const db = env.authenticatedContext(uid,{email_verified:true}).firestore();
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
  await assertSucceeds(getBytes(ref(env.authenticatedContext('admin',{email_verified:true}).storage(), 'certificates/provider/cert/proof.png')));
  await assertFails(uploadBytes(ref(env.authenticatedContext('stranger').storage(),'messages/booking/stranger/image.png'), bytes, {contentType:'image/png'}));
});

test('new unverified providers can upload PDF/JPEG/PNG evidence and submit a pending certificate', async () => {
  const uid = 'new-certificate-provider';
  const context = env.authenticatedContext(uid);
  const db = context.firestore();
  await setDoc(doc(db,'users',uid), {role:'Provider',accountStatus:'Active',fullName:'New Provider'});
  await setDoc(doc(db,'serviceProviders',uid), {userId:uid,isVerified:false,verificationStatus:'Pending'});
  const storage = context.storage();
  const certId = 'new-cert';
  for (const [extension, contentType] of [['pdf','application/pdf'],['jpg','image/jpeg'],['png','image/png']]) {
    const object = ref(storage, `certificates/${uid}/${certId}/proof.${extension}`);
    await assertSucceeds(uploadBytes(object,new Uint8Array([37,80,68,70]),{contentType}));
    await assertSucceeds(getBytes(object));
    await assertFails(getBytes(ref(env.authenticatedContext('stranger').storage(), object.fullPath)));
  }
  const history = [{id:certId,name:'Carpentry NC II',provider:'TESDA',certificationId:'NC-TEST',status:'Pending',url:`gs://${ref(storage).bucket}/certificates/${uid}/${certId}/proof.pdf`,issueDate:'2025-01-01',expirationDate:'2030-01-01'}];
  await assertSucceeds(updateDoc(doc(db,'serviceProviders',uid),{certificationHistory:history,approvedCertificationIds:[],updatedBy:uid}));
  await assertFails(updateDoc(doc(db,'serviceProviders',uid),{approvedCertificationIds:[certId]}));
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

test('inquiries, messages and attachments are private to their actual participants and cannot be forged',async()=>{
  await env.withSecurityRulesDisabled(async c=>{
    await setDoc(doc(c.firestore(),'inquiries','thread'),{customerId:'customer',providerId:'provider',participantIds:['customer','provider'],blockedBy:[],uploadPermits:{customer:{permitId:'photo',extension:'png',expiresAt:Timestamp.fromMillis(Date.now()+600000),used:false}}});
    await setDoc(doc(c.firestore(),'inquiries','thread','messages','m'),{senderId:'customer',text:'Private requirements'});
  });
  for(const uid of ['customer','provider']) {
    const db=env.authenticatedContext(uid,{email_verified:true}).firestore();
    await assertSucceeds(getDoc(doc(db,'inquiries','thread')));
    await assertSucceeds(getDocs(query(collection(db,'inquiries'),where('participantIds','array-contains',uid))));
    await assertSucceeds(getDocs(collection(db,'inquiries','thread','messages')));
    await assertFails(updateDoc(doc(db,'inquiries','thread'),{providerMessageCount:999}));
    await assertFails(setDoc(doc(db,'inquiries','thread','messages','forged'),{senderId:uid,text:'Bypass discussion count'}));
  }
  for(const uid of ['stranger','admin','agency']) {
    const db=env.authenticatedContext(uid,{email_verified:true}).firestore();
    await assertFails(getDoc(doc(db,'inquiries','thread')));
    await assertFails(getDoc(doc(db,'inquiries','thread','messages','m')));
  }
  const bytes=new Uint8Array([137,80,78,71]);
  await assertSucceeds(uploadBytes(ref(env.authenticatedContext('customer').storage(),'inquiries/thread/customer/photo.png'),bytes,{contentType:'image/png'}));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('provider').storage(),'inquiries/thread/customer/photo.png')));
  await assertFails(getBytes(ref(env.authenticatedContext('stranger').storage(),'inquiries/thread/customer/photo.png')));
  await assertFails(uploadBytes(ref(env.authenticatedContext('provider').storage(),'inquiries/thread/customer/fake.png'),bytes,{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(env.authenticatedContext('customer').storage(),'inquiries/thread/customer/no-permit.png'),bytes,{contentType:'image/png'}));
});

test('blocks revoke an issued upload permit and private contract records cannot be forged',async()=>{
  await env.withSecurityRulesDisabled(async c=>{
    await setDoc(doc(c.firestore(),'inquiries','blocked'),{participantIds:['customer','provider'],blockedBy:['provider'],uploadPermits:{customer:{permitId:'blocked-photo',extension:'png',expiresAt:Timestamp.fromMillis(Date.now()+600000),used:false}}});
    for(const name of ['payments','amendments','agreementVersions','workEvents'])await setDoc(doc(c.firestore(),'bookings','booking',name,'record'),{status:'Actual server record'});
    await setDoc(doc(c.firestore(),'bookingUserReports','report'),{bookingId:'booking',evidence:[{text:'Preserved evidence'}],status:'open'});
  });
  await assertFails(uploadBytes(ref(env.authenticatedContext('customer').storage(),'inquiries/blocked/customer/blocked-photo.png'),new Uint8Array([137,80,78,71]),{contentType:'image/png'}));
  for(const name of ['payments','amendments','agreementVersions','workEvents']) {
    for(const uid of ['customer','provider','admin'])await assertSucceeds(getDoc(doc(env.authenticatedContext(uid,{email_verified:true}).firestore(),'bookings','booking',name,'record')));
    await assertFails(getDoc(doc(env.authenticatedContext('stranger').firestore(),'bookings','booking',name,'record')));
    await assertFails(updateDoc(doc(env.authenticatedContext('customer').firestore(),'bookings','booking',name,'record'),{status:'Forged'}));
  }
  await assertFails(updateDoc(doc(env.authenticatedContext('admin',{email_verified:true}).firestore(),'bookingUserReports','report'),{evidence:[]}));
  await assertFails(getDoc(doc(env.authenticatedContext('customer').firestore(),'rateLimits','private')));
});

test('hourly listings require review and providers cannot publish unsupported services',async()=>{
  const db=env.authenticatedContext('provider').firestore();
  const data={providerId:'provider',category:'Cleaning',serviceTitle:'House Cleaning',priceType:'fixed',approvalStatus:'Pending',isActive:false};
  await assertSucceeds(setDoc(doc(db,'services','valid'),data));
  await assertSucceeds(setDoc(doc(db,'services','hourly'),{...data,priceType:'hourly'}));
  await assertFails(updateDoc(doc(db,'services','hourly'),{approvalStatus:'Approved',isActive:true}));
  await assertFails(setDoc(doc(db,'services','custom'),{...data,category:'Custom Services',serviceTitle:'Anything'}));
  await assertFails(setDoc(doc(db,'services','unsupported'),{...data,category:'Repair and Technical Services',serviceTitle:'Industrial Electrical Design'}));
});

test('providers need profile completion and KYC for submissions but can keep private drafts',async()=>{
  const db=env.authenticatedContext('provider').firestore();
  const data={providerId:'provider',category:'Cleaning',serviceTitle:'House Cleaning',priceType:'fixed',approvalStatus:'Pending',isActive:false};
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'serviceProviders','provider'),{isVerified:false}));
  await assertFails(setDoc(doc(db,'services','blocked'),data));
  await assertSucceeds(setDoc(doc(db,'services','draft'),{...data,approvalStatus:'Draft'}));
  await assertFails(updateDoc(doc(db,'services','draft'),{approvalStatus:'Pending'}));
  await env.withSecurityRulesDisabled(async c=>{
    await updateDoc(doc(c.firestore(),'serviceProviders','provider'),{isVerified:true});
    await updateDoc(doc(c.firestore(),'users','provider'),{contactNumber:''});
  });
  await assertFails(setDoc(doc(db,'services','blocked'),data));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users','provider'),{contactNumber:'09123456789'}));
  await assertSucceeds(updateDoc(doc(db,'services','draft'),{approvalStatus:'Pending'}));
});

test('plumbing and electrical submissions remain pending; retired construction services cannot be submitted',async()=>{
  const db=env.authenticatedContext('provider').firestore();
  const base={providerId:'provider',category:'Repair and Technical Services',priceType:'daily',approvalStatus:'Pending',isActive:false};
  for (const title of ['Plumbing Repair','Electrical Repair']) {
    await assertSucceeds(setDoc(doc(db,'services',title),{...base,serviceTitle:title}));
    await assertFails(updateDoc(doc(db,'services',title),{approvalStatus:'Approved',isActive:true}));
  }
  for (const title of ['Masonry','Concrete Block Laying','Bricklaying','Wall Plastering','Construction Carpentry','Tile Installation','Tile Repair','Construction Painting']) {
    await assertFails(setDoc(doc(db,'services',title),{...base,category:'Construction',serviceTitle:title}));
  }
});

test('active admins do not need email verification; role, account status and MFA still protect admin data',async()=>{
  const unverified=env.authenticatedContext('admin',{email_verified:false});
  await assertSucceeds(getDoc(doc(unverified.firestore(),'users','customer')));
  const bytes=new Uint8Array([137,80,78,71]);
  await assertSucceeds(uploadBytes(ref(env.authenticatedContext('provider').storage(),'certificates/provider/cert/mfa-proof.png'),bytes,{contentType:'image/png'}));
  await assertSucceeds(getBytes(ref(unverified.storage(),'certificates/provider/cert/mfa-proof.png')));
  for(const uid of ['customer','provider','stranger','agency'])await assertFails(getDoc(doc(env.authenticatedContext(uid).firestore(),'users','admin')));
  await env.withSecurityRulesDisabled(async c=>{await updateDoc(doc(c.firestore(),'users','admin'),{accountStatus:'Suspended'});});
  await assertFails(getDoc(doc(unverified.firestore(),'users','customer')));
  await assertFails(getBytes(ref(unverified.storage(),'certificates/provider/cert/mfa-proof.png')));
  await env.withSecurityRulesDisabled(async c=>{await updateDoc(doc(c.firestore(),'users','admin'),{accountStatus:'Active'});});
  await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'securityPolicy','admin'),{requireMfa:true});});
  const primary=env.authenticatedContext('admin',{email_verified:false});
  await assertFails(getDoc(doc(primary.firestore(),'users','customer')));
  await assertFails(getBytes(ref(primary.storage(),'certificates/provider/cert/mfa-proof.png')));
  const mfa=env.authenticatedContext('admin',{email_verified:false,firebase:{sign_in_provider:'password',identities:{},sign_in_second_factor:'phone'}});
  await assertSucceeds(getDoc(doc(mfa.firestore(),'users','customer')));
  await assertSucceeds(getBytes(ref(mfa.storage(),'certificates/provider/cert/mfa-proof.png')));
  await assertFails(updateDoc(doc(mfa.firestore(),'securityPolicy','admin'),{requireMfa:false}));
});
