'use strict';

const statusOf = value => ({pending: 'Pending', approved: 'Approved', rejected: 'Rejected'})[
  String(value || '').trim().toLowerCase()
] || null;
const text = value => typeof value === 'string' ? value.trim() : '';
const detail = value => text(value).slice(0, 500);
const identityStarted = data => Boolean(text(data.diditSessionId) || text(data.diditStatus) || text(data.verificationProvider));
const identityStatus = data => data.isVerified === true ? 'Approved' : statusOf(data.verificationStatus);

// Describe changes from the event snapshots, not a later read of the profile:
// concurrent reviews must retain their own result and stable notification key.
module.exports = function reviewStatusNotifications({collection, id, before = {}, after = {}, ownerId}) {
  const userId = ownerId || after.userId || id;
  const notices = [];
  const add = (subject, subjectId, status, title, message, extra = {}) => notices.push({
    key: `${subject}:${subjectId}`,
    data: {userId, title, message, reviewStatus: status, ...extra},
  });

  if (collection === 'users' || collection === 'serviceProviders') {
    const previous = identityStatus(before), status = identityStatus(after);
    const newSession = identityStarted(after) && (!identityStarted(before)
      || (text(after.diditSessionId) && after.diditSessionId !== before.diditSessionId));
    if (status && (status !== previous || (status === 'Pending' && newSession))
      && (status !== 'Pending' || identityStarted(after))) {
      const message = status === 'Pending'
        ? 'Your identity verification is pending. Complete any required verification steps and wait for the result.'
        : status === 'Approved'
          ? 'Your identity verification has been approved.'
          : 'Your identity verification has been rejected. Open your profile to review the result and any next steps.';
      add('identity', id, status, `Identity verification ${status.toLowerCase()}`, message,
        {notificationType: 'Verification'});
    }
  }

  if (collection === 'services') {
    const status = statusOf(after.approvalStatus);
    // Drafts, edits to an already reviewed listing, and deletion are not reviews.
    if (status && status !== statusOf(before.approvalStatus)) {
      const name = text(after.serviceTitle) || 'Your service';
      const suffix = status === 'Pending' ? ' It is awaiting review.'
        : status === 'Rejected' ? ' Open your service to review it before resubmitting.' : '';
      const reason = status === 'Rejected' ? detail(after.rejectionReason) : '';
      add('service', id, status, `Service ${status.toLowerCase()}`,
        `${name}: ${status}.${suffix}${reason ? ` Reason: ${reason}` : ''}`,
        {notificationType: 'Service Review', relatedServiceId: id});
    }
  }

  if (collection === 'serviceProviders') {
    const previous = new Map((before.certificationHistory || []).filter(c => c?.id).map(c => [c.id, c]));
    const seen = new Set();
    for (const cert of after.certificationHistory || []) {
      if (!cert?.id || seen.has(cert.id)) continue;
      seen.add(cert.id);
      const prior = previous.get(cert.id);
      const status = statusOf(cert.status) || 'Pending';
      // A review can deliberately keep a pending certificate on hold. Notify
      // about the recorded notes, but not array reordering or unrelated edits.
      const pendingReview = status === 'Pending' && cert.reviewedAt
        && (JSON.stringify(cert.reviewedAt) !== JSON.stringify(prior?.reviewedAt)
          || text(cert.verificationNotes) !== text(prior?.verificationNotes));
      if (prior && status === (statusOf(prior.status) || 'Pending') && !pendingReview) continue;
      const name = text(cert.name) || 'Your certificate';
      const explanation = status === 'Approved' ? 'The administrator approved your certificate.'
        : status === 'Rejected' ? 'Open your profile to review the result before resubmitting.'
          : 'It is awaiting certificate verification by the administrator.';
      const notes = status === 'Rejected' ? detail(cert.rejectionReason) || detail(cert.verificationNotes)
        : status === 'Pending' ? detail(cert.verificationNotes) : '';
      add('certificate', cert.id, status, `Certificate ${status.toLowerCase()}`,
        `${name}: ${status}. ${explanation}${notes ? ` Review notes: ${notes}` : ''}`,
        {notificationType: 'Certificate Review', relatedCertificationId: cert.id, relatedProviderId: id});
    }
  }
  return notices;
};
