'use strict';
const crypto=require('node:crypto');
const {FieldValue,Timestamp}=require('firebase-admin/firestore');
const {active,windowFor,hasMatchingCertificate}=require('./domain');
const {coversSchedule,conflicts}=require('./scheduling');
const setup=require('./account_setup');
const stamp=()=>FieldValue.serverTimestamp();
const hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
function baseHash(b) {
  const window=windowFor(b);
  return hash([b.termsRevision||0,window.start,window.end,b.pricingType,b.hourlyRate??null,b.durationHours??null,b.totalFee??null,b.startedAt?.toMillis?.()??null,
    b.serviceId,b.serviceLocation,b.location?.latitude??null,b.location?.longitude??null,b.notes||'']);
}
function terms(data,b,fail) {
  const start=Number(data.scheduledDate),durationHours=Number(data.durationHours),pricingType=String(data.pricingType||'');
  const rateCents=Math.round((Number(data.proposedRate)+Number.EPSILON)*100),rate=rateCents/100;
  const end=start+durationHours*3600000,now=Date.now();
  if(!Number.isFinite(start)||!Number.isFinite(durationHours)||durationHours<.25||durationHours>24||!Number.isInteger(durationHours*4)||end<=now||start>now+180*86400000||(!b.startedAt&&start<=now))fail('invalid-argument','Choose a future schedule and a duration of 0.25–24 hours in 15-minute increments.');
  if(b.startedAt&&start!==windowFor(b).start)fail('failed-precondition','Ongoing work must keep its confirmed start. Propose additional duration or a price change.');
  if(!['hourly','fixed'].includes(pricingType)||!Number.isFinite(rate)||rate<=0||rate>1000000)fail('invalid-argument','Choose hourly or fixed pricing and a valid positive rate.');
  const totalFee=(pricingType==='hourly'?Math.round(rateCents*durationHours):rateCents)/100;
  if(totalFee<=0||totalFee>1000000)fail('invalid-argument','The agreed total must be between PHP 0.01 and PHP 1,000,000.');
  if(totalFee*100<(b.confirmedPaymentCents||0)+(b.pendingPaymentCents||0))fail('failed-precondition','Resolve payment records before reducing the price below reported payments.');
  return {start,end,durationHours,pricingType,proposedRate:rate,hourlyRate:pricingType==='hourly'?rate:null,totalFee};
}
function document(id,revisionId,b,t,reason) {
  const when=ms=>new Date(ms+8*3600000).toISOString().replace('Z','+08:00');
  const text=`NEIGHBORHELP PROVIDER ESTIMATE\nBooking: ${id}\nRevision: ${revisionId}\nService: ${b.serviceId}\nJob description: ${b.notes||''}\nService location: ${b.serviceLocation}\nProposed start: ${when(t.start)}\nEstimated end: ${when(t.end)}\nEstimated duration: ${t.durationHours} hours\nPricing: ${t.pricingType}\n${t.pricingType==='hourly'?'Hourly rate':'Fixed fee'}: PHP ${t.proposedRate.toFixed(2)}\nTotal agreed fee: PHP ${t.totalFee.toFixed(2)}\nReason / scope: ${reason}\nThese terms become confirmed only after the customer approves this exact estimate. Extra time or charges require a further approved amendment; elapsed time alone does not increase the fee.`;
  return {text,hash:crypto.createHash('sha256').update(text).digest('hex'),templateVersion:'direct-estimate-v1'};
}
async function apply({tx,db,data,uid,actor,b,ref,revisionRef,id,revisionId,fail}) {
  const action=String(data.action),provider=uid===b.providerId,customer=uid===b.customerId;
  if(!['Pending','Changes Requested','Accepted','In Progress'].includes(b.status))fail('failed-precondition','This booking no longer accepts estimate changes.');
  const initial=!active(b);
  const revision=(await tx.get(revisionRef)).data();
  if(action==='accept'&&revision?.status==='Accepted'&&revision.acceptedBy===uid&&b.confirmedTerms?.hash===revision.agreement.hash)return {revisionId,duplicate:true};
  if((action==='preview'||action==='propose')&&!provider)fail('permission-denied','Only the provider can set the estimated duration and propose price or schedule changes.');
  if(b.rescheduleRequest&&!['preview','propose'].includes(action))fail('failed-precondition','Resolve the pending schedule request before approving revised terms.');
  let result,patch,writeRevision,lock;
  if(action==='preview'||action==='propose') {
    if(revision) {
      if(action==='propose'&&revision.proposedBy===uid&&revision.agreement.hash===data.agreementHash)return {revisionId,duplicate:true};
      fail('already-exists','This estimate reference is already used.');
    }
    if(b.pendingAmendmentId)fail('failed-precondition','Respond to or withdraw the current estimate first.');
    const reason=String(data.reason||'').trim();
    if(reason.length<10||reason.length>3000)fail('invalid-argument','Explain the scope or proposed changes in 10–3000 characters.');
    const t=terms(data,b,fail);
    result={...t,agreement:document(id,revisionId,b,t,reason)};
    writeRevision={...t,scheduledDate:Timestamp.fromMillis(t.start),scheduledEndDate:Timestamp.fromMillis(t.end),agreement:result.agreement,
      reason,baseHash:baseHash(b),status:'Proposed',proposedBy:uid,proposedAt:stamp(),expiresAt:Timestamp.fromMillis(Math.min(Date.now()+72*3600000,b.startedAt?t.end:t.start))};
    delete writeRevision.start;delete writeRevision.end;
    patch={pendingAmendmentId:revisionId,termsStatus:'Awaiting customer approval',...(initial?{status:'Changes Requested',changeRequest:reason}:{})};
    if(b.rescheduleRequest)patch.rescheduleRequest=FieldValue.delete();
  } else {
    if(!revision||revision.status!=='Proposed'||b.pendingAmendmentId!==revisionId)fail('failed-precondition','This estimate is no longer awaiting a response.');
    if(action==='accept') {
      if(!customer||revision.proposedBy!==b.providerId||data.acceptAgreement!==true||data.agreementHash!==revision.agreement.hash)fail('permission-denied','The customer must review and approve the exact provider estimate.');
      if(baseHash(b)!==revision.baseHash)fail('failed-precondition','The booking changed. Ask for a new estimate.');
      if(revision.expiresAt.toMillis()<=Date.now())fail('failed-precondition','This estimate expired. Ask the provider to withdraw it and send a new estimate.');
      result=terms({scheduledDate:revision.scheduledDate.toMillis(),durationHours:revision.durationHours,pricingType:revision.pricingType,proposedRate:revision.proposedRate},b,fail);
      lock=db.doc(`providerSchedules/${b.providerId}`);await tx.get(lock);
      patch={scheduledDate:revision.scheduledDate,scheduledEndDate:revision.scheduledEndDate,durationHours:revision.durationHours,
        pricingType:revision.pricingType,hourlyRate:revision.hourlyRate,totalFee:revision.totalFee,
        numberOfDays:FieldValue.delete(),hoursPerDay:FieldValue.delete(),proposedRate:FieldValue.delete(),
        requestVersion:2,confirmedTerms:revision.agreement,termsRevision:(b.termsRevision||0)+1,termsStatus:'Confirmed',
        customerAcceptedAt:stamp(),providerAcceptedAt:revision.proposedAt,customerAcceptedHash:revision.agreement.hash,providerAcceptedHash:revision.agreement.hash,
        pendingAmendmentId:FieldValue.delete(),changeRequest:FieldValue.delete(),...(initial?{status:'Accepted',acceptedAt:stamp()}:{})};
    } else if(action==='decline'||action==='withdraw') {
      if(action==='decline'?!customer:!provider)fail('permission-denied','Only the customer may decline; only the provider may withdraw this estimate.');
      patch={pendingAmendmentId:FieldValue.delete(),termsStatus:initial?'Awaiting provider estimate':'Confirmed',...(initial?{status:'Pending',changeRequest:FieldValue.delete()}:{})};
    } else fail('invalid-argument','Unsupported estimate action.');
  }
  // Validate availability for both a proposal and its final approval. The latter
  // serializes with normal accepts, time off, reschedules and other amendments.
  if(result) {
    const [profileSnap,providerSnap,customerSnap,serviceSnap]=await Promise.all([
      tx.get(db.doc(`serviceProviders/${b.providerId}`)),tx.get(db.doc(`users/${b.providerId}`)),
      tx.get(db.doc(`users/${b.customerId}`)),tx.get(db.doc(`services/${b.serviceId}`))]);
    const profile=profileSnap.data(),owner=providerSnap.data(),client=customerSnap.data(),service=serviceSnap.data();
    if(!profile?.isVerified||owner?.accountStatus!=='Active'||client?.accountStatus!=='Active'||!setup.detailsComplete(owner,profile)||!setup.detailsComplete(client)||!setup.verified(client)||!service?.isActive||service.approvalStatus!=='Approved'||!hasMatchingCertificate(profile,service.category,service.serviceTitle))fail('failed-precondition','Both accounts, the service and the provider qualification must remain eligible.');
    if(!require('./provider_area').covers(profile,b.location))fail('failed-precondition','The provider no longer serves this service location.');
    const candidate={scheduledDate:result.start,scheduledEndDate:result.end};
    if(!coversSchedule(profile,candidate))fail('failed-precondition','The estimated work period is outside working hours or time off.');
    const jobs=await tx.get(db.collection('bookings').where('providerId','==',b.providerId));
    if(jobs.docs.some(d=>d.id!==id&&active(d.data())&&conflicts(candidate,d.data())))fail('already-exists','Another accepted booking or its 15-minute travel buffer overlaps these terms.');
    const threadId=b.inquiryId||crypto.createHash('sha256').update(JSON.stringify([b.customerId,b.providerId])).digest('hex');
    const thread=(await tx.get(db.doc(`inquiries/${threadId}`))).data();
    if((thread?.blockedBy||[]).length)fail('failed-precondition','Resolve the blocked conversation before confirming work.');
    if(action==='preview')return {agreement:result.agreement,totalFee:result.totalFee};
    if(action==='propose'&&(data.acceptAgreement!==true||data.agreementHash!==result.agreement.hash))fail('failed-precondition','Review and approve this exact estimate before sending it.');
  }
  const eventId=`${revisionId}:${action}`;
  if(action==='propose')tx.create(revisionRef,writeRevision);
  else tx.update(revisionRef,{status:action==='accept'?'Accepted':action==='decline'?'Declined':'Withdrawn',respondedBy:uid,respondedAt:stamp(),...(action==='accept'?{acceptedBy:uid,acceptedAt:stamp()}:{})});
  tx.update(ref,{...patch,lastEstimateEvent:eventId,updatedAt:stamp(),updatedBy:uid,updatedByRole:actor.role});
  if(action==='accept') {
    if(!initial&&!b.confirmedTerms)tx.create(ref.collection('agreementVersions').doc('legacy-direct-0'),{
      agreement:{text:`PREVIOUSLY RECORDED BOOKING TERMS\nBooking: ${id}\nScheduled start: ${new Date(windowFor(b).start).toISOString()}\nScheduled end: ${new Date(windowFor(b).end).toISOString()}\nRecorded duration: ${b.durationHours??'Not recorded'} hours\nRecorded fee: PHP ${b.totalFee??'Not recorded'}\nThis historical record preserves the previous booking data; missing acceptance evidence is not inferred.`,hash:baseHash(b)},
      revision:0,customerAcceptedAt:b.customerAcceptedAt||null,providerAcceptedAt:b.providerAcceptedAt||b.acceptedAt||null,recordedAt:stamp()});
    tx.create(ref.collection('agreementVersions').doc(`estimate-${patch.termsRevision}`),{agreement:revision.agreement,revision:patch.termsRevision,
      customerAcceptedAt:stamp(),providerAcceptedAt:revision.proposedAt,revisionId});
    tx.set(lock,{version:FieldValue.increment(1),updatedAt:stamp()},{merge:true});
    if(initial)tx.update(db.doc(`serviceProviders/${b.providerId}`),{acceptedBookings:FieldValue.increment(1)});
  }
  tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:`booking.estimate.${action}`,collection:'bookings',referenceId:id,revisionId,createdAt:stamp()});
  for(const userId of [b.customerId,b.providerId])tx.create(db.collection('notifications').doc(),{userId,relatedBookingId:id,notificationType:'Booking Estimate',isRead:false,createdAt:stamp(),
    title:action==='propose'?'Provider estimate awaiting approval':action==='accept'?'Booking terms confirmed':action==='decline'?'Provider estimate declined':'Provider estimate withdrawn',
    message:action==='propose'?'Review the proposed schedule, estimated duration and total price. Nothing is confirmed until the customer approves.':action==='accept'?'Both parties approved the schedule, duration and agreed fee. Open the booking for confirmed details.':'The estimate was not applied. Previously confirmed terms remain unchanged.'});
  return {revisionId};
}
module.exports={apply,terms,baseHash};
