'use strict';
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const policy = require('./marketplace_policy');
const setup = require('./account_setup');
const crypto = require('node:crypto');

// Listings and their certificate alignment are reviewed together. Proposal history
// remains untouched; no proposal document is needed for a new custom listing.
module.exports = ({db, functions, bucket}) => async (data, context) => {
  const fail = (code, message) => { throw new functions.https.HttpsError(code, message); };
  const uid = context.auth?.uid;
  if (!uid) fail('unauthenticated', 'Sign in required.');
  const action = data?.action, id = String(data?.serviceId || '');
  if (!['saveDraft', 'submit', 'approve', 'reject', 'setActive'].includes(action)
      || !/^[\w-]{1,160}$/.test(id)) fail('invalid-argument', 'Invalid service action or reference.');
  const ref = db.doc(`services/${id}`);
  const stamp = () => FieldValue.serverTimestamp();
  return db.runTransaction(async tx => {
    const actor = (await tx.get(db.doc(`users/${uid}`))).data();
    if (actor?.accountStatus !== 'Active') fail('permission-denied', 'An active account is required.');
    const admin = actor.role === 'Administrator';
    if (admin) await require('./admin_security').assertAdminToken(context, fail, db, tx);
    const existing = (await tx.get(ref)).data();
    if (['approve', 'reject'].includes(action) && !admin) fail('permission-denied', 'Administrator review required.');
    if (['saveDraft', 'submit'].includes(action) && actor.role !== 'Provider') fail('permission-denied', 'Provider access required.');
    if (!existing && !['saveDraft', 'submit'].includes(action)) fail('not-found', 'Service no longer exists.');
    const providerId = existing?.providerId || uid;
    if (!admin && (actor.role !== 'Provider' || providerId !== uid)) fail('permission-denied', 'This service belongs to another provider.');
    const profileRef = db.doc(`serviceProviders/${providerId}`);
    const profile = (await tx.get(profileRef)).data();
    const owner = providerId === uid ? actor : (await tx.get(db.doc(`users/${providerId}`))).data();
    const completeProvider = () => {
      if (!profile?.isVerified || owner?.role !== 'Provider' || owner.accountStatus !== 'Active'
          || !setup.detailsComplete(owner, profile)) fail('failed-precondition', 'The provider needs a verified identity, active account and complete service area.');
    };
    const currentCertificate = s => {
      const c = (profile?.certificationHistory || []).find(c => c.id === s.certificationEntryId);
      if (!c || !policy.eligibleReviewedCredential(c, new Set(profile?.approvedCertificationIds || []))) {
        fail('failed-precondition', 'Select a current certificate authenticated and approved by the administrator.');
      }
      const family = policy.serviceFamily(s.category, s.serviceTitle);
      if (family && c.credentialType !== 'equivalent' && policy.credentialFamily(c.name) !== family) {
        fail('failed-precondition', 'The selected TESDA certificate does not match this service.');
      }
      return c;
    };
    const validatePhotos = async s => {
      const photos = s.serviceImages;
      if (!Array.isArray(photos) || photos.length < 3 || photos.length > 6) fail('failed-precondition', 'Add at least 3 service photos (maximum 6) before submitting.');
      const paths = new Set(), hashes = new Set();
      const checked = [];
      for (const value of photos) {
        let path;
        try {
          const url = new URL(value);
          if (url.protocol === 'gs:' && url.hostname === bucket.name) path = decodeURIComponent(url.pathname.slice(1));
          if (url.protocol === 'https:' && url.hostname === 'firebasestorage.googleapis.com') {
            const m = url.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/);
            if (m && decodeURIComponent(m[1]) === bucket.name) path = decodeURIComponent(m[2]);
          }
        } catch (_) { /* Fail closed below for invalid or external URLs. */ }
        if (!path || !path.startsWith(`services/${providerId}/${id}/`) || path.split('/').length !== 4 || paths.has(path)) {
          fail('failed-precondition', 'Use distinct photos uploaded for this listing. External or stock images do not count.');
        }
        paths.add(path);
        try {
          const file = bucket.file(path), [meta] = await file.getMetadata();
          const [bytes] = await file.download({start: 0, end: 11});
          const type = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255 ? 'image/jpeg'
            : bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])) ? 'image/png'
            : bytes.toString('ascii',0,4) === 'RIFF' && bytes.toString('ascii',8,12) === 'WEBP' ? 'image/webp' : '';
          if (!type || meta.contentType !== type || !(Number(meta.size) > 0 && Number(meta.size) <= 5*1024*1024)
              || !meta.md5Hash || hashes.has(meta.md5Hash)) fail('failed-precondition', 'Use 3–6 different JPG, PNG or WebP photos up to 5 MB each.');
          hashes.add(meta.md5Hash);
          checked.push({path, generation: String(meta.generation), md5Hash: meta.md5Hash});
        } catch (e) {
          if (e instanceof functions.https.HttpsError) throw e;
          fail('failed-precondition', 'A service photo is unavailable. Remove it and upload a replacement.');
        }
      }
      return checked;
    };
    let patch;
    if (['saveDraft', 'submit'].includes(action)) {
      const fields = data.fields || {};
      const text = (key, max) => {
        const value = fields[key] ?? existing?.[key] ?? '';
        if (typeof value !== 'string' || value.trim().length > max) fail('invalid-argument', `Invalid ${key}.`);
        return value.trim();
      };
      patch = {serviceTitle:text('serviceTitle',140), category:text('category',100), description:text('description',500),
        estimatedDuration:text('estimatedDuration',80), certificationEntryId:text('certificationEntryId',160),
        estimatedPrice:fields.estimatedPrice ?? existing?.estimatedPrice ?? 0,
        priceType:fields.priceType ?? existing?.priceType ?? 'negotiable',
        serviceImages:fields.serviceImages ?? existing?.serviceImages ?? [],
        listingPolicyVersion:2, requiresCertification:true, isActive:false, rejectionReason:'',
        approvalStatus:action === 'submit' ? 'Pending' : 'Draft',
        certificateAlignment:FieldValue.delete()};
      if (!Number.isFinite(patch.estimatedPrice) || patch.estimatedPrice < 0 || patch.estimatedPrice > 10000000
          || !['hourly','fixed','daily','negotiable'].includes(patch.priceType)
          || !Array.isArray(patch.serviceImages) || patch.serviceImages.length > 6
          || patch.serviceImages.some(v => typeof v !== 'string' || v.length > 2048)) fail('invalid-argument', 'Check the price, pricing basis and photos.');
      if (action === 'submit') {
        completeProvider();
        if (patch.serviceTitle.length < 3 || patch.category.length < 3 || patch.description.length < 10
            || !patch.estimatedDuration || patch.estimatedPrice <= 0) fail('failed-precondition', 'Complete the category, service title, description, price and estimated duration.');
        currentCertificate(patch);
        patch.photoManifest = await validatePhotos(patch);
        patch.submittedAt = stamp();
      }
    } else if (action === 'approve') {
      if (existing.approvalStatus !== 'Pending') fail('failed-precondition', 'The provider must submit the listing before approval.');
      completeProvider();
      // Older submissions may be finished and resubmitted without changing their IDs.
      if (existing.listingPolicyVersion !== 2) fail('failed-precondition', 'Ask the provider to select a certificate, add 3 service photos and resubmit this listing.');
      const cert = currentCertificate(existing);
      if (data.alignmentConfirmed !== true || String(data.notes || '').trim().length < 10 || String(data.notes).length > 3000) {
        fail('failed-precondition', 'Confirm certificate alignment and record at least 10 characters of review notes.');
      }
      const manifest = await validatePhotos(existing);
      const alignment = {status:'Approved',reviewType:'directListing',serviceId:id,category:existing.category,serviceTitle:existing.serviceTitle,
        certificationEntryId:cert.id,qualificationName:cert.name,reviewedBy:uid,reviewedAt:Timestamp.now()};
      // Only reviewed exact category/title/certificate bindings grant eligibility.
      const grants = {...(profile.approvedServiceListings || {}), [id]:alignment};
      if (Object.keys(grants).length > 100) fail('resource-exhausted', 'This provider has reached the reviewed listing limit.');
      tx.update(profileRef, {approvedServiceListings:grants,updatedAt:stamp()});
      const catalogId = crypto.createHash('sha256').update(`${policy.normalize(existing.category)}:${policy.normalize(existing.serviceTitle)}`).digest('hex');
      tx.set(db.doc(`serviceCatalog/${catalogId}`), {category:existing.category,serviceTitle:existing.serviceTitle,reviewedAt:stamp()});
      patch = {approvalStatus:'Approved',isActive:true,rejectionReason:'',certificateAlignment:alignment,photoManifest:manifest};
    } else if (action === 'reject') {
      const reason = String(data.reason || '').trim();
      if (reason.length < 10 || reason.length > 3000) fail('invalid-argument', 'Explain the rejection in 10–3000 characters.');
      patch = {approvalStatus:'Rejected',isActive:false,rejectionReason:reason};
    } else {
      if (typeof data.isActive !== 'boolean') fail('invalid-argument', 'Choose listing visibility.');
      if (data.isActive) {
        completeProvider();
        if (existing.approvalStatus !== 'Approved' || !require('./domain').hasMatchingCertificate(profile,existing.category,existing.serviceTitle)) {
          fail('failed-precondition', 'Administrator approval and a current matching certificate are required.');
        }
        if (existing.listingPolicyVersion === 2) { currentCertificate(existing); await validatePhotos(existing); }
      }
      patch = {isActive:data.isActive};
    }
    const record = {...patch,updatedBy:uid,updatedByRole:actor.role,updatedAt:stamp()};
    if (existing) tx.update(ref,record);
    else {
      delete record.certificateAlignment;
      tx.create(ref,{...record,providerId,availability:{},createdAt:stamp()});
    }
    if (['approve','reject'].includes(action)) {
      tx.create(db.collection('auditLogs').doc(), {actorId:uid,actorRole:actor.role,action:`service.${action}`,collection:'services',referenceId:id,notes:data.notes || data.reason,createdAt:stamp()});
    }
    return {serviceId:id,approvalStatus:patch.approvalStatus || existing.approvalStatus};
  });
};
