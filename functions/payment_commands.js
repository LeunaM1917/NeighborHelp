'use strict';
const {FieldValue}=require('firebase-admin/firestore');
module.exports=({db,functions})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid, id=String(data.bookingId || ''),paymentId=String(data.paymentId || '');
  if(!uid) fail('unauthenticated','Sign in required.');
  if(!/^[\w-]{1,160}$/.test(id)||!/^[\w-]{1,100}$/.test(paymentId)) fail('invalid-argument','Invalid payment reference.');
  const ref=db.doc(`bookings/${id}`),paymentRef=ref.collection('payments').doc(paymentId),stamp=()=>FieldValue.serverTimestamp();
  return db.runTransaction(async tx=>{
    const actor=(await tx.get(db.doc(`users/${uid}`))).data(),b=(await tx.get(ref)).data(),payment=(await tx.get(paymentRef)).data();
    if(actor?.accountStatus!=='Active'||!b||![b.customerId,b.providerId].includes(uid)) fail('permission-denied','Only active booking participants can record payments.');
    if(!b.contractId) fail('failed-precondition','Accept the contract before recording payments.');
    const action=String(data.action);
    if(action==='report') {
      if(uid!==b.customerId) fail('permission-denied','The customer reports a payment; the provider confirms receipt.');
      if(payment) return {paymentId,duplicate:true};
      const amount=Number(data.amount), cents=Math.round(amount*100), method=String(data.method || '');
      if(!Number.isFinite(amount)||cents<=0||Math.abs(amount*100-cents)>0.000001 || !['Cash','GCash','Bank transfer','Other'].includes(method)) fail('invalid-argument','Enter a positive amount with at most two decimals and a payment method.');
      if(cents+(b.confirmedPaymentCents || 0)+(b.pendingPaymentCents || 0)>Math.round((b.totalFee || 0)*100)) fail('failed-precondition','This amount exceeds the remaining agreed fee after received and pending payments. Amend the contract first if needed.');
      const reference=String(data.reference || '').trim();
      if(reference.length>200) fail('invalid-argument','Keep the payment reference under 200 characters.');
      tx.create(paymentRef,{amountCents:cents,method,reference,status:'Reported',reportedBy:uid,reportedAt:stamp()});
      tx.update(ref,{pendingPaymentCents:FieldValue.increment(cents),updatedAt:stamp()});
    } else {
      if(!payment) fail('not-found','Payment record not found.');
      if(payment.status!=='Reported') fail('failed-precondition','This payment has already been resolved.');
      if(action==='confirm') {
        if(uid!==b.providerId||data.confirmReceived!==true) fail('permission-denied','The provider must confirm they actually received this amount.');
        tx.update(paymentRef,{status:'Received',confirmedBy:uid,confirmedAt:stamp()});
        tx.update(ref,{confirmedPaymentCents:FieldValue.increment(payment.amountCents),pendingPaymentCents:FieldValue.increment(-payment.amountCents),updatedAt:stamp()});
      } else if(action==='dispute' || action==='withdraw') {
        if(action==='dispute' ? uid!==b.providerId : uid!==b.customerId) fail('permission-denied','Only the appropriate participant may respond.');
        const reason=String(data.reason || '').trim();
        if(reason.length<10||reason.length>3000) fail('invalid-argument','Explain the correction in 10–3000 characters.');
        tx.update(paymentRef,{status:action==='dispute'?'Disputed':'Withdrawn',reason,respondedBy:uid,respondedAt:stamp()});
        tx.update(ref,{pendingPaymentCents:FieldValue.increment(-payment.amountCents),updatedAt:stamp()});
      } else fail('invalid-argument','Unsupported payment action.');
    }
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:`payment.${action}`,collection:'bookings',referenceId:id,paymentId,createdAt:stamp()});
    tx.create(db.collection('notifications').doc(),{userId:uid===b.customerId?b.providerId:b.customerId,title:'Payment record update',message:`A payment was ${action==='report'?'reported for confirmation':action==='confirm'?'acknowledged as received':action==='dispute'?'disputed':'withdrawn'}.`,relatedBookingId:id,notificationType:'Payment',isRead:false,createdAt:stamp()});
    return {paymentId};
  });
};
