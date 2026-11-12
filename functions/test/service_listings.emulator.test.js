'use strict';
const {before, after, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, updateDoc} = require('firebase/firestore');
const {ref, uploadBytes, deleteObject} = require('firebase/storage');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const functions = require('firebase-functions/v1');
const {credentials, certificate} = require('./marketplace_fixtures');
const {hasMatchingCertificate} = require('../domain');
let env, app, db, bucket, command, certCommand;
const auth = uid => ({auth:{uid,token:{email_verified:true}}});
const image = n => Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),Buffer.from(`synthetic-emulator-photo-${n}`)]);
const listing = (extra = {}) => ({category:'Cleaning',serviceTitle:'House Cleaning',description:'Clean the agreed rooms and surfaces.',estimatedDuration:'1 hour',
  estimatedPrice:525.5,priceType:'hourly',certificationEntryId:'cert',serviceImages:[1,2,3].map(n=>`gs://${bucket.name}/services/p/listing/${n}.png`),...extra});
const submit = fields => command({action:'submit',serviceId:'listing',fields:listing(fields)},auth('p'));
const approve = extra => command({action:'approve',serviceId:'listing',alignmentConfirmed:true,notes:'Credential, category, scope and all photos checked.',...extra},auth('a'));
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) throw Error('Demo Firestore and Storage emulators required');
  env = await initializeTestEnvironment({projectId:'demo-neighborhelp'});
  app = initializeApp({projectId:'demo-neighborhelp',storageBucket:'demo-neighborhelp.appspot.com'},'listing-tests');
  db = getFirestore(app); bucket = getStorage(app).bucket();
  command = require('../service_listing_commands')({db,functions,bucket});
  certCommand = require('../certificate_commands')({db,functions});
});
after(async () => { await deleteApp(app); await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore(); await bucket.deleteFiles({prefix:'services/p/'});
  for (const [id,role] of [['p','Provider'],['p2','Provider'],['a','Administrator'],['c','Customer']]) {
    await db.doc(`users/${id}`).set({role,accountStatus:'Active',fullName:'Test Member',contactNumber:'09123456789'});
  }
  await db.doc('serviceProviders/p').set({userId:'p',isVerified:true,...credentials()});
  for (const n of [1,2,3]) await bucket.file(`services/p/listing/${n}.png`).save(image(n),{resumable:false,metadata:{contentType:'image/png'}});
});
test('incomplete drafts are private; client writes and forged approvals are denied for every role',async () => {
  await db.doc('serviceProviders/p').update({isVerified:false});
  await command({action:'saveDraft',serviceId:'listing',fields:{category:'Custom category',serviceImages:[]}},auth('p'));
  const saved = (await db.doc('services/listing').get()).data();
  assert.equal(saved.approvalStatus,'Draft'); assert.equal(saved.isActive,false);
  await assert.rejects(submit(),{code:'failed-precondition'});
  for (const uid of ['p','a','c']) {
    const client = env.authenticatedContext(uid).firestore();
    await assertFails(setDoc(doc(client,'services',`forged-${uid}`),{...listing(),providerId:uid,approvalStatus:'Approved',isActive:true}));
    await assertFails(updateDoc(doc(client,'services','listing'),{approvalStatus:'Approved',isActive:true}));
  }
  await assert.rejects(command({action:'saveDraft',serviceId:'listing',fields:listing()},auth('p2')),{code:'permission-denied'});
  await assertFails(updateDoc(doc(env.authenticatedContext('p').firestore(),'serviceProviders','p'),{approvedServiceListings:{forged:{status:'Approved'}}}));
});
test('three owned distinct photos and an approved matching certificate are required at submission and approval',async () => {
  await assert.rejects(submit({serviceImages:listing().serviceImages.slice(0,2)}),/at least 3/);
  await assert.rejects(submit({serviceImages:[...listing().serviceImages.slice(0,2),'https://example.test/stock.jpg']}),/External or stock/);
  await assert.rejects(submit({serviceImages:[listing().serviceImages[0],listing().serviceImages[0],listing().serviceImages[2]]}),/distinct/);
  await assert.rejects(submit({certificationEntryId:'another-provider'}),/current certificate/);
  await db.doc('serviceProviders/p').update({certificationHistory:[certificate('Plumbing NC II')]});
  await assert.rejects(submit(),/does not match/);
  await db.doc('serviceProviders/p').update({certificationHistory:[certificate()]});
  await submit();
  const saved = (await db.doc('services/listing').get()).data();
  assert.equal(saved.approvalStatus,'Pending'); assert.equal(saved.isActive,false); assert.equal(saved.photoManifest.length,3);
  await assert.rejects(command({action:'setActive',serviceId:'listing',isActive:true},auth('p')),/approval/);
  await assert.rejects(approve({alignmentConfirmed:false}),/Confirm certificate alignment/);
  await bucket.file('services/p/listing/3.png').delete();
  await assert.rejects(approve(),/photo is unavailable/);
});
test('fake MIME types, oversized files, missing objects, foreign paths and identical uploads do not satisfy the photo count',async () => {
  const url = `gs://${bucket.name}/services/p/listing/3.png`;
  await bucket.file('services/p/listing/3.png').save(Buffer.from('not an image'),{resumable:false,metadata:{contentType:'image/png'}});
  await assert.rejects(submit(),/JPG, PNG or WebP/);
  await bucket.file('services/p/listing/3.png').save(image(1),{resumable:false,metadata:{contentType:'image/png'}});
  await assert.rejects(submit(),/different JPG/);
  const big = Buffer.alloc(5*1024*1024+1); image(3).copy(big);
  await bucket.file('services/p/listing/3.png').save(big,{resumable:false,metadata:{contentType:'image/png'}});
  await assert.rejects(submit(),/5 MB/);
  await assert.rejects(submit({serviceImages:[...listing().serviceImages.slice(0,2),url.replace('/p/','/p2/')]}),/uploaded for this listing/);
});
test('custom categories and services become public only after scoped administrator review; history remains intact',async () => {
  await db.doc('serviceProposals/historical').set({providerId:'p',status:'Approved'});
  await submit({category:'Home Care',serviceTitle:'Custom Upholstery Cleaning'});
  let saved = (await db.doc('services/listing').get()).data();
  let p = (await db.doc('serviceProviders/p').get()).data();
  assert.equal(hasMatchingCertificate(p,saved.category,saved.serviceTitle),false);
  assert.equal((await db.collection('serviceCatalog').get()).size,0);
  await assert.rejects(command({action:'approve',serviceId:'listing',alignmentConfirmed:true,notes:'A provider cannot review this.'},auth('p')),{code:'permission-denied'});
  await db.doc('securityPolicy/admin').set({requireMfa:true});
  await assert.rejects(approve(),{code:'permission-denied'});
  await db.doc('securityPolicy/admin').delete(); await approve();
  saved = (await db.doc('services/listing').get()).data(); p = (await db.doc('serviceProviders/p').get()).data();
  assert.equal(saved.approvalStatus,'Approved'); assert.equal(saved.isActive,true);
  assert.equal((await db.collection('serviceCatalog').get()).size,1);
  assert.equal(saved.certificateAlignment.notes,undefined);
  await assertFails(setDoc(doc(env.authenticatedContext('p').firestore(),'serviceCatalog','forged'),{category:'Unreviewed',serviceTitle:'Unreviewed'}));
  assert.equal(hasMatchingCertificate(p,saved.category,saved.serviceTitle),true);
  assert.equal(hasMatchingCertificate(p,'Another Category',saved.serviceTitle),false);
  assert.equal((await db.collection('serviceProposals').get()).size,1);
  await command({action:'setActive',serviceId:'listing',isActive:false},auth('p'));
  await command({action:'setActive',serviceId:'listing',isActive:true},auth('p'));
  await command({action:'saveDraft',serviceId:'listing',fields:{description:'A revised listing must undergo review again.'}},auth('p'));
  assert.equal((await db.doc('services/listing').get()).data().isActive,false);
  await assert.rejects(command({action:'setActive',serviceId:'listing',isActive:true},auth('p')),/approval/);
});
test('equivalent credentials require issuing authority verification and separate listing alignment; unrelated approvals survive certificate submission',async () => {
  const entry = {id:'equivalent',credentialType:'equivalent',name:'Domestic cleaning qualification',provider:'Test Credential Authority',certificationId:'EQ-001',
    url:`gs://${bucket.name}/certificates/p/equivalent/proof.pdf`,issueDate:'2025-01-01',expirationDate:'2099-01-01'};
  await certCommand({action:'submit',providerId:'p',entry:{...entry,status:'Approved',issuerVerified:true,reviewedBy:'forged'}},auth('p'));
  let p = (await db.doc('serviceProviders/p').get()).data();
  assert.deepEqual(p.approvedCertificationIds,['cert']); assert.equal(p.certificationHistory[1].status,'Pending');
  await assert.rejects(submit({certificationEntryId:'equivalent'}),/current certificate/);
  const review = {providerId:'p',certificationEntryId:'equivalent',decision:'Approved',notes:'Checked credential holder, number, scope and dates with the issuer.'};
  await assert.rejects(certCommand(review,auth('a')),{code:'failed-precondition'});
  await certCommand({...review,issuerVerified:true},auth('a'));
  p = (await db.doc('serviceProviders/p').get()).data();
  assert.equal(hasMatchingCertificate({...p,certificationHistory:p.certificationHistory.slice(1)},'Cleaning','House Cleaning'),false);
  await submit({certificationEntryId:'equivalent'}); await approve();
  p = (await db.doc('serviceProviders/p').get()).data();
  assert.equal(hasMatchingCertificate({...p,certificationHistory:p.certificationHistory.slice(1)},'Cleaning','House Cleaning'),true);
  await certCommand({...review,decision:'Rejected',notes:'Issuer could not confirm the renewed credential.'},auth('a'));
  p = (await db.doc('serviceProviders/p').get()).data();
  assert.equal(hasMatchingCertificate({...p,certificationHistory:p.certificationHistory.slice(1)},'Cleaning','House Cleaning'),false);
});
test('rejection requires a reason; valid resubmission returns to pending and cannot retain public approval',async () => {
  await submit();
  await assert.rejects(command({action:'reject',serviceId:'listing',reason:''},auth('a')),{code:'invalid-argument'});
  await command({action:'reject',serviceId:'listing',reason:'Please correct the service scope and photos.'},auth('a'));
  let saved = (await db.doc('services/listing').get()).data(); assert.equal(saved.approvalStatus,'Rejected'); assert.equal(saved.isActive,false);
  await submit(); saved = (await db.doc('services/listing').get()).data();
  assert.equal(saved.approvalStatus,'Pending'); assert.equal(saved.rejectionReason,''); assert.equal(saved.isActive,false);
});
test('reviewed service photos cannot be overwritten or deleted through client Storage access',async () => {
  const storage = env.authenticatedContext('p').storage();
  await uploadBytes(ref(storage,'services/p/new-listing/photo.png'),image(7),{contentType:'image/png'});
  await assertFails(uploadBytes(ref(storage,'services/p/new-listing/photo.png'),image(8),{contentType:'image/png'}));
  await assertFails(deleteObject(ref(storage,'services/p/new-listing/photo.png')));
  await assertFails(uploadBytes(ref(env.authenticatedContext('c').storage(),'services/c/listing/photo.png'),image(9),{contentType:'image/png'}));
});
test('adding a first certificate preserves credentials stored in older profile formats',async () => {
  await db.doc('serviceProviders/p').update({certificationHistory:[],approvedCertificationIds:[],certifications:['Existing historical qualification']});
  const entry = {...certificate(),url:`gs://${bucket.name}/certificates/p/cert/proof.pdf`};
  await certCommand({action:'submit',providerId:'p',entry},auth('p'));
  const history = (await db.doc('serviceProviders/p').get()).data().certificationHistory;
  assert.equal(history.length,2); assert.equal(history[0].name,'Existing historical qualification');
  assert.equal(history[0].status,'Pending'); assert.equal(history[1].id,'cert');
});
test('credentials issued today use the Manila calendar date and invalid dates are rejected',async () => {
  const entry = {...certificate(),issueDate:new Date(Date.now()+8*3600000).toISOString().slice(0,10),url:`gs://${bucket.name}/certificates/p/cert/proof.pdf`};
  await certCommand({action:'submit',providerId:'p',entry},auth('p'));
  await certCommand({providerId:'p',certificationEntryId:'cert',decision:'Approved',registryChecked:true,notes:'Holder, number, qualification and current validity verified.'},auth('a'));
  await assert.rejects(certCommand({action:'submit',providerId:'p',entry:{...entry,issueDate:'2025-02-30'}},auth('p')),{code:'invalid-argument'});
});
