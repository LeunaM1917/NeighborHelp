'use strict';
const {requestedWindow,availability,coversSchedule,minutes,periods} = require('./scheduling');
module.exports=({db,functions})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid;
  if(!uid) fail('unauthenticated','Sign in required.');
  const user=(await db.doc(`users/${uid}`).get()).data();
  if(user?.accountStatus!=='Active') fail('permission-denied','An active account is required.');
  if(!Array.isArray(data.providerIds)) fail('invalid-argument','Choose providers to check.');
  const ids=[...new Set(data.providerIds)];
  if(!ids.length || ids.length>30 || ids.some(id=>typeof id!=='string'|| !/^[\w-]{1,160}$/.test(id))) fail('invalid-argument','Choose 1–30 providers per availability check.');
  await db.runTransaction(async tx=>{const apply=await require('./rate_limits').quota(tx,db,uid,'availability',[[60000,60]],fail);apply();});
  if(data.action==='slots')return require('./booking_slots').command({db,data,uid,user,fail});
  if(data.action==='saveSchedule') {
    if(user.role!=='Provider'||ids.length!==1||ids[0]!==uid)fail('permission-denied','Only the provider can save their working hours.');
    const schedule=data.weeklyAvailability;
    const names=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    if(!schedule||names.some(day=>!schedule[day]||typeof schedule[day].enabled!=='boolean'||minutes(schedule[day].start)==null||minutes(schedule[day].end)==null||schedule[day].enabled&&minutes(schedule[day].start)===minutes(schedule[day].end)))fail('invalid-argument','Choose valid hours for every working day.');
    const clean=Object.fromEntries(names.map(day=>[day,{enabled:schedule[day].enabled,start:schedule[day].start,end:schedule[day].end}]));
    return db.runTransaction(async tx=>{
      const current=(await tx.get(db.doc(`users/${uid}`))).data();
      if(current?.role!=='Provider'||current.accountStatus!=='Active')fail('permission-denied','An active provider account is required.');
      const ref=db.doc(`serviceProviders/${uid}`),profile=(await tx.get(ref)).data();
      if(!profile)fail('not-found','Provider profile not found.');
      const lock=db.doc(`providerSchedules/${uid}`);await tx.get(lock);
      const jobs=await tx.get(db.collection('bookings').where('providerId','==',uid));
      if(jobs.docs.some(d=>require('./domain').active(d.data())&&periods(d.data()).some(p=>p.end>Date.now())&&!coversSchedule({...profile,weeklyAvailability:clean},d.data())))fail('failed-precondition','These hours exclude accepted work. Amend or cancel that booking before changing working hours.');
      const {FieldValue}=require('firebase-admin/firestore');
      tx.update(ref,{weeklyAvailability:clean,updatedAt:FieldValue.serverTimestamp(),updatedBy:uid});
      tx.set(lock,{version:FieldValue.increment(1),updatedAt:FieldValue.serverTimestamp()},{merge:true});
      return {saved:true};
    });
  }
  const request=requestedWindow(data,fail);
  const results=await Promise.all(ids.map(async id=>{
    const [profile,owner,jobs,projection]=await Promise.all([db.doc(`serviceProviders/${id}`).get(),db.doc(`users/${id}`).get(),db.collection('bookings').where('providerId','==',id).get(),db.doc(`publicProviders/${id}`).get()]);
    if(!projection.exists || !profile.data()?.isVerified || owner.data()?.accountStatus!=='Active') return [id,{available:false,reason:'Provider unavailable.'}];
    return [id,availability(profile.data(),request,jobs.docs.map(d=>d.data()))];
  }));
  return {providers:Object.fromEntries(results),checkedAt:Date.now(),travelBufferMinutes:15};
};
