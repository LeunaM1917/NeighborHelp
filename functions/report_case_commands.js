'use strict';
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const crypto = require('node:crypto');
const closed = report => ['resolved', 'dismissed'].includes(report.status);
const stamp = () => FieldValue.serverTimestamp();

module.exports = ({db, functions, storageBucket = JSON.parse(process.env.FIREBASE_CONFIG || '{}').storageBucket,
  verifyPhoto = async (bucket, path) => (await require('firebase-admin/storage').getStorage().bucket(bucket).file(path).getMetadata())[0]}) => async (data, context) => {
  const fail = (code, message) => { throw new functions.https.HttpsError(code, message); };
  const uid = context.auth?.uid;
  if (!uid) fail('unauthenticated', 'Sign in required.');
  return db.runTransaction(async tx => {
    const actor = (await tx.get(db.doc(`users/${uid}`))).data();
    if (actor?.accountStatus !== 'Active') fail('permission-denied', 'An active account is required.');
    const action = String(data.action || '');
    if (['reportBooking', 'authorizePhoto'].includes(action)) {
      const bookingId = String(data.bookingId || '');
      if (!/^[\w-]{1,160}$/.test(bookingId)) fail('invalid-argument', 'Invalid booking.');
      const b = (await tx.get(db.doc(`bookings/${bookingId}`))).data();
      if (!b || ![b.customerId, b.providerId].includes(uid)) fail('permission-denied', 'Only booking participants can report the other party.');
      const other = uid === b.customerId ? b.providerId : b.customerId;
      const id = `${bookingId}_${uid}_${other}`, ref = db.doc(`bookingUserReports/${id}`);
      const existing = await tx.get(ref);
      if (action === 'authorizePhoto') {
        if (existing.exists) fail('failed-precondition', 'The report was already submitted. Share further evidence in the dispute conversation.');
        const permitId = String(data.permitId || ''), extension = String(data.extension || '');
        if (!/^[\w-]{1,100}$/.test(permitId) || !['jpg', 'jpeg', 'png', 'webp'].includes(extension)) fail('invalid-argument', 'Choose a JPG, PNG or WebP photo up to 5 MB.');
        const permitRef = db.doc(`reportUploads/${permitId}`), permit = (await tx.get(permitRef)).data();
        if (permit) {
          if (permit.userId !== uid || permit.reportId !== id || permit.extension !== extension) fail('already-exists', 'Upload reference already used.');
          if (permit.usedAt || permit.expiresAt.toMillis() <= Date.now()) fail('failed-precondition', 'Upload permission expired. Select the photo again.');
          return {reportId: id, fileName: `${permitId}.${extension}`};
        }
        const apply = await require('./rate_limits').quota(tx, db, uid, 'photo_uploads', [[3600000, 20], [86400000, 60]], fail);
        apply();
        if (!storageBucket) fail('failed-precondition', 'Report photo storage is not configured.');
        tx.create(permitRef, {userId: uid, reportId: id, extension, bucket: storageBucket, expiresAt: Timestamp.fromMillis(Date.now() + 15 * 60000), createdAt: stamp()});
        return {reportId: id, fileName: `${permitId}.${extension}`};
      }
      const reason = String(data.reason || '').trim(), details = String(data.details || '').trim();
      const photos = data.photoUrls ?? [];
      if (reason.length < 3 || reason.length > 3000 || details.length > 6000 || !Array.isArray(photos) || photos.length > 5 || new Set(photos).size !== photos.length) fail('invalid-argument', 'Provide concise report details and at most 5 optional photos.');
      if (existing.exists) return {reportId: id, duplicate: true};
      const permits = [];
      for (const url of photos) {
        if (typeof url !== 'string' || url.length > 1500) fail('invalid-argument', 'Invalid report photo.');
        const match = url.match(new RegExp(`^gs://[^/]+/reportPhotos/${id}/${uid}/([\\w-]+)\\.(jpg|jpeg|png|webp)$`));
        if (!match) fail('invalid-argument', 'Upload photos for this report only.');
        const permitRef = db.doc(`reportUploads/${match[1]}`), permit = (await tx.get(permitRef)).data();
        if (!permit || permit.userId !== uid || permit.reportId !== id || permit.extension !== match[2] || permit.usedAt || permit.expiresAt.toMillis() <= Date.now()) fail('failed-precondition', 'Report photo permission expired or is invalid. Select the photo again.');
        if (url !== `gs://${permit.bucket}/reportPhotos/${id}/${uid}/${match[1]}.${match[2]}`) fail('invalid-argument', 'Use the system report photo storage.');
        let metadata;
        try { metadata = await verifyPhoto(permit.bucket, `reportPhotos/${id}/${uid}/${match[1]}.${match[2]}`); }
        catch (_) { fail('failed-precondition', 'The photo upload is incomplete or unavailable. Upload the photo again.'); }
        if (!(Number(metadata.size) > 0 && Number(metadata.size) <= 5 * 1024 * 1024) || !['image/jpeg', 'image/png', 'image/webp'].includes(metadata.contentType)) fail('invalid-argument', 'Each report photo must be a JPG, PNG or WebP image up to 5 MB.');
        permits.push(permitRef);
      }
      const apply = await require('./rate_limits').quota(tx, db, uid, 'reports', [[86400000, 10]], fail);
      apply();
      for (const permit of permits) tx.update(permit, {usedAt: stamp()});
      tx.create(ref, {bookingId, reporterId: uid, reportedUserId: other, reporterRole: uid === b.customerId ? 'customer' : 'provider',
        reportedRole: uid === b.customerId ? 'provider' : 'customer', reason, details, photoUrls: photos, status: 'open', createdAt: stamp(), adminNotes: ''});
      tx.create(ref.collection('events').doc(), {action: 'submitted', actorId: uid, createdAt: stamp()});
      tx.create(db.collection('auditLogs').doc(), {actorId: uid, actorRole: actor.role, action: 'booking.report', collection: 'bookingUserReports', referenceId: id, createdAt: stamp()});
      tx.create(db.collection('notifications').doc(), {userId: uid, title: 'Report submitted', message: 'Your report is awaiting administrator review. Photos are supporting evidence, not an automatic finding of fault.', relatedBookingId: bookingId, relatedReportId: id, notificationType: 'Report Update', isRead: false, createdAt: stamp()});
      return {reportId: id};
    }

    const id = String(data.reportId || '');
    if (!/^[\w-]{1,500}$/.test(id)) fail('invalid-argument', 'Invalid report reference.');
    const ref = db.doc(`bookingUserReports/${id}`), report = (await tx.get(ref)).data();
    if (!report) fail('not-found', 'Report not found.');
    const parties = [report.reporterId, report.reportedUserId];
    if (action === 'confirmResolution') {
      if (!parties.includes(uid)) fail('permission-denied', 'Only the two parties can confirm a proposed resolution.');
      const proposal = report.resolutionProposal;
      if (closed(report) || !proposal || proposal.id !== data.proposalId) fail('failed-precondition', 'This proposal is no longer awaiting confirmation.');
      if ((proposal.confirmedBy || []).includes(uid)) return {reportId: id, duplicate: true};
      const disputeRef = db.doc(`inquiries/${report.disputeInquiryId}`), dispute = (await tx.get(disputeRef)).data();
      if (!dispute || dispute.reportId !== id) fail('failed-precondition', 'The dispute conversation is unavailable.');
      const confirmedBy = [...(proposal.confirmedBy || []), uid];
      tx.update(ref, {resolutionProposal: {...proposal, confirmedBy}, updatedAt: stamp(), updatedBy: uid});
      const confirmation = `${actor.fullName || 'A party'} confirmed the proposed ${proposal.type} resolution.`;
      tx.create(disputeRef.collection('messages').doc(), {senderId: uid, senderName: actor.fullName || (uid === dispute.customerId ? 'Customer' : 'Provider'),
        senderRole: uid === dispute.customerId ? 'Customer' : 'Provider', text: confirmation, sentAt: stamp()});
      tx.update(disputeRef, {lastMessage: confirmation, updatedAt: stamp(), unreadCounts: Object.fromEntries(dispute.participantIds.map(p => [p, (dispute.unreadCounts?.[p] || 0) + (p === uid ? 0 : 1)]))});
      tx.create(ref.collection('events').doc(), {action: 'resolution.confirmed', actorId: uid, proposalId: proposal.id, createdAt: stamp()});
      notify(tx, db, report, id, [report.assignedAdminId, ...parties.filter(p => p !== uid)], 'Resolution confirmation', 'A party confirmed the proposed resolution. Both parties must confirm any agreement; the administrator records the final outcome.');
      return {reportId: id, confirmedBy};
    }
    if (actor.role !== 'Administrator') fail('permission-denied', 'Administrator access required.');
    await require('./admin_security').assertAdminToken(context, fail, db, tx);
    if (report.assignedAdminId && report.assignedAdminId !== uid) fail('permission-denied', 'This case is assigned to another administrator.');
    const threadId = report.disputeInquiryId || crypto.createHash('sha256').update(`dispute:${id}`).digest('hex');
    const threadRef = db.doc(`inquiries/${threadId}`);
    const thread = (await tx.get(threadRef)).data();
    if (action === 'startReview') {
      if (closed(report)) fail('failed-precondition', 'This report is already closed.');
      if (thread && report.assignedAdminId === uid) return {reportId: id, inquiryId: threadId, duplicate: true};
      let customerId = report.reporterRole === 'customer' ? report.reporterId : report.reportedUserId;
      let providerId = report.reporterRole === 'provider' ? report.reporterId : report.reportedUserId;
      const booking = report.bookingId ? (await tx.get(db.doc(`bookings/${report.bookingId}`))).data() : null;
      if (booking) {
        if (!parties.includes(booking.customerId) || !parties.includes(booking.providerId)) fail('failed-precondition', 'The report does not match the booking participants.');
        customerId = booking.customerId; providerId = booking.providerId;
      }
      if (!customerId || !providerId || customerId === providerId || parties.includes(uid)) fail('failed-precondition', 'The case needs two distinct parties and an independent administrator.');
      const customer = (await tx.get(db.doc(`users/${customerId}`))).data();
      const provider = (await tx.get(db.doc(`users/${providerId}`))).data();
      if (!customer || !provider) fail('failed-precondition', 'One of the case participants is missing.');
      tx.create(threadRef, {kind: 'dispute', reportId: id, bookingId: report.bookingId || '', customerId, providerId,
        assignedAdminId: uid, participantIds: [customerId, providerId, uid], customerName: customer.fullName || 'Customer', providerName: provider.fullName || 'Provider',
        adminName: actor.fullName || 'System Administrator', serviceId: '', serviceTitle: 'Dispute case', caseStatus: 'under_review',
        blockedBy: [], unreadCounts: {[customerId]: 1, [providerId]: 1, [uid]: 0}, lastMessage: 'An administrator opened this dispute for review.', createdAt: stamp(), updatedAt: stamp()});
      tx.create(threadRef.collection('messages').doc('case_opened'), {senderId: uid, senderName: actor.fullName || 'System Administrator', senderRole: 'Administrator', text:
        `This case is under review. Both parties may respond and submit relevant evidence here.\n\nReported concern: ${report.reason}\n${report.details || ''}\n\nA report is not proof of fault. The administrator will review both responses. Any correction or refund agreement needs confirmation from both parties.`, sentAt: stamp()});
      tx.update(ref, {assignedAdminId: uid, disputeInquiryId: threadId, status: 'under_review', updatedAt: stamp(), updatedBy: uid});
      tx.create(ref.collection('events').doc(), {action: 'review.started', actorId: uid, status: 'under_review', createdAt: stamp()});
      notify(tx, db, {...report, disputeInquiryId: threadId}, id, parties, 'Dispute under review', 'An administrator opened a shared dispute conversation. Open Messages to respond and submit relevant evidence.');
      return {reportId: id, inquiryId: threadId};
    }
    if (!report.assignedAdminId || !thread) fail('failed-precondition', 'Start the review and contact both parties first.');
    if (closed(report)) {
      if (action === 'resolve' && report.status === data.status && report.adminNotes === String(data.adminNotes || '').trim()) return {reportId: id, duplicate: true};
      fail('failed-precondition', 'This case is already closed.');
    }
    const notes = String(data.adminNotes || '').trim();
    if (notes.length < 10 || notes.length > 3000) fail('invalid-argument', 'Explain the evidence, decision or requested response in 10–3000 characters.');
    let status, message;
    if (action === 'setStatus') {
      status = String(data.status || '');
      if (!['under_review', 'waiting_response'].includes(status)) fail('invalid-argument', 'Choose Under review or Waiting for response.');
      if (report.status === status && report.lastAdminRequest === notes) return {reportId: id, duplicate: true};
      tx.update(ref, {lastAdminRequest: notes});
      message = `Case ${status.replaceAll('_', ' ')}: ${notes}`;
    } else if (action === 'proposeResolution') {
      const proposalId = String(data.proposalId || ''), type = String(data.resolutionType || '');
      if (!/^[\w-]{1,100}$/.test(proposalId) || !['correction', 'refund', 'other'].includes(type)) fail('invalid-argument', 'Choose a resolution type and valid proposal reference.');
      if (report.resolutionProposal?.id === proposalId) {
        if (report.resolutionProposal.summary !== notes || report.resolutionProposal.type !== type) fail('already-exists', 'Proposal reference already used.');
        return {reportId: id, duplicate: true};
      }
      const proposalRef = ref.collection('proposals').doc(proposalId);
      if ((await tx.get(proposalRef)).exists) fail('failed-precondition', 'This proposal was replaced. Review the current terms.');
      tx.create(proposalRef, {type, summary: notes, proposedBy: uid, proposedAt: stamp()});
      tx.update(ref, {resolutionProposal: {id: proposalId, type, summary: notes, proposedBy: uid, proposedAt: Timestamp.now(), confirmedBy: []}});
      status = 'waiting_response';
      message = `Proposed ${type} resolution: ${notes}\nBoth parties must explicitly confirm this proposal. This records an agreement only; it does not transfer money, change the booking schedule or mark work completed.`;
    } else if (action === 'resolve') {
      status = String(data.status || '');
      if (!['resolved', 'dismissed'].includes(status)) fail('invalid-argument', 'Choose Resolved or Dismissed.');
      if (status === 'resolved' && report.resolutionProposal && !parties.every(p => (report.resolutionProposal.confirmedBy || []).includes(p))) fail('failed-precondition', 'Both parties must confirm the proposed correction or financial agreement before resolving this case.');
      tx.update(ref, {adminNotes: notes, resolvedAt: stamp()});
      message = `Case ${status}. Recorded evidence and outcome: ${notes}\nThis administrative record does not transfer money or automatically mark work completed.`;
    } else fail('invalid-argument', 'Unsupported reporting action.');
    tx.update(ref, {status, updatedAt: stamp(), updatedBy: uid});
    tx.update(threadRef, {caseStatus: status, lastMessage: message.slice(0, 150), updatedAt: stamp(),
      unreadCounts: Object.fromEntries(thread.participantIds.map(p => [p, (thread.unreadCounts?.[p] || 0) + (p === uid ? 0 : 1)]))});
    tx.create(threadRef.collection('messages').doc(), {senderId: uid, senderName: actor.fullName || 'System Administrator', senderRole: 'Administrator', text: message, sentAt: stamp()});
    tx.create(ref.collection('events').doc(), {action, status, notes, actorId: uid, createdAt: stamp()});
    tx.create(db.collection('auditLogs').doc(), {actorId: uid, actorRole: actor.role, action: `report.${action}`, collection: 'bookingUserReports', referenceId: id, createdAt: stamp()});
    notify(tx, db, report, id, parties, `Dispute ${status.replaceAll('_', ' ')}`, message);
    return {reportId: id, inquiryId: threadId};
  });
};

function notify(tx, db, report, id, users, title, message) {
  for (const userId of new Set(users.filter(Boolean))) tx.create(db.collection('notifications').doc(), {
    userId, title, message: message.length > 400 ? `${message.slice(0, 397)}...` : message, relatedBookingId: report.bookingId || '', relatedInquiryId: report.disputeInquiryId || '', relatedReportId: id,
    notificationType: 'Report Update', isRead: false, createdAt: stamp(),
  });
}
