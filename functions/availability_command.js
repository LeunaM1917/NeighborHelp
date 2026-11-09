'use strict';
const {requestedWindow,availability} = require('./scheduling');
module.exports=({db,functions})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid;
  if(!uid) fail('unauthenticated','Sign in required.');
  const user=(await db.doc(`users/${uid}`).get()).data();
  if(user?.accountStatus!=='Active') fail('permission-denied','An active account is required.');
  if(!Array.isArray(data.providerIds)) fail('invalid-argument','Choose providers to check.');
  const ids=[...new Set(data.providerIds)];
  if(!ids.length || ids.length>30 || ids.some(id=>typeof id!=='string'|| !/^[\w-]{1,160}$/.test(id))) fail('invalid-argument','Choose 1–30 providers per availability check.');
  const request=requestedWindow(data,fail);
  await db.runTransaction(async tx=>{const apply=await require('./rate_limits').quota(tx,db,uid,'availability',[[60000,60]],fail);apply();});
  const results=await Promise.all(ids.map(async id=>{
    const [profile,owner,jobs,projection]=await Promise.all([db.doc(`serviceProviders/${id}`).get(),db.doc(`users/${id}`).get(),db.collection('bookings').where('providerId','==',id).get(),db.doc(`publicProviders/${id}`).get()]);
    if(!projection.exists || !profile.data()?.isVerified || owner.data()?.accountStatus!=='Active') return [id,{available:false,reason:'Provider unavailable.'}];
    return [id,availability(profile.data(),request,jobs.docs.map(d=>d.data()))];
  }));
  return {providers:Object.fromEntries(results),checkedAt:Date.now(),travelBufferMinutes:15};
};
