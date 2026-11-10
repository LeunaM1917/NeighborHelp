'use strict';
const {before, after, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {getDoc, doc, collection, query, where, getDocs, updateDoc, onSnapshot} = require('firebase/firestore');
const {ref, uploadBytes, getBytes} = require('firebase/storage');
let env, app, db, report, inquiry;
const auth = uid => ({auth: {uid, token: {email_verified: false}}});
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Demo emulator required.');
  env = await initializeTestEnvironment({projectId: 'demo-neighborhelp'});
  app = admin.initializeApp({projectId: 'demo-neighborhelp'}, 'dispute-tests');
  db = getFirestore(app);
  report = require('../report_commands')({db, functions, storageBucket: 'demo-neighborhelp', verifyPhoto: async () => ({size: 100, contentType: 'image/png'})});
  inquiry = require('../inquiry_commands')({db, functions});
});
after(async () => {await require('firebase-admin/app').deleteApp(app); await env?.cleanup();});
beforeEach(async () => {
  await env.clearFirestore();
  for (const [id, role] of [['c', 'Customer'], ['p', 'Provider'], ['a', 'Administrator'], ['staff', 'Administrator'], ['other', 'Customer']]) {
    await db.doc(`users/${id}`).set({role, accountStatus: 'Active', fullName: id});
  }
  await db.doc('bookings/b').set({customerId: 'c', providerId: 'p', status: 'Accepted', totalFee: 1234, serviceId: 's'});
});
async function submitted(extra = {}) {
  return report({action: 'reportBooking', bookingId: 'b', reason: 'Incomplete work', details: 'The agreed rooms were not cleaned.', ...extra}, auth('c'));
}
async function reviewing() {
  const {reportId} = await submitted();
  return report({action: 'startReview', reportId}, auth('a'));
}

test('reports accept no photo, derive the reported party and do not duplicate on retry', async () => {
  await assert.rejects(submitted.call(null, {bookingId: 'missing'}), /participants/);
  await assert.rejects(report({action: 'reportBooking', bookingId: 'b', reason: 'Bad job'}, auth('other')), /participants/);
  const result = await submitted({reportedUserId: 'other'});
  const data = (await db.doc(`bookingUserReports/${result.reportId}`).get()).data();
  assert.equal(data.reportedUserId, 'p'); assert.deepEqual(data.photoUrls, []);
  assert.equal((await submitted()).duplicate, true);
  assert.equal((await db.collection('bookingUserReports').get()).size, 1);
  assert.equal((await db.collection('notifications').get()).size, 1);
});

test('the booking report listener works before submission and continues with the created report', async () => {
  const client = env.authenticatedContext('c').firestore();
  const reference = query(collection(client, 'bookingUserReports'), where('reporterId', '==', 'c'), where('bookingId', '==', 'b'));
  assert.equal((await assertSucceeds(getDocs(reference))).empty, true);
  await assertFails(getDocs(query(collection(env.authenticatedContext('other').firestore(), 'bookingUserReports'), where('reporterId', '==', 'c'))));
  let unsubscribe;
  const received = new Promise((resolve, reject) => {
    unsubscribe = onSnapshot(reference, snapshot => {if (!snapshot.empty) resolve(snapshot.docs[0].data());}, reject);
  });
  try {
    await submitted();
    assert.equal((await received).reporterId, 'c');
  } finally {unsubscribe();}
});

test('report photos require a scoped, unexpired, unused permit and a maximum of five', async () => {
  const permit = {action: 'authorizePhoto', bookingId: 'b', permitId: 'proof', extension: 'png'};
  await assert.rejects(report(permit, auth('other')), /participants/);
  const {reportId} = await report(permit, auth('c'));
  const url = `gs://demo-neighborhelp/reportPhotos/${reportId}/c/proof.png`;
  await assert.rejects(submitted({photoUrls: [url.replace('/c/', '/p/')]}), /this report/);
  await assert.rejects(submitted({photoUrls: [url, url]}), /at most 5/);
  await db.doc('reportUploads/proof').update({expiresAt: Timestamp.fromMillis(Date.now() - 1000)});
  await assert.rejects(submitted({photoUrls: [url]}), /expired/);
  await db.doc('reportUploads/proof').update({expiresAt: Timestamp.fromMillis(Date.now() + 60000)});
  await submitted({photoUrls: [url]});
  assert.ok((await db.doc('reportUploads/proof').get()).data().usedAt);
  await assert.rejects(report({...permit, permitId: 'later'}, auth('c')), /already submitted/);
});

test('starting review assigns exactly one independent administrator without exposing private chat', async () => {
  await db.doc('inquiries/private').set({participantIds: ['c', 'p'], customerId: 'c', providerId: 'p'});
  await db.doc('inquiries/private/messages/secret').set({text: 'Private conversation'});
  const {reportId, inquiryId} = await reviewing();
  assert.deepEqual((await db.doc(`inquiries/${inquiryId}`).get()).data().participantIds, ['c', 'p', 'a']);
  assert.equal((await db.collection(`inquiries/${inquiryId}/messages`).get()).size, 1);
  assert.equal((await db.doc('inquiries/private').get()).data().participantIds.includes('a'), false);
  assert.equal((await report({action: 'startReview', reportId}, auth('a'))).duplicate, true);
  await assert.rejects(report({action: 'startReview', reportId}, auth('staff')), /another administrator/);
  await assert.rejects(inquiry({action: 'send', inquiryId, messageId: 'spy', text: 'Join'}, auth('staff')), /another account/);
  const alerts = (await db.collection('notifications').where('title', '==', 'Dispute under review').get()).docs.map(d => d.data().userId).sort();
  assert.deepEqual(alerts, ['c', 'p']);
});

test('three-party messages notify the other participants once and maintain individual read receipts', async () => {
  const {inquiryId} = await reviewing();
  for (const uid of ['c', 'p', 'a']) {
    const command = {action: 'send', inquiryId, messageId: `message-${uid}`, text: `Evidence from ${uid}`};
    await inquiry(command, auth(uid)); await inquiry(command, auth(uid));
  }
  const messages = await db.collection(`inquiries/${inquiryId}/messages`).get();
  assert.equal(messages.size, 4);
  assert.equal(messages.docs.find(d => d.id === 'message-a').data().senderRole, 'Administrator');
  assert.equal((await db.collection('notifications').where('title', '==', 'New dispute message').get()).size, 6);
  await inquiry({action: 'read', inquiryId}, auth('c'));
  const unread = (await db.doc(`inquiries/${inquiryId}`).get()).data().unreadCounts;
  assert.equal(unread.c, 0); assert.ok(unread.p > 0); assert.ok(unread.a > 0);
  await assert.rejects(inquiry({action: 'block', inquiryId}, auth('c')), /assigned administrator/);
});

test('requests for response and agreements require both confirmations before resolution; booking money stays unchanged', async () => {
  const before = (await db.doc('bookings/b').get()).data();
  const {reportId, inquiryId} = await reviewing();
  await report({action: 'setStatus', reportId, status: 'waiting_response', adminNotes: 'Please explain which rooms were completed.'}, auth('a'));
  await inquiry({action: 'send', inquiryId, messageId: 'reply', text: 'The kitchen needs correction.'}, auth('c'));
  assert.equal((await db.doc(`bookingUserReports/${reportId}`).get()).data().status, 'under_review');
  const proposal = {action: 'proposeResolution', reportId, proposalId: 'proposal-1', resolutionType: 'refund', adminNotes: 'Both parties propose a partial refund of PHP 200, payable directly.'};
  await report(proposal, auth('a'));
  assert.equal((await report(proposal, auth('a'))).duplicate, true);
  const resolve = {action: 'resolve', reportId, status: 'resolved', adminNotes: 'Reviewed both responses and recorded the agreed partial refund.'};
  await assert.rejects(report(resolve, auth('a')), /Both parties/);
  await assert.rejects(report({action: 'confirmResolution', reportId, proposalId: 'old'}, auth('c')), /no longer/);
  await assert.rejects(report({action: 'confirmResolution', reportId, proposalId: 'proposal-1'}, auth('a')), /two parties/);
  await report({action: 'confirmResolution', reportId, proposalId: 'proposal-1'}, auth('c'));
  assert.equal((await report({action: 'confirmResolution', reportId, proposalId: 'proposal-1'}, auth('c'))).duplicate, true);
  await assert.rejects(report(resolve, auth('a')), /Both parties/);
  await report({action: 'confirmResolution', reportId, proposalId: 'proposal-1'}, auth('p'));
  await report(resolve, auth('a')); await report(resolve, auth('a'));
  assert.equal((await db.doc(`bookingUserReports/${reportId}`).get()).data().status, 'resolved');
  assert.deepEqual((await db.doc('bookings/b').get()).data(), before);
  assert.equal((await db.collection('bookings/b/payments').get()).size, 0);
  await assert.rejects(inquiry({action: 'send', inquiryId, messageId: 'late', text: 'Edit the case'}, auth('p')), /closed/);
  await inquiry({action: 'read', inquiryId}, auth('p'));
});

test('replacing a proposal clears confirmations and stale confirmations are rejected', async () => {
  const {reportId} = await reviewing();
  const proposal = {action: 'proposeResolution', reportId, proposalId: 'first', resolutionType: 'correction', adminNotes: 'Clean the kitchen again at the time agreed in this case.'};
  await report(proposal, auth('a'));
  await report({action: 'confirmResolution', reportId, proposalId: 'first'}, auth('c'));
  await report({...proposal, proposalId: 'second', adminNotes: 'Clean the kitchen and bathroom at the newly agreed time.'}, auth('a'));
  await assert.rejects(report({action: 'confirmResolution', reportId, proposalId: 'first'}, auth('p')), /no longer/);
  await assert.rejects(report(proposal, auth('a')), /was replaced/);
  assert.deepEqual((await db.doc(`bookingUserReports/${reportId}`).get()).data().resolutionProposal.confirmedBy, []);
});

test('dismissal retains evidence and a recorded reason and rejects later edits', async () => {
  const {reportId} = await reviewing();
  await assert.rejects(report({action: 'resolve', reportId, status: 'dismissed', adminNotes: 'Short'}, auth('a')), /10/);
  await report({action: 'resolve', reportId, status: 'dismissed', adminNotes: 'Insufficient evidence after reviewing both parties and the agreed scope.'}, auth('a'));
  await assert.rejects(report({action: 'setStatus', reportId, status: 'under_review', adminNotes: 'Change the final decision.'}, auth('a')), /already closed/);
  assert.ok((await db.collection(`bookingUserReports/${reportId}/events`).get()).size >= 3);
});

test('rules permit participant inboxes and case evidence but deny outsiders, private chat and client mutations', async () => {
  const {reportId, inquiryId} = await reviewing();
  await db.doc('inquiries/private').set({participantIds: ['c', 'p']});
  for (const uid of ['c', 'p', 'a']) {
    const client = env.authenticatedContext(uid).firestore();
    await assertSucceeds(getDocs(query(collection(client, 'inquiries'), where('participantIds', 'array-contains', uid))));
    await assertSucceeds(getDocs(collection(client, `inquiries/${inquiryId}/messages`)));
    await assertSucceeds(getDoc(doc(client, `bookingUserReports/${reportId}`)));
    await assertFails(updateDoc(doc(client, `bookingUserReports/${reportId}`), {status: 'resolved'}));
  }
  for (const uid of ['other', 'staff']) await assertFails(getDoc(doc(env.authenticatedContext(uid).firestore(), `inquiries/${inquiryId}`)));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(), `bookingUserReports/${reportId}`)));
  await assertFails(getDoc(doc(env.authenticatedContext('a').firestore(), 'inquiries/private')));
});

test('report photo storage is private, permit-bound and immutable, with sharing only to case parties and admins', async () => {
  const {reportId, fileName} = await report({action: 'authorizePhoto', bookingId: 'b', permitId: 'storage-proof', extension: 'png'}, auth('c'));
  const path = `reportPhotos/${reportId}/c/${fileName}`;
  const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64');
  const cStorage = env.authenticatedContext('c').storage();
  const url = `gs://${ref(cStorage, path).bucket}/${path}`;
  const strictReport = require('../report_commands')({db, functions, storageBucket: ref(cStorage, path).bucket,
    verifyPhoto: async (bucket, file) => (await require('firebase-admin/storage').getStorage(app).bucket(bucket).file(file).getMetadata())[0]});
  const submission = {action: 'reportBooking', bookingId: 'b', reason: 'Incomplete work', photoUrls: [url]};
  await assert.rejects(strictReport(submission, auth('c')), /upload is incomplete/);
  await assertFails(uploadBytes(ref(cStorage, path.replace(fileName, 'unauthorized.png')), bytes, {contentType: 'image/png'}));
  await assertSucceeds(uploadBytes(ref(cStorage, path), bytes, {contentType: 'image/png'}));
  await assertFails(uploadBytes(ref(cStorage, path), bytes, {contentType: 'image/png'}));
  await assertFails(getBytes(ref(env.authenticatedContext('p').storage(), path)));
  await strictReport(submission, auth('c'));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('p').storage(), path)));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('a').storage(), path)));
  await assertFails(getBytes(ref(env.authenticatedContext('other').storage(), path)));
});

test('assigned admin commands and case messages retain optional MFA and active-admin checks', async () => {
  const {reportId, inquiryId} = await reviewing();
  await db.doc('securityPolicy/admin').set({requireMfa: true});
  await assert.rejects(inquiry({action: 'send', inquiryId, messageId: 'admin-no-mfa', text: 'Review'}, auth('a')), /Two-step/);
  await assert.rejects(report({action: 'setStatus', reportId, status: 'under_review', adminNotes: 'Continue the evidence review.'}, auth('a')), /Two-step/);
  await assertFails(getDocs(query(collection(env.authenticatedContext('a').firestore(), 'inquiries'), where('participantIds', 'array-contains', 'a'))));
  const mfa = {auth: {uid: 'a', token: {firebase: {sign_in_second_factor: 'totp'}}}};
  await inquiry({action: 'send', inquiryId, messageId: 'admin-mfa', text: 'Review'}, mfa);
  await db.doc('users/a').update({role: 'Customer'});
  await assert.rejects(inquiry({action: 'send', inquiryId, messageId: 'former-admin', text: 'Review'}, mfa), /no longer/);
  await assertFails(getDocs(collection(env.authenticatedContext('a').firestore(), `inquiries/${inquiryId}/messages`)));
});

test('case photo messages use participant-bound permits and remain readable after closure', async () => {
  const {reportId, inquiryId} = await reviewing();
  await assert.rejects(inquiry({action: 'send', inquiryId, messageId: 'foreign', mediaUrl: 'gs://demo-neighborhelp/inquiries/another/p/proof.png'}, auth('p')), /through the dispute/);
  const {fileName} = await inquiry({action: 'authorizeUpload', inquiryId, permitId: 'case-photo', extension: 'png'}, auth('p'));
  const path = `inquiries/${inquiryId}/p/${fileName}`;
  const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64');
  const storage = env.authenticatedContext('p').storage();
  await assertSucceeds(uploadBytes(ref(storage, path), bytes, {contentType: 'image/png'}));
  await inquiry({action: 'send', inquiryId, messageId: 'photo', mediaUrl: `gs://${ref(storage, path).bucket}/${path}`}, auth('p'));
  await assert.rejects(inquiry({action: 'send', inquiryId, messageId: 'reuse-photo', mediaUrl: `gs://${ref(storage, path).bucket}/${path}`}, auth('p')), /expired or is invalid/);
  await assertFails(getBytes(ref(env.authenticatedContext('other').storage(), path)));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('a').storage(), path)));
  await report({action: 'resolve', reportId, status: 'dismissed', adminNotes: 'Reviewed both responses and found insufficient supporting evidence.'}, auth('a'));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('c').storage(), path)));
  await assert.rejects(inquiry({action: 'authorizeUpload', inquiryId, permitId: 'after-close', extension: 'png'}, auth('p')), /closed/);
});

test('report photo metadata must describe an uploaded supported image within the size limit', async () => {
  const {reportId} = await report({action: 'authorizePhoto', bookingId: 'b', permitId: 'invalid-meta', extension: 'png'}, auth('c'));
  for (const metadata of [{size: 6 * 1024 * 1024, contentType: 'image/png'}, {size: 200, contentType: 'text/html'}, {size: 0, contentType: 'image/png'}]) {
    const command = require('../report_commands')({db, functions, verifyPhoto: async () => metadata});
    await assert.rejects(command({action: 'reportBooking', bookingId: 'b', reason: 'Incomplete work', photoUrls: [`gs://demo-neighborhelp/reportPhotos/${reportId}/c/invalid-meta.png`]}, auth('c')), /up to 5 MB/);
  }
});
