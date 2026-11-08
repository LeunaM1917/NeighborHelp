'use strict';
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const crypto = require('node:crypto');
const {hasMatchingCertificate} = require('./domain');
module.exports = ({db, functions}) => async (data, context) => {
  const fail = (code, message) => {throw new functions.https.HttpsError(code, message);};
  const uid = context.auth?.uid;
  if (!uid) fail('unauthenticated', 'Sign in required.');
  const user = (await db.doc(`users/${uid}`).get()).data();
  if (user?.accountStatus !== 'Active') fail('permission-denied', 'An active account is required.');
  if (data.action === 'template') return {version: require('./agreements').VERSION, text: require('./agreements').TERMS};
  if (data.action === 'open') {
    if (user.role !== 'Customer') fail('permission-denied', 'Only customers can open inquiries.');
    const serviceId = String(data.serviceId || '');
    if (!/^[\w-]{1,160}$/.test(serviceId)) fail('invalid-argument', 'Invalid service.');
    const s = (await db.doc(`services/${serviceId}`).get()).data();
    if (!s?.isActive || s.approvalStatus !== 'Approved' || s.archivedAt) fail('failed-precondition', 'Service unavailable.');
    const p = (await db.doc(`serviceProviders/${s.providerId}`).get()).data();
    const owner = (await db.doc(`users/${s.providerId}`).get()).data();
    if (!p?.isVerified || owner?.accountStatus !== 'Active' || !hasMatchingCertificate(p,s.category,s.serviceTitle)) fail('failed-precondition', 'The provider needs a verified matching TESDA certificate.');
    const id = crypto.createHash('sha256').update(JSON.stringify([uid,s.providerId])).digest('hex');
    const ref = db.doc(`inquiries/${id}`);
    await db.runTransaction(async tx => {
      if (!(await tx.get(ref)).exists) tx.create(ref, {customerId:uid,providerId:s.providerId,participantIds:[uid,s.providerId],
        customerName:user.fullName || 'Customer',providerName:owner.fullName || 'Provider',serviceId,serviceTitle:s.serviceTitle,
        customerMessageCount:0,providerMessageCount:0,customerUnreadCount:0,providerUnreadCount:0,lastMessage:'Discuss your requirements before sending an offer.',createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    });
    return {inquiryId:id};
  }
  const id = String(data.inquiryId || '');
  if (!/^[a-f0-9]{64}$/.test(id)) fail('invalid-argument', 'Invalid conversation.');
  const ref = db.doc(`inquiries/${id}`);
  return db.runTransaction(async tx => {
    const snap = await tx.get(ref), thread = snap.data();
    if (!thread || !thread.participantIds.includes(uid)) fail('permission-denied','This conversation belongs to another account.');
    if(data.action === 'read') {
      const field=uid === thread.customerId ? 'customerUnreadCount' : 'providerUnreadCount';
      if(thread[field]) tx.update(ref,{[field]:0});
      return {read:true};
    }
    const other = uid === thread.customerId ? thread.providerId : thread.customerId;
    if ((await tx.get(db.doc(`users/${other}`))).data()?.accountStatus !== 'Active') fail('failed-precondition','The other account is unavailable.');
    if (data.action !== 'send') fail('invalid-argument','Unsupported inquiry action.');
    const text = String(data.text || '').trim(), media = String(data.mediaUrl || '');
    if ((!text && !media) || text.length > 6000) fail('invalid-argument','Enter a message up to 6000 characters.');
    if (media && !new RegExp(`^gs://[^/]+/inquiries/${id}/${uid}/[\\w.-]+$`).test(media)) fail('invalid-argument','Upload a photo to this conversation first.');
    const messageId = String(data.messageId || '');
    if (!/^[\w-]{1,160}$/.test(messageId)) fail('invalid-argument','Invalid message identifier.');
    const messageRef = ref.collection('messages').doc(messageId);
    if ((await tx.get(messageRef)).exists) return {messageId,duplicate:true};
    tx.create(messageRef,{senderId:uid,receiverId:other,text,mediaUrl:media,sentAt:FieldValue.serverTimestamp()});
    tx.update(ref,{[uid === thread.customerId ? 'customerMessageCount' : 'providerMessageCount']:FieldValue.increment(text ? 1 : 0),
      [uid === thread.customerId ? 'providerUnreadCount' : 'customerUnreadCount']:FieldValue.increment(1),
      lastMessage:text.slice(0,150) || 'Photo',updatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('notifications').doc(`inquiry_${id}_${messageId}`),{userId:other,title:'New inquiry message',message:text.slice(0,150) || 'Photo',
      relatedInquiryId:id,notificationType:'Inquiry',isRead:false,createdAt:Timestamp.now()});
    return {messageId};
  });
};
