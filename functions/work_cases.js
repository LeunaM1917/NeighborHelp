'use strict';
const crypto=require('node:crypto');
const {FieldValue,Timestamp,FieldPath}=require('firebase-admin/firestore');
const ms=value=>value?.toMillis?.() || Number(value) || 0;
function caseEligibility(b,type,now=Date.now()) {
  if(type==='completion_overdue')return b.status==='Awaiting Confirmation' && ms(b.completionResponseDueAt)>0 && ms(b.completionResponseDueAt)<=now;
  if(type==='no_show'||type==='start_unconfirmed')return b.status==='Accepted' && !b.startedAt && ms(b.scheduledDate)>0 && ms(b.scheduledDate)+3600000<=now;
  if(type==='corrections_overdue')return b.status==='In Progress' && b.correctionRequest && ms(b.correctionRequestedAt)>0 && ms(b.correctionRequestedAt)+72*3600000<=now;
  return false;
}
function caseId(id,type,b) {
  const cycle=type==='completion_overdue'?ms(b.completionReportedAt):type==='corrections_overdue'?ms(b.correctionRequestedAt):ms(b.scheduledDate);
  return crypto.createHash('sha256').update(JSON.stringify([id,type,cycle])).digest('hex');
}
async function openCase({db,id,type,uid='',reason='',now=Date.now(),functions}) {
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  return db.runTransaction(async tx=>{
    const ref=db.doc(`bookings/${id}`),b=(await tx.get(ref)).data();
    if(!b)fail('not-found','Booking not found.');
    if(uid) {
      const actor=(await tx.get(db.doc(`users/${uid}`))).data();
      if(actor?.accountStatus!=='Active'||![b.customerId,b.providerId].includes(uid))fail('permission-denied','Only active participants can report this work.');
      if(reason.length<10||reason.length>3000)fail('invalid-argument','Explain the concern in 10–3000 characters.');
    }
    if(!caseEligibility(b,type,now)) {if(!uid)return null;fail('failed-precondition','This work is not eligible for that follow-up yet. No-shows require an unstarted accepted job at least one hour after its start; completion or correction concerns follow the stated response period.');}
    const cid=caseId(id,type,b),caseRef=db.doc(`workCases/${cid}`),existing=(await tx.get(caseRef)).data();
    if(existing) {
      if(!uid && ['open','reviewing'].includes(existing.status) && ms(existing.lastReminderAt)+86400000<=now) {
        tx.update(caseRef,{lastReminderAt:Timestamp.fromMillis(now)});
        for(const userId of [b.customerId,b.providerId])tx.create(db.collection('notifications').doc(),{userId,title:'Unresolved work reminder',message:'A work follow-up remains open. Review the booking and respond or contact the administrator.',relatedBookingId:id,notificationType:'Work follow-up',isRead:false,createdAt:FieldValue.serverTimestamp()});
      }
      return {caseId:cid,duplicate:true};
    }
    const apply=uid?await require('./rate_limits').quota(tx,db,uid,'work_reports',[[86400000,10]],fail):()=>{};
    apply();
    tx.create(caseRef,{bookingId:id,type,status:'open',customerId:b.customerId,providerId:b.providerId,participantIds:[b.customerId,b.providerId],reportedBy:uid||'system',reason:reason||'A scheduled response or start confirmation has not been recorded. Review with both parties; this is not a finding of fault.',bookingStatusAtReport:b.status,createdAt:FieldValue.serverTimestamp(),lastReminderAt:Timestamp.fromMillis(now)});
    for(const userId of [b.customerId,b.providerId])tx.create(db.collection('notifications').doc(),{userId,title:'Work follow-up opened',message:'A work concern needs a response. Open the booking to review the record. An administrator can review unresolved concerns.',relatedBookingId:id,notificationType:'Work follow-up',isRead:false,createdAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('auditLogs').doc(),{actorId:uid||'system',action:'work_case.open',collection:'workCases',referenceId:cid,bookingId:id,createdAt:FieldValue.serverTimestamp()});
    return {caseId:cid};
  });
}
module.exports=({db,functions})=>({
  command:async(data,context)=>{
    const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
    const uid=context.auth?.uid,id=String(data.bookingId || '');
    if(!uid)fail('unauthenticated','Sign in required.');
    if(data.action==='report') {
      if(!/^[\w-]{1,160}$/.test(id)||!['no_show','completion_overdue','corrections_overdue'].includes(data.type))fail('invalid-argument','Invalid work follow-up.');
      return openCase({db,functions,id,uid,type:data.type,reason:String(data.reason || '').trim()});
    }
    const cid=String(data.caseId || '');if(!/^[a-f0-9]{64}$/.test(cid))fail('invalid-argument','Invalid case reference.');
    return db.runTransaction(async tx=>{
      const actor=(await tx.get(db.doc(`users/${uid}`))).data(),caseRef=db.doc(`workCases/${cid}`),record=(await tx.get(caseRef)).data();
      if(actor?.role!=='Administrator'||actor.accountStatus!=='Active')fail('permission-denied','Administrator access required.');
      await require('./admin_security').assertAdminToken(context,fail,db,tx);
      if(!record)fail('not-found','Follow-up not found.');
      const notes=String(data.notes || '').trim();
      if(notes.length<10||notes.length>3000)fail('invalid-argument','Record the review and reasons in 10–3000 characters.');
      const bookingRef=db.doc(`bookings/${record.bookingId}`),b=(await tx.get(bookingRef)).data();
      if(!b)fail('not-found','Booking not found.');
      if(!['open','reviewing'].includes(record.status))fail('failed-precondition','This follow-up was already resolved.');
      const action=String(data.action),decision=String(data.decision || '');
      if(action!=='review'&&action!=='resolve')fail('invalid-argument','Choose review or resolve.');
      if(action==='resolve'&&!['Discussed with parties','No-show confirmed','Insufficient evidence','Cancelled after review','Other'].includes(decision))fail('invalid-argument','Choose a recorded outcome.');
      let amendmentRef;
      if(action==='resolve'&&decision==='Cancelled after review') {
        if(!['Accepted','In Progress','Awaiting Confirmation'].includes(b.status))fail('failed-precondition','The booking is already closed or has changed. Refresh before resolving.');
        if(b.pendingAmendmentId){amendmentRef=bookingRef.collection('amendments').doc(b.pendingAmendmentId);await tx.get(amendmentRef);}
      }
      const stamp=()=>FieldValue.serverTimestamp();
      if(amendmentRef)tx.set(amendmentRef,{status:'Superseded by cancellation',respondedBy:uid,respondedAt:stamp()},{merge:true});
      if(action==='resolve'&&decision==='Cancelled after review')tx.update(bookingRef,{status:'Cancelled',cancelledAt:stamp(),cancelledByRole:'administrator',cancellationReason:notes,pendingAmendmentId:FieldValue.delete(),updatedBy:uid,updatedByRole:'Administrator',updatedAt:stamp()});
      tx.update(caseRef,{status:action==='review'?'reviewing':'resolved',notes,decision:action==='resolve'?decision:'Review in progress',reviewedBy:uid,updatedAt:stamp(),...(action==='resolve'?{resolvedAt:stamp()}: {})});
      tx.create(caseRef.collection('events').doc(),{action,decision,notes,actorId:uid,createdAt:stamp()});
      tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:`work_case.${action}`,collection:'workCases',referenceId:cid,createdAt:stamp()});
      for(const userId of record.participantIds)tx.create(db.collection('notifications').doc(),{userId,title:'Work follow-up reviewed',message:action==='review'?'An administrator is reviewing the work concern.':`Administrative outcome: ${decision}. Open the booking to read the recorded decision. This does not acknowledge a payment or waive your rights.`,relatedBookingId:record.bookingId,notificationType:'Work follow-up',isRead:false,createdAt:stamp()});
      return {caseId:cid};
    });
  },
  sweep:async()=>{
    const checkpoint=db.doc('maintenance/workCaseSweep'),cursor=(await checkpoint.get()).data()?.cursor;
    let query=db.collection('bookings').orderBy(FieldPath.documentId()).limit(200);if(cursor)query=query.startAfter(cursor);
    const rows=await query.get();
    for(const row of rows.docs)for(const type of ['completion_overdue','start_unconfirmed','corrections_overdue'])if(caseEligibility(row.data(),type))await openCase({db,functions,id:row.id,type});
    await checkpoint.set({cursor:rows.size===200?rows.docs.at(-1).id:'',updatedAt:FieldValue.serverTimestamp()});
    return null;
  },
});
module.exports.caseEligibility=caseEligibility;
