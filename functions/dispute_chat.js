'use strict';
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
module.exports = async ({db, tx, ref, thread, uid, user, data, context, fail}) => {
  if (uid === thread.assignedAdminId) {
    if (user.role !== 'Administrator') fail('permission-denied', 'Administrator access is no longer available.');
    await require('./admin_security').assertAdminToken(context, fail, db, tx);
  }
  const report = (await tx.get(db.doc(`bookingUserReports/${thread.reportId}`))).data();
  if (!report || report.disputeInquiryId !== ref.id || report.assignedAdminId !== thread.assignedAdminId) fail('permission-denied', 'This dispute conversation is unavailable.');
  const unread = {...(thread.unreadCounts || {})};
  if (data.action === 'read') {
    if (unread[uid]) tx.update(ref, {unreadCounts: {...unread, [uid]: 0}});
    return {read: true};
  }
  if (['resolved', 'dismissed'].includes(report.status)) fail('failed-precondition', 'This dispute is closed. Its messages and evidence remain available.');
  if (!['send', 'authorizeUpload'].includes(data.action)) fail('invalid-argument', 'Use the assigned administrator to manage this dispute.');
  const stamp = () => FieldValue.serverTimestamp();
  if (data.action === 'authorizeUpload') {
    const permitId = String(data.permitId || ''), extension = String(data.extension || '');
    if (!/^[\w-]{1,100}$/.test(permitId) || !['jpg', 'jpeg', 'png', 'webp'].includes(extension)) fail('invalid-argument', 'Invalid image upload.');
    const permitRef = db.doc(`inquiryUploads/${permitId}`), existing = (await tx.get(permitRef)).data();
    if (existing) {
      if (existing.senderId !== uid || existing.inquiryId !== ref.id || existing.extension !== extension) fail('already-exists', 'Upload reference already used.');
      if (existing.usedAt || existing.expiresAt.toMillis() <= Date.now()) fail('failed-precondition', 'Photo permission expired. Select the photo again.');
      return {fileName: `${permitId}.${extension}`};
    }
    const apply = await require('./rate_limits').quota(tx, db, uid, 'photo_uploads', [[3600000, 20], [86400000, 60]], fail);
    const expiresAt = Timestamp.fromMillis(Date.now() + 15 * 60000);
    apply();
    tx.create(permitRef, {senderId: uid, inquiryId: ref.id, extension, expiresAt, createdAt: stamp()});
    tx.update(ref, {[`uploadPermits.${uid}`]: {permitId, extension, expiresAt, used: false}});
    return {fileName: `${permitId}.${extension}`};
  }
  const text = String(data.text || '').trim(), mediaUrl = String(data.mediaUrl || ''), messageId = String(data.messageId || '');
  if (!/^[\w-]{1,160}$/.test(messageId) || (!text && !mediaUrl) || text.length > 6000 || mediaUrl.length > 1500) fail('invalid-argument', 'Enter a message up to 6000 characters or an uploaded photo.');
  const messageRef = ref.collection('messages').doc(messageId);
  if ((await tx.get(messageRef)).exists) return {messageId, duplicate: true};
  let permitRef;
  if (mediaUrl) {
    const match = mediaUrl.match(new RegExp(`^gs://[^/]+/inquiries/${ref.id}/${uid}/([\\w-]+)\\.(jpg|jpeg|png|webp)$`));
    if (!match) fail('invalid-argument', 'Upload this photo through the dispute conversation.');
    permitRef = db.doc(`inquiryUploads/${match[1]}`);
    const permit = (await tx.get(permitRef)).data();
    if (!permit || permit.senderId !== uid || permit.inquiryId !== ref.id || permit.extension !== match[2] || permit.usedAt || permit.expiresAt.toMillis() <= Date.now()) fail('failed-precondition', 'Photo permission expired or is invalid. Select the photo again.');
  }
  const apply = await require('./rate_limits').quota(tx, db, uid, 'messages', [[60000, 30], [86400000, 500]], fail);
  const recipients = thread.participantIds.filter(id => id !== uid);
  for (const id of recipients) unread[id] = (unread[id] || 0) + 1;
  apply();
  if (permitRef) {
    tx.update(permitRef, {usedAt: stamp(), messageId});
    tx.update(ref, {[`uploadPermits.${uid}.used`]: true});
  }
  tx.create(messageRef, {senderId: uid, senderName: user.fullName || (uid === thread.assignedAdminId ? 'System Administrator' : uid === thread.customerId ? 'Customer' : 'Provider'),
    senderRole: uid === thread.assignedAdminId ? 'Administrator' : uid === thread.customerId ? 'Customer' : 'Provider', text, mediaUrl, sentAt: stamp()});
  tx.update(ref, {unreadCounts: unread, lastMessage: text.slice(0, 150) || 'Photo evidence', updatedAt: stamp()});
  if (uid !== thread.assignedAdminId && report.status === 'waiting_response' && !report.resolutionProposal) {
    tx.update(db.doc(`bookingUserReports/${thread.reportId}`), {status: 'under_review', updatedAt: stamp()});
    tx.update(ref, {caseStatus: 'under_review'});
  }
  for (const userId of recipients) tx.create(db.collection('notifications').doc(`dispute_${ref.id}_${messageId}_${userId}`), {
    userId, title: 'New dispute message', message: text.slice(0, 150) || 'New photo evidence', relatedInquiryId: ref.id, relatedReportId: thread.reportId,
    notificationType: 'Report Update', isRead: false, createdAt: stamp(),
  });
  return {messageId};
};
