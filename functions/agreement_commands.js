'use strict';
const crypto=require('node:crypto');
const {FieldValue,Timestamp}=require('firebase-admin/firestore');
const {validateOffer,makeAgreement}=require('./agreements');
const {active,windowFor,hasMatchingCertificate}=require('./domain');
const {coversSchedule,conflicts}=require('./scheduling');
module.exports=({db,functions})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid, id=String(data.bookingId || ''), revisionId=String(data.revisionId || '');
  if(!uid) fail('unauthenticated','Sign in required.');
  if(!/^[\w-]{1,160}$/.test(id) || !/^[\w-]{1,100}$/.test(revisionId)) fail('invalid-argument','Invalid agreement reference.');
  const ref=db.doc(`bookings/${id}`), revisionRef=ref.collection('amendments').doc(revisionId), stamp=()=>FieldValue.serverTimestamp();
  return db.runTransaction(async tx=>{
    const actor=(await tx.get(db.doc(`users/${uid}`))).data(),b=(await tx.get(ref)).data();
    if(actor?.accountStatus!=='Active' || !b || ![b.customerId,b.providerId].includes(uid)) fail('permission-denied','Only active participants may change this agreement.');
    if(!b.agreement)return require('./booking_estimates').apply({tx,db,data,uid,actor,b,ref,revisionRef,id,revisionId,fail});
    if(!b.agreement || !['Accepted','In Progress'].includes(b.status)) fail('failed-precondition','Amendments are available for accepted or ongoing work. Resolve completion first.');
    const contractRef=db.doc(`contracts/${b.contractId || id}`),contract=(await tx.get(contractRef)).data();
    if(contract?.status!=='active') fail('failed-precondition','This contract has ended.');
    const revision=(await tx.get(revisionRef)).data();
    const action=String(data.action);
    if(action==='preview' || action==='propose') {
      if(revision) { if(revision.proposedBy===uid && revision.agreement.hash===data.agreementHash) return {revisionId,duplicate:true}; fail('already-exists','This amendment reference is already used.'); }
      if(b.pendingAmendmentId) fail('failed-precondition','Respond to or withdraw the current amendment first.');
      if(data.expectedHash!==b.agreement.hash) fail('failed-precondition','The agreement changed. Open the current version and try again.');
      const offer=validateOffer(data,fail), start=Number(data.scheduledDate),end=start+(offer.numberOfDays-1)*86400000+offer.hoursPerDay*3600000;
      const current=windowFor(b), reason=String(data.reason || '').trim();
      if(reason.length<10 || reason.length>3000) fail('invalid-argument','Explain the amendment in 10–3000 characters.');
      if(!Number.isFinite(start) || end<=Date.now() || start>Date.now()+180*86400000) fail('invalid-argument','The amended work period must end in the future and start within 180 days.');
      if(b.startedAt ? start!==current.start || offer.hoursPerDay!==b.hoursPerDay || offer.numberOfDays<b.numberOfDays : start<=Date.now()) fail('failed-precondition','Ongoing work must keep its start, hours per day and completed days. Add days or clarify scope; discuss a new offer for other scheduling changes.');
      if(Math.round(offer.totalFee*100)<(b.confirmedPaymentCents || 0)+(b.pendingPaymentCents || 0)) fail('failed-precondition','Resolve the payment records before reducing the price below received or reported payments.');
      const [customer,provider,service,profile]=await Promise.all([tx.get(db.doc(`users/${b.customerId}`)),tx.get(db.doc(`users/${b.providerId}`)),tx.get(db.doc(`services/${b.serviceId}`)),tx.get(db.doc(`serviceProviders/${b.providerId}`))]);
      if(customer.data()?.accountStatus!=='Active' || provider.data()?.accountStatus!=='Active') fail('failed-precondition','Both accounts must be active.');
      if(!profile.data()?.isVerified || !service.exists || !hasMatchingCertificate(profile.data(),service.data().category,service.data().serviceTitle)) fail('failed-precondition','A current matching verified certificate is required for amended work.');
      if(!coversSchedule(profile.data() || {},{scheduledDate:start,scheduledEndDate:end,...offer})) fail('failed-precondition','The amended schedule is outside the provider\'s working hours.');
      const agreement=makeAgreement({id:`${id} amendment ${revisionId}`,offer,customer:{id:b.customerId,fullName:customer.data().fullName || 'Customer'},provider:{id:b.providerId,fullName:provider.data().fullName || 'Provider'},service:service.data()?.serviceTitle || b.serviceId,address:b.serviceLocation,start,end});
      agreement.text=`AMENDMENT TO ACCEPTED AGREEMENT\nPrevious fingerprint: ${b.agreement.hash}\nReason: ${reason}\nThe following terms apply only after both participants accept this amendment. Previous versions remain on record.\n\n${agreement.text}`;
      agreement.hash=crypto.createHash('sha256').update(agreement.text).digest('hex');
      if(action==='preview') return {agreement,totalFee:offer.totalFee};
      if(data.agreementHash!==agreement.hash) fail('failed-precondition','Preview and accept this exact amendment before proposing it.');
      tx.create(revisionRef,{...offer,scheduledDate:Timestamp.fromMillis(start),scheduledEndDate:Timestamp.fromMillis(end),agreement,baseHash:b.agreement.hash,reason,status:'Proposed',proposedBy:uid,proposedAt:stamp()});
      tx.update(ref,{pendingAmendmentId:revisionId,updatedAt:stamp()});
    } else {
      if(!revision || revision.status!=='Proposed' || b.pendingAmendmentId!==revisionId) fail('failed-precondition','This amendment is no longer awaiting a response.');
      if(action==='accept') {
        if(uid===revision.proposedBy || data.acceptAgreement!==true || data.agreementHash!==revision.agreement.hash) fail('failed-precondition','The other participant must review and accept this exact amendment.');
        if(b.agreement.hash!==revision.baseHash) fail('failed-precondition','The base agreement changed. Propose a new amendment.');
        if(Math.round(revision.totalFee*100)<(b.confirmedPaymentCents || 0)+(b.pendingPaymentCents || 0)) fail('failed-precondition','Resolve payment records before accepting this reduced price.');
        const provider=(await tx.get(db.doc(`users/${b.providerId}`))).data(), customer=(await tx.get(db.doc(`users/${b.customerId}`))).data();
        const profile=(await tx.get(db.doc(`serviceProviders/${b.providerId}`))).data();
        const service=(await tx.get(db.doc(`services/${b.serviceId}`))).data();
        if(!profile?.isVerified || !service || !hasMatchingCertificate(profile,service.category,service.serviceTitle)) fail('failed-precondition','A current matching verified certificate is required for amended work.');
        if(provider?.accountStatus!=='Active' || customer?.accountStatus!=='Active') fail('failed-precondition','Both accounts must be active.');
        if(!coversSchedule(profile || {},revision)) fail('failed-precondition','The provider\'s hours no longer cover this amendment.');
        if(!b.startedAt && revision.scheduledDate.toMillis()<=Date.now() || revision.scheduledEndDate.toMillis()<=Date.now()) fail('failed-precondition','The proposed work period has passed.');
        const lock=db.doc(`providerSchedules/${b.providerId}`); await tx.get(lock);
        const jobs=await tx.get(db.collection('bookings').where('providerId','==',b.providerId));
        if(jobs.docs.some(d=>d.id!==id && active(d.data()) && conflicts(revision,d.data()))) fail('already-exists','The revised schedule conflicts with another job or its travel buffer.');
        const previous=ref.collection('agreementVersions').doc(String(b.agreementRevision || 0));
        const previousSnap=await tx.get(previous);
        if(!previousSnap.exists) tx.create(previous,{agreement:b.agreement,customerAcceptedAt:b.customerAcceptedAt,providerAcceptedAt:b.providerAcceptedAt,revision:b.agreementRevision || 0});
        const patch={};
        for(const key of ['pricingType','proposedRate','numberOfDays','hoursPerDay','totalFee','scope','deliverables','exclusions','materials','paymentTerms','completionCriteria','responsibilities','scheduledDate','scheduledEndDate','agreement']) patch[key]=revision[key];
        const customerAt=revision.proposedBy===b.customerId ? revision.proposedAt : stamp(),providerAt=revision.proposedBy===b.providerId ? revision.proposedAt : stamp();
        Object.assign(patch,{originalAgreement:b.originalAgreement || b.agreement,agreementRevision:(b.agreementRevision || 0)+1,pendingAmendmentId:FieldValue.delete(),durationHours:revision.numberOfDays*revision.hoursPerDay,
          customerAcceptedHash:revision.agreement.hash,providerAcceptedHash:revision.agreement.hash,customerAcceptedAt:customerAt,providerAcceptedAt:providerAt,updatedAt:stamp()});
        tx.update(ref,patch);
        tx.create(ref.collection('agreementVersions').doc(String(patch.agreementRevision)),{agreement:revision.agreement,revision:patch.agreementRevision,customerAcceptedAt:customerAt,providerAcceptedAt:providerAt,revisionId});
        tx.update(contractRef,{currentAgreement:revision.agreement,agreementRevision:patch.agreementRevision,updatedAt:stamp()});
        tx.update(revisionRef,{status:'Accepted',acceptedBy:uid,acceptedAt:stamp()});
        tx.set(lock,{version:FieldValue.increment(1),updatedAt:stamp()},{merge:true});
      } else if(action==='decline' || action==='withdraw') {
        if((action==='withdraw')!==(uid===revision.proposedBy)) fail('permission-denied','Only the proposer can withdraw; the other participant can decline.');
        tx.update(revisionRef,{status:action==='withdraw' ? 'Withdrawn' : 'Declined',respondedBy:uid,respondedAt:stamp()});
        tx.update(ref,{pendingAmendmentId:FieldValue.delete(),updatedAt:stamp()});
      } else fail('invalid-argument','Unsupported amendment action.');
    }
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:`agreement.${action}`,collection:'bookings',referenceId:id,revisionId,createdAt:stamp()});
    const other=uid===b.customerId ? b.providerId : b.customerId;
    tx.create(db.collection('notifications').doc(),{userId:other,title:'Contract amendment',message:`A contract amendment was ${action==='propose' ? 'proposed for your review' : action==='accept' ? 'accepted' : action==='decline' ? 'declined' : 'withdrawn'}.`,relatedBookingId:id,notificationType:'Contract',isRead:false,createdAt:stamp()});
    return {revisionId};
  });
};
