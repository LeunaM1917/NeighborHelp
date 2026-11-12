'use strict';
const { FieldValue, Timestamp, GeoPoint } = require('firebase-admin/firestore');

const { active, windowFor, validWindow, hasMatchingCertificate } = require('./domain');
const {validateOffer, makeAgreement} = require('./agreements');
const {coversSchedule, conflicts} = require('./scheduling');
const offerExpiry=require('./offer_expiry');
const accountSetup = require('./account_setup');
const inquiryKey = (customerId, providerId) => require('node:crypto').createHash('sha256')
  .update(JSON.stringify([customerId, providerId])).digest('hex');

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
      if(isAdmin)await require('./admin_security').assertAdminToken(context,fail,db,tx);
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
        if (!accountSetup.detailsComplete(actor) || !accountSetup.verified(actor)) fail('failed-precondition', 'Complete your profile and government ID verification, and receive verification approval, before sending an offer.');
        const serviceSnap = await tx.get(db.collection('services').doc(String(data.serviceId || '')));
        const service = serviceSnap.data();
        if (!service || !service.isActive || service.approvalStatus !== 'Approved' || service.archivedAt) fail('failed-precondition', 'This service is unavailable.');
        providerId = service.providerId;
        const profile = (await tx.get(db.collection('serviceProviders').doc(providerId))).data();
        const provider = (await tx.get(db.collection('users').doc(providerId))).data();
        if (!profile?.isVerified || provider?.accountStatus !== 'Active') fail('failed-precondition', 'This provider is not currently eligible for bookings.');
        if (!accountSetup.detailsComplete(provider, profile)) fail('failed-precondition', 'This provider must complete their required account details before receiving offers.');
        if (!hasMatchingCertificate(profile, service.category, service.serviceTitle)) fail('failed-precondition', 'The provider needs a valid certificate for this service.');
        const location = point(data.location);
        if (!require('./provider_area').covers(profile,location)) fail('failed-precondition', 'Choose a job address within the provider selected service barangays. Discuss boundary estimates in messages.');
        const address = String(data.serviceLocation || '').trim();
        if (address.length < 5 || address.length > 500) fail('invalid-argument', 'Enter the complete service address.');
        if (action === 'create' && !data.inquiryId && !data.agreementHash) {
          const thread = (await tx.get(db.doc(`inquiries/${inquiryKey(uid, providerId)}`))).data();
          if ((thread?.blockedBy || []).length) fail('failed-precondition', 'This conversation is blocked. New bookings cannot be sent.');
          const {start, end, ...details} = require('./direct_booking')(data, service, profile, fail);
          patch = {customerId: uid, providerId, serviceId: serviceSnap.id,
            serviceLocation: address, location, scheduledDate: timestamp(start),
            scheduledEndDate: timestamp(end), ...details, status: 'Pending',
            notes: String(data.notes || '').trim().slice(0, 3000), createdAt: stamp()};
          if(details.requestVersion===2) {
            patch.preferredScheduledDate=timestamp(start);
            newWindow=patch;
          }
        } else {
          // Keep existing contract clients/records compatible during the rollout.
          const offer = validateOffer(data, fail);
          const inquiryId = String(data.inquiryId || '');
          if (!/^[a-f0-9]{64}$/.test(inquiryId)) fail('failed-precondition', 'Message the provider and discuss the requirements before sending an offer.');
          const inquiry = (await tx.get(db.collection('inquiries').doc(inquiryId))).data();
          if (inquiry?.customerId !== uid || inquiry?.providerId !== providerId || !(inquiry.customerMessageCount > 0 && inquiry.providerMessageCount > 0)) fail('failed-precondition', 'Both parties must discuss the work in this conversation before an offer.');
          if ((inquiry.blockedBy || []).length) fail('failed-precondition','This conversation is blocked. New offers cannot be sent.');
          const start = Number(data.scheduledDate), end = start + (offer.numberOfDays - 1) * 86400000 + offer.hoursPerDay * 3600000;
          if (!Number.isFinite(start) || start <= Date.now() || start > Date.now() + 180 * 86400000) fail('invalid-argument', 'Choose a future start within 180 days.');
          const hours = offer.hoursPerDay * offer.numberOfDays;
          if(!coversSchedule(profile,{scheduledDate:start,scheduledEndDate:end,...offer})) fail('failed-precondition','The requested work periods are outside the provider\'s working hours. Discuss a different schedule first.');
          const agreement = makeAgreement({id,offer,customer:{id:uid,fullName:actor.fullName || 'Customer'},provider:{id:providerId,fullName:provider.fullName || 'Provider'},service:service.serviceTitle,address,start,end});
          patch = { customerId: uid, providerId, serviceId: serviceSnap.id, serviceLocation: address, location,
            scheduledDate: timestamp(start), scheduledEndDate: timestamp(end), durationHours: hours,
            ...offer, inquiryId, agreement, customerAcceptedAt: stamp(), customerAcceptedHash:agreement.hash,
            notes: String(data.notes || '').trim().slice(0, 3000), status: 'Pending',offerExpiresAt:timestamp(offerExpiry.deadline(start)),createdAt: stamp() };
          if (action === 'preview') return {agreement, totalFee:offer.totalFee};
          if (data.agreementHash !== agreement.hash) fail('failed-precondition','The agreement changed. Preview and accept its current version again.');
          // An offer does not reserve time. The provider's acceptance takes the lock.
        }
      } else {
        if (!b) fail('not-found', 'Booking not found.');
        providerId = b.providerId;
        const customer = b.customerId === uid, provider = b.providerId === uid;
        if (!customer && !provider && !isAdmin) fail('permission-denied', 'This booking belongs to another account.');
        if(offerExpiry.expired(b))fail('failed-precondition','This offer expired. Discuss and send a new offer.');
        const status = String(b.status).toLowerCase();
        switch (action) {
          case 'accept':
          case 'decline': {
            if (!provider || status !== 'pending') fail('failed-precondition', 'Only the provider can respond to a pending booking.');
            if(action==='accept'&&b.requestVersion===2)fail('failed-precondition','Set the estimated duration and price, then send the terms for customer approval.');
            if(b.pendingAmendmentId)fail('failed-precondition','Respond to or withdraw the pending estimate first.');
            if(offerExpiry.expired(b))fail('failed-precondition','This offer expired. Ask the customer to discuss and send a new offer.');
            if (action === 'accept' && b.agreement && (data.acceptAgreement !== true || data.agreementHash !== b.agreement.hash)) fail('failed-precondition', 'Review and accept the current contract.');
            if (action === 'accept' && windowFor(b).start <= Date.now()) fail('failed-precondition','This offer has passed its start time. Ask the customer for a new offer.');
            if(action==='accept') {
              const thread=(await tx.get(db.doc(`inquiries/${b.inquiryId || inquiryKey(b.customerId, providerId)}`))).data();
              if((b.inquiryId && !thread) || (thread?.blockedBy || []).length) fail('failed-precondition','The conversation is unavailable or blocked. Resolve that before accepting a booking.');
            }
            patch = action === 'accept' ? { status: 'Accepted', acceptedAt: stamp(),
              ...(b.agreement ? {providerAcceptedAt:stamp(),providerAcceptedHash:b.agreement.hash} : {}) } : { status: 'Declined' };
            if (action === 'accept') newWindow = b;
            break;
          }
          case 'requestChanges':
            if(offerExpiry.expired(b))fail('failed-precondition','This offer expired. Discuss a new offer.');
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
            if(b.pendingAmendmentId)fail('failed-precondition','Resolve the proposed estimate before starting work.');
            if(b.requestVersion===2&&(!b.confirmedTerms||b.customerAcceptedHash!==b.confirmedTerms.hash||b.providerAcceptedHash!==b.confirmedTerms.hash))fail('failed-precondition','Both parties must approve the same booking terms before work starts.');
            if (!provider || status !== 'accepted' || b.startedAt) fail('failed-precondition', 'Only an accepted booking can be started by its provider.');
            if (b.agreement && b.providerAcceptedHash !== b.agreement.hash) fail('failed-precondition','Both parties must accept the same agreement before work starts.');
            if(b.agreement||b.requestVersion===2) {
              const profile=(await tx.get(db.doc(`serviceProviders/${providerId}`))).data();
              const service=(await tx.get(db.doc(`services/${b.serviceId}`))).data();
              if(!profile?.isVerified || !service || !hasMatchingCertificate(profile,service.category,service.serviceTitle)) fail('failed-precondition','A current verified matching certificate is required before work starts.');
            }
            if (Date.now() < windowFor(b).start) fail('failed-precondition', 'The scheduled start time has not arrived.');
            if ((b.agreement || b.requestVersion===2) && Date.now() >= windowFor(b).end) fail('failed-precondition','The agreed work period has ended. Discuss and accept a new schedule before starting.');
            patch = { status: 'In Progress', startedAt: stamp() };
            break;
          case 'complete':
            if (!provider || status !== 'in progress' || !b.startedAt) fail('failed-precondition', 'Start the job before marking it complete.');
            if(b.pendingAmendmentId) fail('failed-precondition','Resolve the proposed amendment before reporting completion.');
            if (b.pricingType !== 'fixed' && Date.now() < (b.agreement ? windowFor(b).end : b.startedAt.toMillis() + (Number(b.durationHours) || 1) * 3600000)) fail('failed-precondition', 'The work period has not finished.');
            patch = { status: 'Awaiting Confirmation', completionReportedAt: stamp(), completionResponseDueAt:timestamp(Date.now()+72*3600000), correctionRequest:FieldValue.delete() };
            break;
          case 'confirmCompletion':
            if(!customer || status !== 'awaiting confirmation') fail('failed-precondition','Only the customer can confirm reported completion.');
            if(data.confirmDeliverables !== true) fail('failed-precondition','Inspect the agreed deliverables and confirm they are complete.');
            patch = {status:b.agreement ? 'Milestone Complete' : 'Completed',completedAt:stamp(),completionConfirmedBy:uid,...(b.requestVersion===2?{finalFee:b.totalFee}:{})};
            break;
          case 'requestCorrections':
            if(!customer || status !== 'awaiting confirmation') fail('failed-precondition','Only the customer can request corrections to reported work.');
            if(String(data.reason || '').trim().length<10) fail('invalid-argument','Describe the incomplete or defective deliverables in at least 10 characters.');
            patch = {status:'In Progress',correctionRequest:String(data.reason).trim().slice(0,3000),correctionRequestedAt:stamp(),correctionRounds:FieldValue.increment(1)};
            break;
          case 'requestReschedule': {
            if(b.pendingAmendmentId)fail('failed-precondition','Resolve the pending estimate before requesting a different date.');
            if (b.agreement) fail('failed-precondition','The schedule is part of the agreement. Cancel this offer with a recorded reason, discuss the change, and send a new offer for both parties to accept.');
            if (!customer || !['pending', 'accepted'].includes(status)) fail('failed-precondition', 'Only the customer can reschedule an unstarted booking.');
            const start = Number(data.scheduledDate), end = start + (windowFor(b).end - windowFor(b).start);
            if (!validWindow(start, end)) fail('invalid-argument', 'Select a future date and time.');
            if(b.requestVersion===2)newWindow={...b,scheduledDate:timestamp(start),scheduledEndDate:timestamp(end)};
            patch = { rescheduleRequest: { scheduledDate: timestamp(start), scheduledEndDate: timestamp(end), requestedBy: uid, requestedAt: timestamp(Date.now()) } };
            break;
          }
          case 'approveReschedule':
          case 'rejectReschedule':
            if (!provider || !b.rescheduleRequest || !['pending', 'accepted'].includes(status)) fail('failed-precondition', 'No reschedule request is awaiting your response.');
            patch = { rescheduleRequest: FieldValue.delete() };
            if (action === 'approveReschedule') {
              if(b.requestVersion===2)fail('failed-precondition','Send a revised provider estimate for customer approval instead of replacing confirmed terms directly.');
              const proposed = b.rescheduleRequest;
              if (!validWindow(proposed.scheduledDate.toMillis(), proposed.scheduledEndDate.toMillis())) fail('failed-precondition', 'The requested time has passed. Ask for a new date.');
              patch.scheduledDate = proposed.scheduledDate;
              patch.scheduledEndDate = proposed.scheduledEndDate;
              newWindow = { ...b, ...proposed };
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
        const profile=(await tx.get(db.doc(`serviceProviders/${providerId}`))).data();
        if(!coversSchedule(profile || {},newWindow)) fail('failed-precondition','The provider\'s working hours no longer cover every requested work period.');
        const other = await tx.get(db.collection('bookings').where('providerId', '==', providerId));
        if (other.docs.some(d => d.id !== id && active(d.data()) && conflicts(newWindow, d.data()))) fail('already-exists', 'The provider already has an accepted booking or a 15-minute travel buffer during this time.');
      }
      let contractRef, contract, profileRef;
      let supersededAmendment;
      if(patch.status==='Cancelled' && b?.pendingAmendmentId) {
        supersededAmendment=ref.collection('amendments').doc(b.pendingAmendmentId);
        const pending=(await tx.get(supersededAmendment)).data();
        if(pending?.status!=='Proposed') supersededAmendment=null;
        patch.pendingAmendmentId=FieldValue.delete();
      }
      if (patch.status === 'Accepted') {
        profileRef = db.collection('serviceProviders').doc(providerId);
        const profile = (await tx.get(profileRef)).data();
        const customer = (await tx.get(db.collection('users').doc(b.customerId))).data();
        const service = (await tx.get(db.collection('services').doc(b.serviceId))).data();
        if (!accountSetup.detailsComplete(customer) || !accountSetup.verified(customer)
          || !accountSetup.detailsComplete(actor, profile)) fail('failed-precondition', 'Both parties must complete account setup and the customer must have approved identity verification before this offer can be accepted.');
        if (!profile?.isVerified || customer?.accountStatus !== 'Active' || !service?.isActive || service.approvalStatus !== 'Approved'
          || !hasMatchingCertificate(profile, service.category, service.serviceTitle)) fail('failed-precondition', 'The service or one of its participants is no longer eligible for booking.');
        if(!require('./provider_area').covers(profile,point(b.location))) fail('failed-precondition','The provider no longer serves this barangay. Discuss coverage before sending a new offer.');
        if (b.agreement) {
          // Preserve acceptance evidence for existing contract bookings.
          contractRef = db.collection('contracts').doc(id);
          contract = (await tx.get(contractRef)).data();
          patch.contractId = contractRef.id;
          patch.milestoneNumber = (contract?.milestoneCount || 0) + 1;
        }
      }
      const who = { updatedBy: uid, updatedByRole: actor.role, updatedAt: stamp() };
      if (action === 'create') tx.create(ref, { ...patch, ...who });
      else tx.update(ref, { ...patch, ...who });
      if(supersededAmendment) tx.update(supersededAmendment,{status:'Superseded by cancellation',respondedBy:uid,respondedAt:stamp()});
      if(['complete','confirmCompletion','requestCorrections'].includes(action)) tx.create(ref.collection('workEvents').doc(),{action,actorId:uid,reason:patch.correctionRequest && typeof patch.correctionRequest==='string' ? patch.correctionRequest : '',createdAt:stamp()});
      tx.set(lockRef, { version: FieldValue.increment(1), updatedAt: stamp() }, { merge: true });
      if (patch.status === 'Accepted') {
        if (contractRef) {
          tx.set(contractRef, { customerId: b.customerId, providerId, status: 'active', milestoneCount: patch.milestoneNumber,
            agreement:b.agreement, customerAcceptedAt:b.customerAcceptedAt,customerAcceptedHash:b.customerAcceptedHash,
            providerAcceptedAt:stamp(),providerAcceptedHash:b.agreement.hash,
            createdAt: contract?.createdAt || stamp(), updatedAt: stamp() }, { merge: true });
          tx.create(ref.collection('agreementVersions').doc('0'),{agreement:b.agreement,revision:0,customerAcceptedAt:b.customerAcceptedAt,providerAcceptedAt:stamp()});
        }
        tx.update(profileRef, { acceptedBookings: FieldValue.increment(1) });
      }
      if (['Milestone Complete', 'Completed'].includes(patch.status)) tx.update(db.collection('serviceProviders').doc(providerId), { completedBookings: FieldValue.increment(1) });
      tx.create(auditRef, { actorId: uid, actorRole: actor.role, action: `booking.${action}`, collection: 'bookings', referenceId: id,
        beforeStatus: b?.status || '', afterStatus: patch.status || b?.status || '', createdAt: stamp() });
      if(action==='create'&&patch.requestVersion===2)tx.create(db.collection('notifications').doc(),{userId:uid,title:'Booking request sent',message:'Your preferred start and job description were sent. The provider will set the estimated duration and price for your approval.',relatedBookingId:id,notificationType:'Booking',isRead:false,createdAt:stamp()});
      return { bookingId: id };
    });
  };
};
