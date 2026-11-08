'use strict';
const {Timestamp} = require('firebase-admin/firestore');
const certificate = (name = 'Domestic Work NC II') => ({id:'cert',name,provider:'TESDA',certificationId:'NC-TEST-0001',url:'gs://test/certificate.pdf',
  expirationDate:'2099-01-01',issueDate:'2026-01-01',status:'Approved',reviewedBy:'admin',reviewedAt:Timestamp.now(),verificationSource:'TESDA Registry of Certified Workers'});
const credentials = (name) => ({approvedCertificationIds:['cert'],certificationHistory:[certificate(name)]});
const offer = () => ({pricingType:'fixed',proposedRate:100,numberOfDays:1,hoursPerDay:1,templateVersion:require('../agreements').VERSION,acceptAgreement:true,
  scope:'Clean the agreed rooms.',deliverables:'Clean floors and surfaces.',exclusions:'No work outside the agreed rooms.',materials:'Customer supplies cleaning products.',paymentTerms:'Pay directly in cash after completion.',completionCriteria:'Inspect the agreed rooms together.',responsibilities:'Customer provides safe access. Provider brings tools.'});
module.exports={certificate,credentials,offer};
