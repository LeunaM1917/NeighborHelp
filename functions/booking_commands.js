'use strict';
const { FieldValue, Timestamp, GeoPoint } = require('firebase-admin/firestore');

const { active, complete, windowFor, overlaps, validWindow, hasMatchingCertificate, distanceKm } = require('./domain');
const {validateOffer, makeAgreement} = require('./agreements');

module.exports = function bookingCommands({ db, admin, functions }) {
  const fail = (code, message) => { throw new functions.https.HttpsError(code, message); };
  const stamp = () => FieldValue.serverTimestamp();
  const timestamp = ms => Timestamp.fromMillis(ms);
  const point = p => {
    if (!p || !Number.isFinite(p.latitude) || !Number.isFinite(p.longitude) || Math.abs(p.latitude) > 90 || Math.abs(p.longitude) > 180 || (p.latitude === 0 && p.longitude === 0)) fail('invalid-argument', 'Select a valid service location on the map.');
    return new GeoPoint(p.latitude, p.longitude);
  };
  return async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) fail('unauthenticated', 'Sign in required.');
    const action = String(data?.action || '');
    const id = String(data?.bookingId || '');
    if (!/^[A-Za-z0-9_-]{1,160}$/.test(id)) fail('invalid-argument', 'Invalid booking identifier.');
    const ref = db.collection('bookings').doc(id);
    const auditRef = db.collection('auditLogs').doc();
    return db.runTransaction(async tx => {
      const actorSnap = await tx.get(db.collection('users').doc(uid));
      const actor = actorSnap.data() || {};
      if (!actorSnap.exists || actor.accountStatus !== 'Active') fail('permission-denied', 'An active account is required.');
      const isAdmin = actor.role === 'Administrator';
      const snap = await tx.get(ref);
      const b = snap.data();
      let patch;
      let providerId;
      let newWindow;
      if (action === 'create' || action === 'preview') {
        if (snap.exists) {
          if (b.customerId === uid) return { bookingId: id, duplicate: true };
          fail('already-exists', 'Booking already exists.');
        }
        if (actor.role !== 'Customer') fail('permission-denied', 'Only customers can request services.');
        const serviceSnap = await tx.get(db.collection('services').doc(String(data.serviceId || '')));
        const service = serviceSnap.data();
        if (!service || !service.isActive || service.approvalStatus !== 'Approved' || service.archivedAt) fail('failed-precondition', 'This service is unavailable.');
        providerId = service.providerId;
        const profile = (await tx.get(db.collection('serviceProviders').doc(providerId))).data();
        const provider = (await tx.get(db.collection('users').doc(providerId))).data();
        if (!profile?.isVerified || provider?.accountStatus !== 'Active') fail('failed-precondition', 'This provider is not currently eligible for bookings.');
        if (!hasMatchingCertificate(profile, service.category, service.serviceTitle)) fail('failed-precondition', 'The provider needs a valid certificate for this service.');
        const location = point(data.location);
        if (!profile.location || distanceKm(profile.location, location) > (profile.serviceRadiusKm || 5)) fail('failed-precondition', 'The address is outside this provider’s service coverage.');
        const offer = validateOffer(data, fail);
        const inquiryId = String(data.inquiryId || '');
        if (!/^[a-f0-9]{64}$/.test(inquiryId)) fail('failed-precondition', 'Message the provider and discuss the requirements before sending an offer.');
        const inquiry = (await tx.get(db.collection('inquiries').doc(inquiryId))).data();
        if (inquiry?.customerId !== uid || inquiry?.providerId !== providerId || !(inquiry.customerMessageCount > 0 && inquiry.providerMessageCount > 0)) fail('failed-precondition', 'Both parties must discuss the work in this conversation before an offer.');
        const start = Number(data.scheduledDate), end = start + (offer.numberOfDays - 1) * 86400000 + offer.hoursPerDay * 3600000;
        if (!Number.isFinite(start) || start <= Date.now() || start > Date.now() + 180 * 86400000) fail('invalid-argument', 'Choose a future start within 180 days.');
        const address = String(data.serviceLocation || '').trim();
        if (address.length < 5 || address.length > 500) fail('invalid-argument', 'Enter the complete service address.');
        const hours = offer.hoursPerDay * offer.numberOfDays;
        const agreement = makeAgreement({id,offer,customer:{id:uid,fullName:actor.fullName || 'Customer'},provider:{id:providerId,fullName:provider.fullName || 'Provider'},service:service.serviceTitle,address,start,end});
        patch = { customerId: uid, providerId, serviceId: serviceSnap.id, serviceLocation: address, location,
          scheduledDate: timestamp(start), scheduledEndDate: timestamp(end), durationHours: hours,
          ...offer, inquiryId, agreement, customerAcceptedAt: stamp(), customerAcceptedHash:agreement.hash,
          notes: String(data.notes || '').trim().slice(0, 3000), status: 'Pending', createdAt: stamp() };
        if (action === 'preview') return {agreement, totalFee:offer.totalFee};
        if (data.agreementHash !== agreement.hash) fail('failed-precondition','The agreement changed. Preview and accept its current version again.');
        // An offer does not reserve time. The provider's acceptance takes the lock.
      } else {
        if (!b) fail('not-found', 'Booking not found.');
        providerId = b.providerId;
        const customer = b.customerId === uid, provider = b.providerId === uid;
        if (!customer && !provider && !isAdmin) fail('permission-denied', 'This booking belongs to another account.');
        const status = String(b.status).toLowerCase();
        switch (action) {
          case 'accept':
          case 'decline': {
            if (!provider || status !== 'pending') fail('failed-precondition', 'Only the provider can respond to a pending booking.');
            if (action === 'accept' && (!b.agreement || data.acceptAgreement !== true || data.agreementHash !== b.agreement.hash)) fail('failed-precondition', 'Review and accept the current contract. Legacy pending requests must be replaced with a fixed or daily offer.');
            if (action === 'accept' && windowFor(b).start <= Date.now()) fail('failed-precondition','This offer has passed its start time. Ask the customer for a new offer.');
            patch = action === 'accept' ? { status: 'Accepted', acceptedAt: stamp(),providerAcceptedAt:stamp(),providerAcceptedHash:b.agreement.hash } : { status: 'Declined' };
            if (action === 'accept') newWindow = b;
            break;
          }
          case 'requestChanges':
            if (!provider || status !== 'pending') fail('failed-precondition','Only the provider can request changes to a pending offer.');
            if (String(data.reason || '').trim().length < 10) fail('invalid-argument','Explain the requested changes in at least 10 characters.');
            patch = {status:'Changes Requested',changeRequest:String(data.reason).trim().slice(0,3000)};
            break;
          case 'cancel':
            if (!customer && !provider && !isAdmin) fail('permission-denied', 'Not your booking.');
            if (!['pending', 'accepted', 'in progress', 'changes requested'].includes(status)) fail('failed-precondition', 'This booking cannot be cancelled.');
            if (String(data.reason || '').trim().length < 10) fail('invalid-argument', 'Explain the cancellation in at least 10 characters.');
            patch = { status: 'Cancelled', cancelledAt: stamp(), cancellationReason: String(data.reason).trim().slice(0, 3000), cancelledByRole: customer ? 'customer' : provider ? 'provider' : 'administrator' };
            break;
          case 'start':
            if (!provider || status !== 'accepted' || b.startedAt) fail('failed-precondition', 'Only an accepted booking can be started by its provider.');
            if (b.agreement && b.providerAcceptedHash !== b.agreement.hash) fail('failed-precondition','Both parties must accept the same agreement before work starts.');
            if(b.agreement) {
              const profile=(await tx.get(db.doc(`serviceProviders/${providerId}`))).data();
              const service=(await tx.get(db.doc(`services/${b.serviceId}`))).data();
              if(!profile?.isVerified || !service || !hasMatchingCertificate(profile,service.category,service.serviceTitle)) fail('failed-precondition','A current verified matching certificate is required before work starts.');
            }
            if (Date.now() < windowFor(b).start) fail('failed-precondition', 'The scheduled start time has not arrived.');
            if (b.agreement && Date.now() >= windowFor(b).end) fail('failed-precondition','The agreed work period has ended. Discuss and accept a new schedule before starting.');
            patch = { status: 'In Progress', startedAt: stamp() };
            break;
          case 'complete':
            if (!provider || status !== 'in progress' || !b.startedAt) fail('failed-precondition', 'Start the job before marking it complete.');
            if (Date.now() < (b.agreement ? windowFor(b).end : b.startedAt.toMillis() + (Number(b.durationHours) || 1) * 3600000)) fail('failed-precondition', 'The work period has not finished.');
            patch = { status: 'Milestone Complete', completedAt: stamp() };
            break;
          case 'requestReschedule': {
            if (b.agreement) fail('failed-precondition','The schedule is part of the agreement. Cancel this offer with a recorded reason, discuss the change, and send a new offer for both parties to accept.');
            if (!customer || !['pending', 'accepted'].includes(status)) fail('failed-precondition', 'Only the customer can reschedule an unstarted booking.');
            const start = Number(data.scheduledDate), end = start + (windowFor(b).end - windowFor(b).start);
            if (!validWindow(start, end)) fail('invalid-argument', 'Select a future date and time.');
            patch = { rescheduleRequest: { scheduledDate: timestamp(start), scheduledEndDate: timestamp(end), requestedBy: uid, requestedAt: timestamp(Date.now()) } };
            break;
          }
          case 'approveReschedule':
          case 'rejectReschedule':
            if (!provider || !b.rescheduleRequest || !['pending', 'accepted'].includes(status)) fail('failed-precondition', 'No reschedule request is awaiting your response.');
            patch = { rescheduleRequest: FieldValue.delete() };
            if (action === 'approveReschedule') {
              const proposed = b.rescheduleRequest;
              if (!validWindow(proposed.scheduledDate.toMillis(), proposed.scheduledEndDate.toMillis())) fail('failed-precondition', 'The requested time has passed. Ask for a new date.');
              patch.scheduledDate = proposed.scheduledDate;
              patch.scheduledEndDate = proposed.scheduledEndDate;
              if (active(b)) newWindow = { ...b, ...proposed };
            }
            break;
          case 'adminStatus': {
            if (!isAdmin) fail('permission-denied', 'Administrator access is required.');
            let target = String(data.status || '');
            if (target !== 'Cancelled' && target !== 'Declined') fail('failed-precondition','Only the provider may accept an agreement, start work or report completion.');
            if (target === 'Completed') target = 'Milestone Complete';
            const allowed = { pending: ['Accepted', 'Declined', 'Cancelled'], accepted: ['In Progress', 'Cancelled'], 'in progress': ['Milestone Complete', 'Cancelled'] };
            if (!(allowed[status] || []).includes(target)) fail('failed-precondition', 'This status change is not valid for the current booking.');
            patch = { status: target };
            if (target === 'Accepted') { patch.acceptedAt = stamp(); newWindow = b; }
            if (target === 'In Progress') patch.startedAt = stamp();
            if (target === 'Milestone Complete') patch.completedAt = stamp();
            if (target === 'Cancelled') Object.assign(patch, { cancelledAt: stamp(), cancelledByRole: 'administrator', cancellationReason: 'Cancelled by the administrator after review.' });
            break;
          }
          default: fail('invalid-argument', 'Unsupported booking action.');
        }
      }
      // Every schedule-changing command reads and writes the same provider lock.
      // Concurrent accepts/reschedules retry, then see the committed competing job.
      const lockRef = db.collection('providerSchedules').doc(providerId);
      await tx.get(lockRef);
      if (newWindow) {
        const other = await tx.get(db.collection('bookings').where('providerId', '==', providerId));
        if (other.docs.some(d => d.id !== id && active(d.data()) && overlaps(newWindow, d.data()))) fail('already-exists', 'The provider already has an accepted booking during this time.');
      }
      let contractRef, contract, profileRef;
      if (patch.status === 'Accepted') {
        profileRef = db.collection('serviceProviders').doc(providerId);
        const profile = (await tx.get(profileRef)).data();
        const customer = (await tx.get(db.collection('users').doc(b.customerId))).data();
        const service = (await tx.get(db.collection('services').doc(b.serviceId))).data();
        if (!profile?.isVerified || customer?.accountStatus !== 'Active' || !service?.isActive || service.approvalStatus !== 'Approved'
          || !hasMatchingCertificate(profile, service.category, service.serviceTitle)) fail('failed-precondition', 'The service or one of its participants is no longer eligible for booking.');
        // Each accepted offer has its own immutable agreement; never overwrite a past contract.
        contractRef = db.collection('contracts').doc(id);
        contract = (await tx.get(contractRef)).data();
        patch.contractId = contractRef.id;
        patch.milestoneNumber = (contract?.milestoneCount || 0) + 1;
      }
      const who = { updatedBy: uid, updatedByRole: actor.role, updatedAt: stamp() };
      if (action === 'create') tx.create(ref, { ...patch, ...who });
      else tx.update(ref, { ...patch, ...who });
      tx.set(lockRef, { version: FieldValue.increment(1), updatedAt: stamp() }, { merge: true });
      if (patch.status === 'Accepted') {
        tx.set(contractRef, { customerId: b.customerId, providerId, status: 'active', milestoneCount: patch.milestoneNumber,
          agreement:b.agreement, customerAcceptedAt:b.customerAcceptedAt,customerAcceptedHash:b.customerAcceptedHash,
          providerAcceptedAt:stamp(),providerAcceptedHash:b.agreement.hash,
          createdAt: contract?.createdAt || stamp(), updatedAt: stamp() }, { merge: true });
        tx.update(profileRef, { acceptedBookings: FieldValue.increment(1) });
      }
      if (patch.status === 'Milestone Complete') tx.update(db.collection('serviceProviders').doc(providerId), { completedBookings: FieldValue.increment(1) });
      tx.create(auditRef, { actorId: uid, actorRole: actor.role, action: `booking.${action}`, collection: 'bookings', referenceId: id,
        beforeStatus: b?.status || '', afterStatus: patch.status || b?.status || '', createdAt: stamp() });
      return { bookingId: id };
    });
  };
};
