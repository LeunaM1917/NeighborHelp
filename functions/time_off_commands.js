'use strict';
const {Timestamp,FieldValue}=require('firebase-admin/firestore');
const {active}=require('./domain');
const {periods}=require('./scheduling');
module.exports=({db,functions})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid,id=String(data.blockId || '');
  if(!uid)fail('unauthenticated','Sign in required.');
  if(!/^[\w-]{1,100}$/.test(id))fail('invalid-argument','Invalid time-off reference.');
  return db.runTransaction(async tx=>{
    const actor=(await tx.get(db.doc(`users/${uid}`))).data(),ref=db.doc(`serviceProviders/${uid}`),profile=(await tx.get(ref)).data();
    if(actor?.role!=='Provider'||actor.accountStatus!=='Active'||!profile)fail('permission-denied','An active provider account is required.');
    const lock=db.doc(`providerSchedules/${uid}`);await tx.get(lock);
    const now=Date.now(),blocks=(profile.timeOff || []).filter(b=>b.end?.toMillis?.()>now);
    const existing=blocks.find(b=>b.id===id);
    if(data.action==='add'){
      const start=Number(data.start),end=Number(data.end),label=String(data.label || '').trim();
      const today=Math.floor((now+8*3600000)/86400000)*86400000-8*3600000;
      if(!Number.isFinite(start)||!Number.isFinite(end)||start<today||end<=now||end<=start||end>now+366*86400000||end-start>90*86400000||label.length>120)fail('invalid-argument','Choose future unavailable hours within one year, up to 90 days per block.');
      if(existing){if(existing.start.toMillis()===start&&existing.end.toMillis()===end&&existing.label===label)return {blockId:id,duplicate:true};fail('already-exists','This time-off reference is already used.');}
      if(blocks.length>=100)fail('resource-exhausted','Keep up to 100 future time-off blocks.');
      const jobs=await tx.get(db.collection('bookings').where('providerId','==',uid));
      if(jobs.docs.some(d=>active(d.data())&&periods(d.data()).some(p=>Math.max(start,now)<p.end&&p.start<end)))fail('failed-precondition','Accepted work overlaps these unavailable hours. Discuss and amend or cancel it before adding time off.');
      blocks.push({id,start:Timestamp.fromMillis(start),end:Timestamp.fromMillis(end),label,createdAt:Timestamp.now()});
    }else if(data.action==='remove'){
      if(!existing)return {blockId:id,duplicate:true};
    }else fail('invalid-argument','Choose add or remove time off.');
    const next=data.action==='remove'?blocks.filter(b=>b.id!==id):blocks;
    tx.update(ref,{timeOff:next,updatedBy:uid,updatedAt:FieldValue.serverTimestamp()});
    tx.set(lock,{version:FieldValue.increment(1),updatedAt:FieldValue.serverTimestamp()},{merge:true});
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:`time_off.${data.action}`,collection:'serviceProviders',referenceId:uid,blockId:id,createdAt:FieldValue.serverTimestamp()});
    return {blockId:id};
  });
};
