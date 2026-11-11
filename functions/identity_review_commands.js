'use strict';
const {FieldValue}=require('firebase-admin/firestore');
module.exports=({db,functions,refreshIdentity})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid, subject=String(data.subject||''), targetId=String(data.userId||''),action=String(data.action||'');
  if(!uid)fail('unauthenticated','Sign in as an administrator to review identity verification.');
  if(!['customer','provider'].includes(subject)||!['approve','reject'].includes(action)||!/^[\w-]{1,160}$/.test(targetId))fail('invalid-argument','Choose a valid identity application and review action.');
  const actorRef=db.doc('users/'+uid),ownerRef=db.doc('users/'+targetId);
  const targetRef=subject==='customer'?ownerRef:db.doc('serviceProviders/'+targetId);
  async function authorize(tx) {
    const actor=(await (tx?tx.get(actorRef):actorRef.get())).data();
    if(actor?.role!=='Administrator'||actor.accountStatus!=='Active')fail('permission-denied','Sign in with an active Administrator account to review identities.');
    await require('./admin_security').assertAdminToken(context,fail,db,tx);
  }
  await authorize();
  const before=(await targetRef.get()).data();
  if(!before)fail('not-found','Identity application not found.');
  // Approval always reconciles the authoritative hosted result. Rejection does
  // not depend on vendor availability, or on client-supplied reviewer fields.
  if(action==='approve'&&before.verificationProvider==='idanalyzer') {
    if(!before.identitySessionKey)fail('failed-precondition','This application has no linked verification result. Ask the user to restart verification.');
    try {await refreshIdentity(targetId,subject);}catch(error){
      if(error instanceof functions.https.HttpsError)throw error;
      fail(error.code||'unavailable',error.message||'Could not refresh the identity result. Retry.');
    }
  }
  return db.runTransaction(async tx=>{
    await authorize(tx);
    const owner=(await tx.get(ownerRef)).data(),current=(await tx.get(targetRef)).data();
    if(owner?.role!==(subject==='customer'?'Customer':'Provider'))fail('failed-precondition','This identity record does not match the account role. Select the current customer or provider application.');
    if(!current || current.diditSessionId!==before.diditSessionId || current.identitySessionKey!==before.identitySessionKey)fail('aborted','A newer verification attempt started. Refresh the application before reviewing it.');
    if(!current.verificationProvider&&!current.diditStatus)fail('failed-precondition','The user has not submitted identity verification yet.');
    if(action==='approve') {
      if(current.verificationRetakeRequired)fail('failed-precondition','The ID or selfie could not be read clearly. Ask the user to retake verification; this submission cannot be approved.');
      if(current.verificationProvider==='idanalyzer') {
        const session=(await tx.get(db.doc('identitySessions/'+current.identitySessionKey))).data();
        if(!session || session.uid!==targetId || session.subject!==subject || session.reference!==current.diditSessionId
          || !session.completedAt || !session.transactionId || !session.qualityPassed || !['accept','review'].includes(session.decision)) {
          fail('failed-precondition','Complete a readable ID and face verification first. Pending, failed or unreadable submissions cannot be approved.');
        }
      } else if(!['approved','active'].includes(String(current.diditStatus||'').toLowerCase())) {
        fail('failed-precondition','The identity provider must finish and approve this legacy verification first.');
      }
    }
    const decision=action==='approve'?'Approved':'Rejected';
    if(current.verificationManualDecision===decision && current.verificationStatus===decision)return {decision,duplicate:true};
    const stamp=()=>FieldValue.serverTimestamp();
    tx.update(targetRef,{isVerified:action==='approve',verificationStatus:decision,verificationManualDecision:decision,
      verificationReviewedBy:uid,verificationReviewedByRole:'Administrator',verificationReviewedAt:stamp(),
      verificationUpdatedAt:stamp(),updatedAt:stamp(),updatedBy:uid,updatedByRole:'Administrator'});
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:'Administrator',action:'identity.'+action,
      collection:subject==='customer'?'users':'serviceProviders',referenceId:targetId,createdAt:stamp()});
    return {decision};
  });
};
