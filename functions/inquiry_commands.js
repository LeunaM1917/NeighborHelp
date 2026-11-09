'use strict';
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const crypto = require('node:crypto');
const {hasMatchingCertificate} = require('./domain');
const {quota}=require('./rate_limits');
module.exports = ({db, functions}) => async (data, context) => {
  const fail = (code, message) => {throw new functions.https.HttpsError(code, message);};
  const uid = context.auth?.uid;
  if (!uid) fail('unauthenticated', 'Sign in required.');
  const user = (await db.doc(`users/${uid}`).get()).data();
  if (user?.accountStatus !== 'Active') fail('permission-denied', 'An active account is required.');
  if(data.action==='bookingThread')return require('./chat_migration')({db,functions}).migrate(String(data.bookingId||''),uid);
  if(data.action==='syncBookings')return require('./chat_migration')({db,functions}).sync(data,uid,user.role);
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
      const currentUser=(await tx.get(db.doc(`users/${uid}`))).data();
      if(currentUser?.accountStatus!=='Active' || currentUser.role!=='Customer') fail('permission-denied','An active customer account is required.');
      if (!(await tx.get(ref)).exists) {
        const apply=await quota(tx,db,uid,'new_inquiries',[[86400000,30]],fail);
        apply();
        tx.create(ref, {customerId:uid,providerId:s.providerId,participantIds:[uid,s.providerId],
        customerName:user.fullName || 'Customer',providerName:owner.fullName || 'Provider',serviceId,serviceTitle:s.serviceTitle,
        customerMessageCount:0,providerMessageCount:0,customerUnreadCount:0,providerUnreadCount:0,blockedBy:[],lastMessage:'Discuss your requirements before sending an offer.',createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
      }
    });
    return {inquiryId:id};
  }
  const id = String(data.inquiryId || '');
  if (!/^[a-f0-9]{64}$/.test(id)) fail('invalid-argument', 'Invalid conversation.');
  const ref = db.doc(`inquiries/${id}`);
  return db.runTransaction(async tx => {
    const currentUser=(await tx.get(db.doc(`users/${uid}`))).data();
    if(currentUser?.accountStatus!=='Active') fail('permission-denied','An active account is required.');
    const snap = await tx.get(ref), thread = snap.data();
    if (!thread || !thread.participantIds.includes(uid)) fail('permission-denied','This conversation belongs to another account.');
    if(data.action === 'read') {
      const field=uid === thread.customerId ? 'customerUnreadCount' : 'providerUnreadCount';
      if(thread[field]) tx.update(ref,{[field]:0});
      return {read:true};
    }
    const other = uid === thread.customerId ? thread.providerId : thread.customerId;
    if(data.action==='block' || data.action==='unblock') {
      tx.update(ref,{blockedBy:data.action==='block'?FieldValue.arrayUnion(uid):FieldValue.arrayRemove(uid),updatedAt:FieldValue.serverTimestamp()});
      return {blocked:data.action==='block'};
    }
    if(data.action==='report') {
      const reportId=String(data.reportId || ''),reason=String(data.reason || '').trim();
      if(!/^[\w-]{1,100}$/.test(reportId)||reason.length<10 || reason.length>3000) fail('invalid-argument','Explain the concern in 10–3000 characters.');
      const reportRef=db.doc(`bookingUserReports/${reportId}`);
      const existing=await tx.get(reportRef);
      if(existing.exists) {if(existing.data().reporterId===uid && existing.data().inquiryId===id) return {reportId,duplicate:true}; fail('already-exists','Report reference already used.');}
      const evidence=await tx.get(ref.collection('messages').orderBy('sentAt','desc').limit(10));
      const apply=await quota(tx,db,uid,'reports',[[86400000,10]],fail);
      apply();
      tx.create(reportRef,{bookingId:'',inquiryId:id,reporterId:uid,reporterRole:uid===thread.customerId?'customer':'provider',reportedUserId:other,reportedRole:uid===thread.customerId?'provider':'customer',reason,
        details:'Inquiry report. The reporter shared the most recent 10 messages as evidence.',evidence:evidence.docs.map(d=>({id:d.id,...d.data()})),status:'open',createdAt:FieldValue.serverTimestamp(),adminNotes:''});
      tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:user.role,action:'inquiry.report',collection:'bookingUserReports',referenceId:reportId,createdAt:FieldValue.serverTimestamp()});
      return {reportId};
    }
    if((thread.blockedBy || []).length) fail('failed-precondition','Messaging is blocked in this conversation. History and reporting remain available.');
    if ((await tx.get(db.doc(`users/${other}`))).data()?.accountStatus !== 'Active') fail('failed-precondition','The other account is unavailable.');
    if(data.action==='authorizeUpload') {
      const permitId=String(data.permitId || ''),extension=String(data.extension || '');
      if(!/^[\w-]{1,100}$/.test(permitId)||!['jpg','jpeg','png','webp'].includes(extension)) fail('invalid-argument','Invalid image upload.');
      const permitRef=db.doc(`inquiryUploads/${permitId}`),existing=(await tx.get(permitRef)).data();
      if(existing) {
        if(existing.senderId!==uid || existing.inquiryId!==id || existing.extension!==extension) fail('already-exists','Upload reference already used.');
        if(existing.expiresAt.toMillis()<=Date.now() || existing.usedAt) fail('failed-precondition','This upload permission expired. Retry the photo.');
        return {fileName:`${permitId}.${extension}`};
      }
      const apply=await quota(tx,db,uid,'photo_uploads',[[3600000,20],[86400000,60]],fail);
      const expiresAt=Timestamp.fromMillis(Date.now()+15*60000);
      apply();tx.create(permitRef,{senderId:uid,inquiryId:id,extension,expiresAt,createdAt:FieldValue.serverTimestamp()});
      tx.update(ref,{[`uploadPermits.${uid}`]:{permitId,extension,expiresAt,used:false}});
      return {fileName:`${permitId}.${extension}`};
    }
    if (data.action !== 'send') fail('invalid-argument','Unsupported inquiry action.');
    const text = String(data.text || '').trim(), media = String(data.mediaUrl || '');
    if(media.length>1500) fail('invalid-argument','Invalid image reference. Upload the photo through this conversation.');
    if ((!text && !media) || text.length > 6000) fail('invalid-argument','Enter a message up to 6000 characters.');
    if (media && !new RegExp(`^gs://[^/]+/inquiries/${id}/${uid}/[\\w.-]+$`).test(media)) fail('invalid-argument','Upload a photo to this conversation first.');
    const messageId = String(data.messageId || '');
    if (!/^[\w-]{1,160}$/.test(messageId)) fail('invalid-argument','Invalid message identifier.');
    const messageRef = ref.collection('messages').doc(messageId);
    if ((await tx.get(messageRef)).exists) return {messageId,duplicate:true};
    let uploadRef;
    if(media) {
      const file=media.split('/').pop(),permitId=file.substring(0,file.lastIndexOf('.'));
      if(!/^[\w-]{1,100}$/.test(permitId)) fail('invalid-argument','Invalid image permission reference.');
      uploadRef=db.doc(`inquiryUploads/${permitId}`);
      const permit=(await tx.get(uploadRef)).data();
      if(!permit || permit.senderId!==uid || permit.inquiryId!==id || `${permitId}.${permit.extension}`!==file || permit.usedAt || permit.expiresAt.toMillis()<=Date.now()) fail('failed-precondition','Upload permission is invalid or expired. Select the photo again.');
    }
    const apply=await quota(tx,db,uid,'messages',[[60000,30],[86400000,500]],fail);
    apply(); if(uploadRef) {
      tx.update(uploadRef,{usedAt:FieldValue.serverTimestamp(),messageId});
      tx.update(ref,{[`uploadPermits.${uid}.used`]:true});
    }
    tx.create(messageRef,{senderId:uid,receiverId:other,text,mediaUrl:media,sentAt:FieldValue.serverTimestamp()});
    tx.update(ref,{[uid === thread.customerId ? 'customerMessageCount' : 'providerMessageCount']:FieldValue.increment(text ? 1 : 0),
      [uid === thread.customerId ? 'providerUnreadCount' : 'customerUnreadCount']:FieldValue.increment(1),
      lastMessage:text.slice(0,150) || 'Photo',updatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('notifications').doc(`inquiry_${id}_${messageId}`),{userId:other,title:'New inquiry message',message:text.slice(0,150) || 'Photo',
      relatedInquiryId:id,notificationType:'Inquiry',isRead:false,createdAt:Timestamp.now()});
    return {messageId};
  });
};
