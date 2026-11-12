'use strict';
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const {validTesdaQualification, normalize} = require('./marketplace_policy');
module.exports = ({db, functions}) => async (data, context) => {
  const fail = (code,message) => {throw new functions.https.HttpsError(code,message);};
  const uid = context.auth?.uid;
  if (!uid) fail('unauthenticated','Sign in required.');
  const dateValid = value => /^\d{4}-\d{2}-\d{2}$/.test(value || '') && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0,10) === value;
  const todayManila = new Date(Date.now()+8*3600000).toISOString().slice(0,10);
  return db.runTransaction(async tx => {
    const actor = (await tx.get(db.doc(`users/${uid}`))).data();
    if (data.action === 'submit') {
      if (actor?.role !== 'Provider' || actor.accountStatus !== 'Active' || data.providerId !== uid) fail('permission-denied','Submit certificates only for your own provider profile.');
      const ref = db.doc(`serviceProviders/${uid}`), p = (await tx.get(ref)).data(), e = data.entry || {};
      const equivalent = e.credentialType === 'equivalent';
      if (!p || !/^[\w-]{1,160}$/.test(e.id || '') || typeof e.name !== 'string' || e.name.trim().length < 3 || e.name.length > 140
          || typeof e.provider !== 'string' || !e.provider.trim() || e.provider.length > 140 || !String(e.certificationId || '').trim()
          || String(e.certificationId).length > 160 || !new RegExp(`^gs://[^/]+/certificates/${uid}/[\\w-]+/[\\w.-]+$`).test(e.url || '')
          || !dateValid(e.issueDate) || !dateValid(e.expirationDate)
          || e.issueDate > todayManila || !(new Date(`${e.expirationDate}T23:59:59.999+08:00`) >= new Date())
          || e.issueDate > e.expirationDate || (!equivalent && (!validTesdaQualification(e.name) || normalize(e.provider) !== 'tesda'))
          || (equivalent && normalize(e.provider) === 'tesda')) fail('invalid-argument','Complete the credential, issuer, certificate number, uploaded document and valid dates.');
      const c = {id:e.id,name:e.name.trim(),provider:e.provider.trim(),credentialType:equivalent?'equivalent':'tesda',
        certificationId:String(e.certificationId).trim(),url:e.url,issueDate:e.issueDate,expirationDate:e.expirationDate,
        description:String(e.description || '').slice(0,4000),status:'Pending'};
      const history = [...(p.certificationHistory || [])];
      // Keep pre-history profile credentials visible when adding the first upload.
      if (!history.length) for (const [i,name] of (p.certifications || []).entries()) {
        if (typeof name === 'string' && name.trim()) history.push({
          id:'legacy_'+require('node:crypto').createHash('sha256').update(`${i}:${name}`).digest('hex').slice(0,24),
          name:name.trim(),status:'Pending',
        });
      }
      const index = history.findIndex(v => v.id === c.id);
      if (index < 0) history.push(c); else history[index] = c;
      if (history.length > 100) fail('resource-exhausted','Certificate limit reached.');
      tx.update(ref,{certificationHistory:history,approvedCertificationIds:(p.approvedCertificationIds || []).filter(id => id !== c.id),updatedBy:uid,updatedAt:FieldValue.serverTimestamp()});
      return {decision:'Pending'};
    }
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
    const equivalent = c.credentialType === 'equivalent';
    if (decision === 'Approved' && ((equivalent ? data.issuerVerified !== true || !String(c.provider || '').trim() || normalize(c.provider) === 'tesda' || String(c.name || '').trim().length < 3 : data.registryChecked !== true || !validTesdaQualification(c.name) || normalize(c.provider) !== 'tesda') || !String(c.certificationId || '').trim()
      || !new RegExp(`^gs://[^/]+/certificates/${providerId}/[\\w-]+/[\\w.-]+$`).test(c.url || '') || !dateValid(c.issueDate) || !dateValid(c.expirationDate) || c.issueDate > c.expirationDate || c.issueDate > todayManila
      || !/^\d{4}-\d{2}-\d{2}$/.test(c.expirationDate || '') || !(new Date(`${c.expirationDate}T23:59:59.999+08:00`) >= new Date()))) fail('failed-precondition','Confirm the holder, certificate number, qualification and validity in the TESDA registry. A supported qualification, TESDA issuer, certificate number, document and valid expiry date are required.');
    history[index] = {...c,status:decision,reviewedBy:uid,reviewedByRole:'Administrator',reviewedAt:Timestamp.now(),
      verificationSource:equivalent?'Issuing authority verification':'TESDA Registry of Certified Workers',verificationNotes:notes,registryChecked:!equivalent && data.registryChecked === true,issuerVerified:equivalent && data.issuerVerified === true,
      rejectionReason:decision === 'Rejected' ? notes : ''};
    const approved = new Set(p.approvedCertificationIds || []);
    if (decision === 'Approved') approved.add(certId); else approved.delete(certId);
    tx.update(ref,{certificationHistory:history,approvedCertificationIds:[...approved],updatedBy:uid,updatedByRole:'Administrator',updatedAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:'Administrator',action:'certificate.review',collection:'serviceProviders',referenceId:providerId,
      certificationEntryId:certId,decision,notes,createdAt:FieldValue.serverTimestamp()});
    return {decision};
  });
};
