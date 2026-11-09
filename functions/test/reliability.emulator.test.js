'use strict';
const {before,after,beforeEach,test}=require('node:test'),assert=require('node:assert/strict');
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const admin=require('firebase-admin'),functions=require('firebase-functions/v1');
const {initializeTestEnvironment}=require('@firebase/rules-unit-testing');
let env,app,db,settlement,payment,cases;
const auth=(uid,token={email_verified:true})=>({auth:{uid,token}}),stamp=ms=>Timestamp.fromMillis(ms);
before(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Demo emulator required.');
  env=await initializeTestEnvironment({projectId:'demo-neighborhelp'});app=admin.initializeApp({projectId:'demo-neighborhelp'},'reliability-tests');db=getFirestore(app);
  settlement=require('../settlement_commands')({db,functions});payment=require('../payment_commands')({db,functions});cases=require('../work_cases')({db,functions});
});
after(async()=>{await require('firebase-admin/app').deleteApp(app);await env?.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore();delete process.env.REQUIRE_ADMIN_MFA;
  for(const [id,role] of [['c','Customer'],['p','Provider'],['s','Customer'],['a','Administrator']])await db.doc(`users/${id}`).set({role,accountStatus:'Active'});
  await db.doc('bookings/b').set({customerId:'c',providerId:'p',contractId:'b',status:'Cancelled',totalFee:1000,confirmedPaymentCents:70000,confirmedRefundCents:0,pendingPaymentCents:0,agreement:{hash:'original',text:'Original terms'},scheduledDate:stamp(Date.now()-3*3600000)});
});
async function propose(amount=500,extra={},uid='c',sid='one'){
  const payload={bookingId:'b',settlementId:sid,agreedWorkAmount:amount,workCompleted:'One room cleaned before cancellation.',materialsReturned:'Customer materials returned in full.',reason:'Both parties discussed the unfinished work.',...extra};
  const preview=await settlement({action:'preview',...payload},auth(uid));
  await settlement({action:'propose',...payload,acceptAgreement:true,agreementHash:preview.agreement.hash},auth(uid));return preview;
}
async function accept(preview,uid='p',sid='one'){return settlement({action:'accept',bookingId:'b',settlementId:sid,acceptAgreement:true,agreementHash:preview.agreement.hash},auth(uid));}
test('settlement preserves the contract and requires the other party to accept the exact record',async()=>{
  const preview=await propose();assert.equal(preview.refundDueCents,20000);assert.equal(preview.balanceDueCents,0);
  await assert.rejects(accept(preview,'c'),/other participant/);
  await assert.rejects(accept({agreement:{hash:'wrong'}}),/exact settlement/);
  await accept(preview);
  const b=(await db.doc('bookings/b').get()).data();assert.equal(b.totalFee,1000);assert.equal(b.agreement.hash,'original');assert.equal(b.settlement.agreedFeeCents,50000);
  assert.equal((await db.doc('bookings/b/settlements/one').get()).data().status,'Accepted');
});
test('rejected or withdrawn settlement leaves original amounts and evidence unchanged',async()=>{
  await propose();await settlement({action:'decline',bookingId:'b',settlementId:'one'},auth('p'));
  assert.equal((await db.doc('bookings/b').get()).data().settlement,undefined);
  await propose(400,{},'p','two');await settlement({action:'withdraw',bookingId:'b',settlementId:'two'},auth('p'));
  assert.equal((await db.doc('bookings/b/settlements/one').get()).data().status,'Declined');
});
test('settlement rejects unclosed work, unsupported charges, pending receipts and unrelated users',async()=>{
  await assert.rejects(propose(1100),/original agreed/);
  await assert.rejects(propose(500,{},'s'),/participants/);
  await db.doc('bookings/b').update({pendingPaymentCents:100});await assert.rejects(propose(),/unacknowledged/);
  await db.doc('bookings/b').update({pendingPaymentCents:0,status:'In Progress'});await assert.rejects(propose(),/Complete or cancel/);
});
test('payment changes invalidate a settlement snapshot and pending proposals freeze new receipts',async()=>{
  const preview=await propose();await assert.rejects(payment({action:'report',bookingId:'b',paymentId:'more',amount:1,method:'Cash'},auth('c')),/pending settlement/);
  await db.doc('bookings/b').update({confirmedPaymentCents:80000});await assert.rejects(accept(preview),/records changed/);
});
test('only customer acknowledgment records a refund, once, without changing job completion or gross payments',async()=>{
  await accept(await propose());
  const report={action:'reportRefund',bookingId:'b',paymentId:'refund',amount:200,method:'Cash'};
  await assert.rejects(payment(report,auth('c')),/provider/);await payment(report,auth('p'));await payment(report,auth('p'));
  await assert.rejects(payment({action:'confirm',bookingId:'b',paymentId:'refund',confirmReceived:true},auth('p')),/refund response/);
  await assert.rejects(payment({action:'confirmRefund',bookingId:'b',paymentId:'refund',confirmReceived:true},auth('p')),/customer/);
  const responses=await Promise.allSettled([1,2].map(()=>payment({action:'confirmRefund',bookingId:'b',paymentId:'refund',confirmReceived:true},auth('c'))));
  assert.equal(responses.filter(r=>r.status==='fulfilled').length,1);
  const b=(await db.doc('bookings/b').get()).data();assert.equal(b.confirmedPaymentCents,70000);assert.equal(b.confirmedRefundCents,20000);assert.equal(b.pendingRefundCents,0);assert.equal(b.status,'Cancelled');
});
test('concurrent refund reports cannot exceed the refund due and disputed refunds release the reservation',async()=>{
  await accept(await propose());
  const reports=await Promise.allSettled(['one','two'].map(paymentId=>payment({action:'reportRefund',bookingId:'b',paymentId,amount:150,method:'GCash'},auth('p'))));
  assert.equal(reports.filter(r=>r.status==='fulfilled').length,1);
  const receipt=(await db.collection('bookings/b/payments').get()).docs[0];
  await payment({action:'disputeRefund',bookingId:'b',paymentId:receipt.id,reason:'The refund has not reached my account.'},auth('c'));
  assert.equal((await db.doc('bookings/b').get()).data().pendingRefundCents,0);
  await payment({action:'reportRefund',bookingId:'b',paymentId:'corrected',amount:200,method:'Cash'},auth('p'));
});
test('after a settlement the remaining customer balance is capped at the agreed final fee',async()=>{
  await accept(await propose(800));await payment({action:'report',bookingId:'b',paymentId:'remaining',amount:100,method:'Cash'},auth('c'));
  await assert.rejects(payment({action:'report',bookingId:'b',paymentId:'extra',amount:1,method:'Cash'},auth('c')),/exceeds/);
});
test('overdue completion opens one follow-up without completing work or claiming payment',async()=>{
  await db.doc('bookings/b').update({status:'Awaiting Confirmation',completionReportedAt:stamp(Date.now()-73*3600000),completionResponseDueAt:stamp(Date.now()-3600000)});
  await cases.sweep();await cases.sweep();assert.equal((await db.collection('workCases').get()).size,1);assert.equal((await db.collection('notifications').get()).size,2);
  const b=(await db.doc('bookings/b').get()).data();assert.equal(b.status,'Awaiting Confirmation');assert.equal(b.completedAt,undefined);assert.equal(b.confirmedPaymentCents,70000);
});
test('no-show reports require an accepted unstarted job past its grace period and actual participants',async()=>{
  await db.doc('bookings/b').update({status:'Accepted',scheduledDate:stamp(Date.now()+3600000)});
  const data={action:'report',bookingId:'b',type:'no_show',reason:'The other party has not arrived for the work.'};
  await assert.rejects(cases.command(data,auth('c')),/not eligible/);
  await db.doc('bookings/b').update({scheduledDate:stamp(Date.now()-2*3600000)});
  await assert.rejects(cases.command(data,auth('s')),/participants/);
  const result=await cases.command(data,auth('c'));assert.equal((await db.doc(`workCases/${result.caseId}`).get()).data().status,'open');
  assert.equal((await db.doc('bookings/b').get()).data().status,'Accepted');
});
test('admin review requires verified email, supports recorded cancellation, and cannot confirm money or completion',async()=>{
  await db.doc('bookings/b').update({status:'Accepted'});
  const {caseId}=await cases.command({action:'report',bookingId:'b',type:'no_show',reason:'The other party has not arrived for the work.'},auth('c'));
  const response={action:'resolve',caseId,decision:'Cancelled after review',notes:'Reviewed both parties and recorded agreed cancellation.'};
  await assert.rejects(cases.command(response,auth('a',{})),/Verify/);
  await assert.rejects(cases.command(response,auth('p')),/Administrator/);
  await cases.command(response,auth('a'));
  const b=(await db.doc('bookings/b').get()).data();assert.equal(b.status,'Cancelled');assert.equal(b.completedAt,undefined);assert.equal(b.confirmedPaymentCents,70000);
  assert.equal((await db.collection(`workCases/${caseId}/events`).get()).size,1);
});
test('MFA policy rejects a primary-only verified admin token and accepts a second-factor token',async()=>{
  await db.doc('bookings/b').update({status:'Accepted'});await db.doc('securityPolicy/admin').set({requireMfa:true});
  const {caseId}=await cases.command({action:'report',bookingId:'b',type:'no_show',reason:'Please review the missed appointment.'},auth('c'));
  const response={action:'review',caseId,notes:'Gathering evidence from both participants.'};
  await assert.rejects(cases.command(response,auth('a')),/Two-step/);
  await cases.command(response,auth('a',{email_verified:true,firebase:{sign_in_second_factor:'phone'}}));
  assert.equal((await db.doc(`workCases/${caseId}`).get()).data().status,'reviewing');
});
