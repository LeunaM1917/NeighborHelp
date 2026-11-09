'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const fromFunctions=require('node:module').createRequire(path.resolve(__dirname,'../functions/package.json'));
const admin=fromFunctions('firebase-admin');
const {getFirestore,Timestamp,GeoPoint}=fromFunctions('firebase-admin/firestore');
const [stage,directory]=process.argv.slice(2);
const projectId='demo-neighborhelp-recovery';
if(!['write','verify'].includes(stage)||!directory)throw Error('Supply write/verify and a local evidence directory.');
if(!/^(127\.0\.0\.1|localhost):8188$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')||process.env.GCLOUD_PROJECT!==projectId)throw Error('Recovery fixtures are restricted to the local demo recovery emulator.');
const app=admin.initializeApp({projectId}),db=getFirestore(app);
const fixture={
  'users/customer':{role:'Customer',accountStatus:'Active',fullName:'Synthetic recovery customer'},
  'users/provider':{role:'Provider',accountStatus:'Active',fullName:'Synthetic recovery provider'},
  'bookings/job':{customerId:'customer',providerId:'provider',status:'Cancelled',totalFee:1000,confirmedPaymentCents:70000,confirmedRefundCents:20000,location:new GeoPoint(7.3,125.6),scheduledDate:Timestamp.fromMillis(1794190000000),settlement:{agreedFeeCents:50000}},
  'contracts/job':{customerId:'customer',providerId:'provider',agreement:{hash:'synthetic-fingerprint',text:'Fixture agreement only'}},
  'bookings/job/payments/paid':{recordType:'payment',status:'Received',amountCents:70000},
  'bookings/job/payments/refund':{recordType:'refund',status:'Received',amountCents:20000},
  'bookings/job/settlements/agreed':{status:'Accepted',agreedFeeCents:50000,agreement:{text:'Synthetic settlement',hash:'synthetic-settlement-hash'}},
  'bookings/job/agreementVersions/0':{agreement:{text:'Original fixture',hash:'synthetic-fingerprint'}},
  'workCases/case':{bookingId:'job',participantIds:['customer','provider'],status:'resolved',notes:'Synthetic reviewed concern'},
  'inquiries/thread':{participantIds:['customer','provider'],blockedBy:['customer']},
  'inquiries/thread/messages/message':{senderId:'customer',text:'Synthetic private fixture message'},
  'auditLogs/event':{actorId:'system',action:'recovery.fixture',referenceId:'job'},
};
function plain(value){if(value instanceof Timestamp)return {timestamp:value.toMillis()};if(value instanceof GeoPoint)return {latitude:value.latitude,longitude:value.longitude};if(Array.isArray(value))return value.map(plain);if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(key=>[key,plain(value[key])]));return value;}
const digest=value=>crypto.createHash('sha256').update(JSON.stringify(plain(value))).digest('hex');
(async()=>{
  fs.mkdirSync(directory,{recursive:true});
  if(stage==='write'){
    const batch=db.batch();for(const [id,value] of Object.entries(fixture))batch.create(db.doc(id),value);await batch.commit();
    fs.writeFileSync(path.join(directory,'expected.json'),JSON.stringify({sha256:digest(fixture),documents:Object.keys(fixture)}));
    console.log(`Wrote ${Object.keys(fixture).length} synthetic documents for an actual emulator export.`);
  }else{
    const expected=JSON.parse(fs.readFileSync(path.join(directory,'expected.json'),'utf8')),restored={};
    for(const id of expected.documents){const snap=await db.doc(id).get();assert.ok(snap.exists,`Restored document missing: ${id}`);restored[id]=snap.data();}
    assert.equal(digest(restored),expected.sha256,'Restored values differ from exported fixture.');
    assert.equal(restored['bookings/job'].confirmedPaymentCents-restored['bookings/job'].confirmedRefundCents,restored['bookings/job/settlements/agreed'].agreedFeeCents);
    const evidence={performedAt:new Date().toISOString(),kind:'actual_local_emulator_export_import',projectId,restoredDocuments:expected.documents.length,sha256:expected.sha256,valuesVerified:true,financialBalanceVerified:true,originalAgreementVerified:true,cloudRestorePerformed:false,limitations:['Synthetic local Firestore data only. Does not restore Auth users, Storage blobs or prove cloud backup readiness.']};
    fs.writeFileSync(path.join(directory,'result.json'),JSON.stringify(evidence,null,2)+'\n');console.log(JSON.stringify(evidence));
  }
  await app.delete();
})().catch(error=>{console.error(error.message);process.exitCode=1;});
