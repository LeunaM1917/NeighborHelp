'use strict';
const {Timestamp} = require('firebase-admin/firestore');
const certificate = (name = 'Domestic Work NC II') => ({id:'cert',name,provider:'TESDA',certificationId:'NC-TEST-0001',url:'gs://test/certificate.pdf',
  expirationDate:'2099-01-01',issueDate:'2026-01-01',status:'Approved',reviewedBy:'admin',reviewedAt:Timestamp.now(),verificationSource:'TESDA Registry of Certified Workers'});
// Start positive booking fixtures tomorrow at 9 AM Manila time, regardless of
// the runner timezone or execution hour. Leave real schedule checks enabled.
const futureWorkStart = (now = Date.now()) => {
  const day = 86400000, manilaOffset = 8 * 3600000;
  const midnight = Math.floor((now + manilaOffset) / day) * day - manilaOffset;
  return midnight + day + 9 * 3600000;
};
// Broad hours isolate business-flow fixtures from weekday differences. They
// still have a midnight gap; arbitrary Date.now() offsets can cross that gap.
const credentials = (name) => ({baseBarangayId:'1102315026',serviceBarangayIds:require('../panabo_barangays.json').barangays.map(b=>b.id),approvedCertificationIds:['cert'],certificationHistory:[certificate(name)],weeklyAvailability:Object.fromEntries(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].map(day=>[day,{enabled:true,start:'12:00 AM',end:'11:59 PM'}]))});
const offer = () => ({pricingType:'fixed',proposedRate:100,numberOfDays:1,hoursPerDay:1,templateVersion:require('../agreements').VERSION,acceptAgreement:true,
  scope:'Clean the agreed rooms.',deliverables:'Clean floors and surfaces.',exclusions:'No work outside the agreed rooms.',materials:'Customer supplies cleaning products.',paymentTerms:'Pay directly in cash after completion.',completionCriteria:'Inspect the agreed rooms together.',responsibilities:'Customer provides safe access. Provider brings tools.'});
module.exports={certificate,credentials,offer,futureWorkStart};
