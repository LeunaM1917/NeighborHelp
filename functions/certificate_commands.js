'use strict';
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const {credentialFamily, normalize} = require('./marketplace_policy');
module.exports = ({db, functions}) => async (data, context) => {
  const fail = (code,message) => {throw new functions.https.HttpsError(code,message);};
  const uid = context.auth?.uid;
  if (!uid) fail('unauthenticated','Sign in required.');
  return db.runTransaction(async tx => {
    const actor = (await tx.get(db.doc(`users/${uid}`))).data();
    if (actor?.role !== 'Administrator' || actor.accountStatus !== 'Active') fail('permission-denied','Administrator access required.');
    await require('./admin_security').assertAdminToken(context,fail,db,tx);
    const providerId = String(data.providerId || ''), certId = String(data.certificationEntryId || '');
    if (!/^[\w-]{1,160}$/.test(providerId) || !/^[\w-]{1,160}$/.test(certId)) fail('invalid-argument','Invalid certificate reference.');
    const ref = db.doc(`serviceProviders/${providerId}`), p = (await tx.get(ref)).data();
    const history = [...(p?.certificationHistory || [])], index = history.findIndex(c => c.id === certId);
    if (index < 0) fail('not-found','Certificate not found.');
    const decision = String(data.decision || ''), notes = String(data.notes || '').trim();
    if (!['Approved','Pending','Rejected'].includes(decision) || notes.length < 10 || notes.length > 3000) fail('invalid-argument','Choose a result and provide review notes of 10–3000 characters.');
    const c = history[index];
    const dateValid = value => /^\d{4}-\d{2}-\d{2}$/.test(value || '') && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0,10) === value;
    if (decision === 'Approved' && (data.registryChecked !== true || !credentialFamily(c.name) || normalize(c.provider) !== 'tesda' || !String(c.certificationId || '').trim()
      || !new RegExp(`^gs://[^/]+/certificates/${providerId}/[\\w-]+/[\\w.-]+$`).test(c.url || '') || !dateValid(c.issueDate) || !dateValid(c.expirationDate) || c.issueDate > c.expirationDate || new Date(c.issueDate) > new Date()
      || !/^\d{4}-\d{2}-\d{2}$/.test(c.expirationDate || '') || !(new Date(`${c.expirationDate}T23:59:59.999+08:00`) >= new Date()))) fail('failed-precondition','Confirm the holder, certificate number, qualification and validity in the TESDA registry. A supported qualification, TESDA issuer, certificate number, document and valid expiry date are required.');
    history[index] = {...c,status:decision,reviewedBy:uid,reviewedByRole:'Administrator',reviewedAt:Timestamp.now(),
      verificationSource:'TESDA Registry of Certified Workers',verificationNotes:notes,registryChecked:data.registryChecked === true,
      rejectionReason:decision === 'Rejected' ? notes : ''};
    const approved = new Set(p.approvedCertificationIds || []);
    if (decision === 'Approved') approved.add(certId); else approved.delete(certId);
    tx.update(ref,{certificationHistory:history,approvedCertificationIds:[...approved],updatedBy:uid,updatedByRole:'Administrator',updatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:'Administrator',action:'certificate.review',collection:'serviceProviders',referenceId:providerId,
      certificationEntryId:certId,decision,notes,createdAt:FieldValue.serverTimestamp()});
    return {decision};
  });
};
