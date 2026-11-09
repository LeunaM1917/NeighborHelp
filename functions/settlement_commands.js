'use strict';
const crypto=require('node:crypto');
const {FieldValue}=require('firebase-admin/firestore');
const {complete}=require('./domain');
const finances=b=>({paid:b.confirmedPaymentCents || 0,refunded:b.confirmedRefundCents || 0});
module.exports=({db,functions})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid,id=String(data.bookingId || ''),sid=String(data.settlementId || '');
  if(!uid)fail('unauthenticated','Sign in required.');
  if(!/^[\w-]{1,160}$/.test(id)||!/^[\w-]{1,100}$/.test(sid))fail('invalid-argument','Invalid settlement reference.');
  const ref=db.doc(`bookings/${id}`),recordRef=ref.collection('settlements').doc(sid),stamp=()=>FieldValue.serverTimestamp();
  return db.runTransaction(async tx=>{
    const actor=(await tx.get(db.doc(`users/${uid}`))).data(),b=(await tx.get(ref)).data(),record=(await tx.get(recordRef)).data();
    if(actor?.accountStatus!=='Active'||!b||![b.customerId,b.providerId].includes(uid))fail('permission-denied','Only active booking participants can agree a settlement.');
    if(!b.contractId||!(complete(b)||String(b.status).toLowerCase()==='cancelled'))fail('failed-precondition','Complete or cancel the work before agreeing a final settlement.');
    const action=String(data.action),state=finances(b);
    if(action==='preview'||action==='propose') {
      if(record) {if(record.proposedBy===uid && record.agreement.hash===data.agreementHash)return {settlementId:sid,duplicate:true};fail('already-exists','This settlement reference is already used.');}
      if(b.pendingSettlementId)fail('failed-precondition','Respond to or withdraw the current settlement first.');
      if(b.pendingPaymentCents||b.pendingRefundCents)fail('failed-precondition','Resolve unacknowledged payments and refunds before proposing a settlement.');
      const amount=Number(data.agreedWorkAmount),cents=Math.round(amount*100),details={};
      if(!Number.isFinite(amount)||cents<0||Math.abs(amount*100-cents)>1e-6||cents>Math.round((b.totalFee || 0)*100))fail('invalid-argument','The agreed fee must be between zero and the original agreed labour fee, with at most two decimal places.');
      for(const key of ['workCompleted','materialsReturned','reason']) {
        const value=String(data[key] || '').trim();
        if(value.length<10||value.length>3000)fail('invalid-argument',`Describe ${key} in 10–3000 characters.`);
        details[key]=value;
      }
      const net=state.paid-state.refunded,balanceDue=Math.max(0,cents-net),refundDue=Math.max(0,net-cents);
      const text=`NEIGHBORHELP FINAL WORK SETTLEMENT\nBooking: ${id}\nSettlement: ${sid}\nOriginal agreement fingerprint: ${b.agreement?.hash || 'Historical agreement'}\nCustomer: ${b.customerId}\nProvider: ${b.providerId}\nRecorded job status: ${b.status}\nOriginal labour fee: PHP ${(Number(b.totalFee)||0).toFixed(2)}\nAgreed final labour fee: PHP ${(cents/100).toFixed(2)}\nPreviously acknowledged payments: PHP ${(state.paid/100).toFixed(2)}\nPreviously acknowledged refunds: PHP ${(state.refunded/100).toFixed(2)}\nBalance due from customer: PHP ${(balanceDue/100).toFixed(2)}\nRefund due from provider: PHP ${(refundDue/100).toFixed(2)}\nWork completed: ${details.workCompleted}\nMaterials supplied/returned: ${details.materialsReturned}\nReason and outstanding concerns: ${details.reason}\n\nBoth parties must voluntarily accept this exact record. A proposal does not change the accepted agreement or prove a payment or refund was made. Only the other party's explicit acceptance records the revised final labour fee. Every version remains on record. Money is paid directly; actual receipt is acknowledged separately. No automatic forfeiture, platform transfer, waiver of mandatory rights or legal determination is created. Disputed amounts and statutory remedies remain available.`;
      const agreement={version:'NH-SETTLEMENT-v1',text,hash:crypto.createHash('sha256').update(text).digest('hex')};
      if(action==='preview')return {agreement,balanceDueCents:balanceDue,refundDueCents:refundDue};
      if(data.acceptAgreement!==true||data.agreementHash!==agreement.hash)fail('failed-precondition','Preview and voluntarily accept this exact settlement first.');
      tx.create(recordRef,{...details,agreedFeeCents:cents,financialSnapshot:state,balanceDueCents:balanceDue,refundDueCents:refundDue,agreement,status:'Proposed',proposedBy:uid,proposedAt:stamp()});
      tx.update(ref,{pendingSettlementId:sid,updatedAt:stamp()});
    }else {
      if(!record||record.status!=='Proposed'||b.pendingSettlementId!==sid)fail('failed-precondition','No settlement is awaiting this response.');
      if(action==='accept') {
        if(record.proposedBy===uid||data.acceptAgreement!==true||data.agreementHash!==record.agreement.hash)fail('failed-precondition','The other participant must accept this exact settlement.');
        if(b.pendingPaymentCents||b.pendingRefundCents||state.paid!==record.financialSnapshot.paid||state.refunded!==record.financialSnapshot.refunded)fail('failed-precondition','Payment records changed. Withdraw this proposal and prepare an updated settlement.');
        const other=record.proposedBy;
        if((await tx.get(db.doc(`users/${other}`))).data()?.accountStatus!=='Active')fail('failed-precondition','Both parties must be active. Contact the administrator for an unresolved case.');
        tx.update(recordRef,{status:'Accepted',acceptedBy:uid,acceptedAt:stamp()});
        tx.update(ref,{settlement:{settlementId:sid,agreedFeeCents:record.agreedFeeCents,agreementHash:record.agreement.hash,acceptedAt:stamp()},pendingSettlementId:FieldValue.delete(),updatedAt:stamp()});
      }else if(action==='decline'||action==='withdraw') {
        if((action==='withdraw')!==(record.proposedBy===uid))fail('permission-denied','Only the proposer may withdraw; the other party may decline.');
        tx.update(recordRef,{status:action==='withdraw'?'Withdrawn':'Declined',respondedBy:uid,respondedAt:stamp()});
        tx.update(ref,{pendingSettlementId:FieldValue.delete(),updatedAt:stamp()});
      }else fail('invalid-argument','Unsupported settlement action.');
    }
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:`settlement.${action}`,collection:'bookings',referenceId:id,settlementId:sid,createdAt:stamp()});
    tx.create(db.collection('notifications').doc(),{userId:uid===b.customerId?b.providerId:b.customerId,title:'Work settlement update',message:`A final work settlement was ${action==='propose'?'proposed for your review':action==='accept'?'accepted':action==='decline'?'declined':'withdrawn'}. Open the booking to review the record.`,relatedBookingId:id,notificationType:'Settlement',isRead:false,createdAt:stamp()});
    return {settlementId:sid};
  });
};
