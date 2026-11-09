'use strict';
const {FieldValue}=require('firebase-admin/firestore');
module.exports=({db,functions})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid;
  if(!uid)fail('unauthenticated','Sign in required.');
  return db.runTransaction(async tx=>{
    const actor=(await tx.get(db.doc(`users/${uid}`))).data();
    if(actor?.accountStatus!=='Active')fail('permission-denied','An active account is required.');
    const stamp=()=>FieldValue.serverTimestamp();
    if(data.action==='resolve') {
      if(actor.role!=='Administrator')fail('permission-denied','Administrator access required.');
      const id=String(data.reportId || ''),status=String(data.status || ''),notes=String(data.adminNotes || '').trim();
      if(!/^[\w-]{1,500}$/.test(id)||!['resolved','dismissed'].includes(status)||notes.length<10||notes.length>3000)fail('invalid-argument','Choose a decision and explain it in 10–3000 characters.');
      const ref=db.doc(`bookingUserReports/${id}`),report=(await tx.get(ref)).data();
      if(!report)fail('not-found','Report not found.');
      if(report.status===status && report.adminNotes===notes)return {reportId:id,duplicate:true};
      tx.update(ref,{status,adminNotes:notes,resolvedAt:stamp(),updatedAt:stamp(),updatedBy:uid});
      tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:'report.resolve',collection:'bookingUserReports',referenceId:id,createdAt:stamp()});
      if(report.reporterId)tx.create(db.collection('notifications').doc(),{userId:report.reporterId,title:'Your report was reviewed',message:`The administrator marked your report ${status}. Contact the administrator if you need to follow up.`,
        relatedBookingId:report.bookingId || '',relatedInquiryId:report.inquiryId || '',notificationType:'Report Update',isRead:false,createdAt:stamp()});
      return {reportId:id};
    }
    if(data.action!=='reportBooking')fail('invalid-argument','Unsupported reporting action.');
    const bookingId=String(data.bookingId || ''),reason=String(data.reason || '').trim(),details=String(data.details || '').trim();
    if(!/^[\w-]{1,160}$/.test(bookingId)||reason.length<3||reason.length>3000||details.length>6000)fail('invalid-argument','Enter a valid booking and concise report details.');
    const b=(await tx.get(db.doc(`bookings/${bookingId}`))).data();
    if(!b||![b.customerId,b.providerId].includes(uid))fail('permission-denied','Only booking participants can report the other party.');
    const other=uid===b.customerId?b.providerId:b.customerId,id=`${bookingId}_${uid}_${other}`,ref=db.doc(`bookingUserReports/${id}`);
    if((await tx.get(ref)).exists)return {reportId:id,duplicate:true};
    const apply=await require('./rate_limits').quota(tx,db,uid,'reports',[[86400000,10]],fail);
    apply();tx.create(ref,{bookingId,reporterId:uid,reportedUserId:other,reporterRole:uid===b.customerId?'customer':'provider',reportedRole:uid===b.customerId?'provider':'customer',reason,details,status:'open',createdAt:stamp(),adminNotes:''});
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:'booking.report',collection:'bookingUserReports',referenceId:id,createdAt:stamp()});
    return {reportId:id};
  });
};
