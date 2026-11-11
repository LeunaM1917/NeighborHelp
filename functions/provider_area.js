'use strict';
const {GeoPoint,FieldValue}=require('firebase-admin/firestore');
const catalog=require('./panabo_barangays.json');
const byId=new Map(catalog.barangays.map(b=>[b.id,b]));
const base=p=>byId.get(p?.baseBarangayId);
function selected(p) {return Array.isArray(p?.serviceBarangayIds) && p.serviceBarangayIds.length>0 && p.serviceBarangayIds.every(id=>byId.has(id));}
function inRing(point,ring) {
  let inside=false;const x=point.longitude,y=point.latitude;
  for(let i=0,j=ring.length-1;i<ring.length;j=i++) {
    const [xi,yi]=ring[i],[xj,yj]=ring[j];
    if((yi>y)!==(yj>y) && x<(xj-xi)*(y-yi)/(yj-yi)+xi) inside=!inside;
  }
  return inside;
}
function covers(p,point) {return selected(p) && p.serviceBarangayIds.some(id=>byId.get(id).polygons.some(rings=>inRing(point,rings[0])&&!rings.slice(1).some(r=>inRing(point,r))));}
const publicArea=p=>{
  const b=base(p);if(!b || !selected(p))return null;
  return {baseBarangayId:b.id,serviceBarangayIds:[...new Set(p.serviceBarangayIds)].sort(),locationPolicyVersion:1,
    locationPrecision:'barangay',location:{latitude:b.latitude,longitude:b.longitude},serviceArea:`${b.name}, Panabo City (approximate base)`};
};
function command({db,functions}) {return async(data,context)=>{
  const fail=(code,msg)=>{throw new functions.https.HttpsError(code,msg);};
  const uid=context.auth?.uid;if(!uid)fail('unauthenticated','Sign in required.');
  const area=publicArea(data);
  if(!area || data.serviceBarangayIds.length>40 || new Set(data.serviceBarangayIds).size!==data.serviceBarangayIds.length)fail('invalid-argument','Choose a base barangay and at least one service barangay in Panabo City.');
  return db.runTransaction(async tx=>{
    const userRef=db.doc(`users/${uid}`),ref=db.doc(`serviceProviders/${uid}`);
    const u=(await tx.get(userRef)).data(),p=(await tx.get(ref)).data();
    if(u?.role!=='Provider'||u.accountStatus!=='Active'||!p)fail('permission-denied','An active provider account is required.');
    tx.update(ref,{...area,location:new GeoPoint(area.location.latitude,area.location.longitude),serviceRadiusKm:FieldValue.delete(),updatedAt:FieldValue.serverTimestamp(),updatedBy:uid});
    tx.update(userRef,{location:FieldValue.delete(),updatedAt:FieldValue.serverTimestamp(),updatedBy:uid});
    tx.create(db.collection('auditLogs').doc(),{action:'provider.selectBarangays',actorId:uid,collection:'serviceProviders',referenceId:uid,createdAt:FieldValue.serverTimestamp()});
    return {saved:true};
  });
};}
module.exports={base,selected,covers,publicArea,command};
