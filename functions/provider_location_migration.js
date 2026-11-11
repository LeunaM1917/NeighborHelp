'use strict';
const {FieldValue,FieldPath,GeoPoint}=require('firebase-admin/firestore');
const {publicArea}=require('./provider_area');
// Local/administrator maintenance only. Never infer a user's base from a home pin.
module.exports=async function migrate(db,{cursor='',apply=false}={}) {
  let query=db.collection('serviceProviders').orderBy(FieldPath.documentId()).limit(100);
  if(cursor)query=query.startAfter(cursor);
  const rows=await query.get();let scrubbed=0,selected=0,needsSelection=0;
  for(const doc of rows.docs) {
    if(publicArea(doc.data()))selected++;else needsSelection++;
    if(!apply)continue;
    await db.runTransaction(async tx=>{
      const p=(await tx.get(doc.ref)).data(),uRef=db.doc(`users/${doc.id}`),u=(await tx.get(uRef)).data();
      const area=publicArea(p),patch={serviceRadiusKm:FieldValue.delete(),updatedAt:FieldValue.serverTimestamp(),updatedBy:'system'};
      if(area)Object.assign(patch,area,{location:new GeoPoint(area.location.latitude,area.location.longitude)});
      else Object.assign(patch,{location:FieldValue.delete(),serviceArea:'',baseBarangayId:FieldValue.delete(),serviceBarangayIds:[],locationPolicyVersion:0});
      tx.update(doc.ref,patch);
      if(u?.role==='Provider')tx.update(uRef,{location:FieldValue.delete()});
      // Projection trigger will republish selected, eligible providers safely.
      tx.delete(db.doc(`publicProviders/${doc.id}`));
    });scrubbed++;
  }
  return {apply,scanned:rows.size,selected,needsSelection,scrubbed,cursor:rows.docs.at(-1)?.id||'',hasMore:rows.size===100};
};
