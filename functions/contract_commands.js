'use strict';
const {FieldValue} = require('firebase-admin/firestore');
const {active} = require('./domain');
module.exports=({db,functions})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid,id=String(data.contractId || '');
  if(!uid) fail('unauthenticated','Sign in required.');
  if(!/^[\w-]{1,300}$/.test(id)) fail('invalid-argument','Invalid contract.');
  return db.runTransaction(async tx=>{
    const actor=(await tx.get(db.doc(`users/${uid}`))).data(),ref=db.doc(`contracts/${id}`),contract=(await tx.get(ref)).data();
    if(actor?.accountStatus !== 'Active' || !contract || ![contract.customerId,contract.providerId].includes(uid)) fail('permission-denied','Only the active contract participants may close it.');
    if(contract.status === 'ended') return {ended:true};
    const bookings=await tx.get(db.collection('bookings').where('contractId','==',id));
    if(bookings.docs.some(d=>active(d.data()) || d.data().status === 'Pending')) fail('failed-precondition','Complete or cancel the outstanding work before closing this contract.');
    tx.update(ref,{status:'ended',endedAt:FieldValue.serverTimestamp(),endedByUserId:uid,endedByRole:uid === contract.customerId ? 'customer' : 'provider',updatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:'contract.end',collection:'contracts',referenceId:id,createdAt:FieldValue.serverTimestamp()});
    return {ended:true};
  });
};
