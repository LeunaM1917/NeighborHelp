'use strict';

// DocuPass replaces new Didit sessions. The two didit* profile fields remain
// compatibility fields for already installed clients; they contain the hosted
// reference and the normalized status, never an ID image or extracted identity.
const crypto = require('node:crypto');
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const TYPES = Object.freeze({ID: 'I', P: 'P', DL: 'D', RP: 'R'});
const text = v => typeof v === 'string' ? v.trim() : '';
const fail = (code, message) => { throw Object.assign(new Error(message), {code}); };
const stamp = () => FieldValue.serverTimestamp();
const millis = v => v?.toMillis?.() || 0;
const SESSION_MS = 24 * 3600000;
const {mandatoryDecisions,assessIdentity,QUALITY_POLICY_VERSION}=require('./identity_quality');

function config() {
  const apiKey = text(process.env.IDANALYZER_API_KEY);
  const profileId = text(process.env.IDANALYZER_PROFILE_ID);
  const webhookSecret = text(process.env.IDANALYZER_WEBHOOK_SECRET);
  const region = text(process.env.IDANALYZER_REGION) || 'us';
  if (!apiKey || !profileId || !webhookSecret || !['us', 'eu'].includes(region)) {
    fail('failed-precondition', 'Identity verification is not configured on the server.');
  }
  return {apiKey, profileId, webhookSecret,
    base: region === 'eu' ? 'https://api2-eu.idanalyzer.com' : 'https://api2.idanalyzer.com'};
}

function returnUrl(value, projectId) {
  if (!value) return '';
  let url;
  try { url = new URL(value); } catch (_) { fail('invalid-argument', 'Invalid verification return URL.'); }
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
  const hostingDomains = [`${projectId}.web.app`, `${projectId}.firebaseapp.com`];
  if (projectId === 'neighborhelp-63771') hostingDomains.push('neighborhelp.web.app', 'neighborhelp.firebaseapp.com');
  const hosted = hostingDomains.includes(url.hostname);
  if (url.username || url.password || !(local && ['http:', 'https:'].includes(url.protocol)
    || hosted && url.protocol === 'https:')) fail('invalid-argument', 'Unsupported verification return URL.');
  return url.toString();
}

function verifySignature(req, secret, now = Date.now()) {
  const timestamp = req.get('X-IDA-Timestamp') || '';
  const signature = req.get('X-IDA-Signature') || '';
  if (!secret || !/^\d{10}$/.test(timestamp) || !/^v1=[a-fA-F0-9]{64}$/.test(signature)
    || Math.abs(now / 1000 - Number(timestamp)) > 300 || !Buffer.isBuffer(req.rawBody)) return false;
  const expected = crypto.createHmac('sha256', secret).update(timestamp + '.').update(req.rawBody).digest();
  const received = Buffer.from(signature.slice(3), 'hex');
  return received.length === expected.length && crypto.timingSafeEqual(received, expected);
}

function resultFor(decision, current = {}) {
  const normalized = text(decision).toLowerCase();
  if (!['accept', 'review', 'reject'].includes(normalized)) return null;
  const rejected = current.verificationManualDecision === 'Rejected';
  const manuallyApproved = current.verificationManualDecision === 'Approved' && normalized !== 'reject';
  return {verificationDecision: normalized,
    diditStatus: normalized === 'accept' ? 'Approved' : normalized === 'reject' ? 'Declined' : 'In Review',
    isVerified: !rejected && (normalized === 'accept' || manuallyApproved),
    verificationStatus: rejected || normalized === 'reject' ? 'Rejected' : normalized === 'accept' || manuallyApproved ? 'Approved' : 'Pending'};
}

module.exports = function idAnalyzer({db, functions, region = 'us-central1',
  projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT,
  fetchImpl = (...args) => fetch(...args), now = Date.now}) {
  async function api(route, method = 'GET', body, timeout = 20000) {
    const c = config();
    let response;
    try {
      response = await fetchImpl(c.base + route, {method,
        headers: {'X-API-KEY': c.apiKey, 'Content-Type': 'application/json'},
        ...(body ? {body: JSON.stringify(body)} : {}), signal: AbortSignal.timeout(timeout)});
    } catch (_) { fail('unavailable', 'The identity verification service could not be reached. Try again shortly.'); }
    const json = await response.json().catch(() => null);
    if (!response.ok || !json || json.error || json.success === false) {
      // Never echo API responses: they can contain credentials, media, or ID data.
      if (response.status === 401 || response.status === 403) fail('failed-precondition', 'Identity verification access needs administrator attention.');
      if (response.status === 402) fail('failed-precondition', 'Identity verification credits need administrator attention.');
      if (response.status === 429) fail('resource-exhausted', 'The identity service is busy. Try again shortly.');
      fail('unavailable', 'The identity service could not complete this request. Try again shortly.');
    }
    return json;
  }

  async function createSession(uid, data = {}) {
    const c = config();
    if (!projectId) fail('failed-precondition', 'The verification server project is not configured.');
    const documentType = text(data.documentType).toUpperCase();
    if (!TYPES[documentType]) fail('invalid-argument', 'Select a valid Philippine government ID type before verifying.');
    const callback = returnUrl(text(data.callback), projectId);
    const key = crypto.randomUUID();
    const userRef = db.doc(`users/${uid}`);
    const time = now();
    const reservation = await db.runTransaction(async tx => {
      const user = (await tx.get(userRef)).data();
      if (!user || user.accountStatus !== 'Active') fail('permission-denied', 'An active account is required.');
      const role = text(user.role).toLowerCase();
      const subject = ['customer', 'client'].includes(role) ? 'customer' : role === 'provider' ? 'provider' : null;
      if (!subject) fail('permission-denied', 'Only customers and providers can start identity verification.');
      if (data.subject && text(data.subject) !== subject) fail('permission-denied', 'The verification account does not match your role.');
      const ref = subject === 'customer' ? userRef : db.doc(`serviceProviders/${uid}`);
      const current = subject === 'customer' ? user : (await tx.get(ref)).data();
      if (!current || subject === 'provider' && current.userId !== uid) fail('failed-precondition', 'Your provider profile is not ready.');
      if (current.isVerified === true || current.verificationStatus === 'Approved') fail('failed-precondition', 'Your identity is already verified.');
      if (current.verificationProvider === 'idanalyzer' && current.verificationStatus === 'Pending'
        && current.governmentIdTypeCode === documentType && current.identitySessionCallback === callback
        && current.identitySessionUrl && millis(current.identitySessionExpiresAt) > time) {
        return {reuse: {url: current.identitySessionUrl, sessionId: current.diditSessionId}};
      }
      if (current.identitySessionRequestId && time - millis(current.identitySessionRequestedAt) < 30000) {
        fail('resource-exhausted', 'Verification is already starting. Please wait a moment.');
      }
      const apply = await require('./rate_limits').quota(tx, db, uid, 'identity_sessions', [[60000, 2], [86400000, 5]], fail, time);
      apply();
      tx.update(ref, {identitySessionRequestId: key, identitySessionRequestedAt: Timestamp.fromMillis(time)});
      return {ref, subject};
    });
    if (reservation.reuse) return reservation.reuse;
    const {ref, subject} = reservation;
    try {
      const webhook = `https://${region}-${projectId}.cloudfunctions.net/idAnalyzerWebhook?session=${key}`;
      const docupass = {expiry: SESSION_MS / 1000, allowFileUpload: false, phoneVerification: 0,
        trackGps: false, ...(callback ? {acceptUrl: callback, rejectUrl: callback, reviewUrl: callback, expireUrl: callback} : {})};
      const json = await api('/docupass', 'POST', {version: '3', profile: c.profileId, mode: 0,
        language: 'en', customData: key, profileOverride: {webhook, docupass,
          decisionTrigger: {review: 1, reject: 1},
          decisions: mandatoryDecisions(),
          acceptedDocuments: {documentType: TYPES[documentType], documentCountry: 'PH', documentState: ''}}});
      let url;
      try { url = new URL(json.url); } catch (_) { fail('unavailable', 'The identity service did not return a verification link.'); }
      // Hosted links are issued by ID Analyzer, never from client input.
      if (url.protocol !== 'https:' || url.username || url.password
        || !['docupass.app', 'docupass.com', 'idanalyzer.com'].some(h => url.hostname === h || url.hostname.endsWith('.' + h))
        || !/^[\w-]{1,200}$/.test(text(json.reference))) fail('unavailable', 'The identity service returned an invalid verification link.');
      const expiresAt = Timestamp.fromMillis(Math.min(time + SESSION_MS, Number(json.expiry) > 0 ? Number(json.expiry) * 1000 : time + SESSION_MS));
      await db.runTransaction(async tx => {
        const current = (await tx.get(ref)).data();
        if (current?.identitySessionRequestId !== key) fail('aborted', 'A newer verification attempt has started.');
        tx.create(db.doc(`identitySessions/${key}`), {uid, subject, documentType, reference: json.reference,
          profileId: c.profileId, qualityPolicyVersion:QUALITY_POLICY_VERSION, createdAt: stamp(), expiresAt, syncToken: null});
        tx.update(ref, {verificationProvider: 'idanalyzer', diditSessionId: json.reference, diditStatus: 'In Progress',
          identitySessionKey: key, identitySessionUrl: url.toString(), identitySessionCallback: callback,
          identitySessionExpiresAt: expiresAt, identitySessionRequestId: FieldValue.delete(),
          verificationDecision: FieldValue.delete(), verificationManualDecision: FieldValue.delete(),
          verificationRetakeRequired:false, verificationIssueCodes:[],
          verificationStatus: 'Pending', isVerified: false, governmentIdTypeCode: documentType,
          governmentIdTypeLabel: ({ID: 'National ID card', P: 'Passport', DL: "Driver's license", RP: 'Residence permit'})[documentType],
          verificationUpdatedAt: stamp(), updatedAt: stamp()});
      });
      return {url: url.toString(), sessionId: json.reference};
    } catch (error) {
      await db.runTransaction(async tx => {
        if ((await tx.get(ref)).data()?.identitySessionRequestId === key) tx.update(ref, {identitySessionRequestId: FieldValue.delete()});
      });
      throw error;
    }
  }

  async function synchronize(key, event) {
    if (!/^[0-9a-f-]{36}$/.test(text(key))) return {ok: true, ignored: 'unlinked session'};
    const ref = db.doc(`identitySessions/${key}`), syncToken = crypto.randomUUID();
    const session = await db.runTransaction(async tx => {
      const record = (await tx.get(ref)).data();
      if (!record) return null;
      if (record.syncToken && now() - millis(record.syncStartedAt) < 30000) fail('unavailable', 'Verification status is being refreshed. Try again shortly.');
      tx.update(ref, {syncToken, syncStartedAt: Timestamp.fromMillis(now())});
      return record;
    });
    if (!session) return {ok: true, ignored: 'unlinked session'};
    try {
      const hosted = await api(`/docupass/${encodeURIComponent(session.reference)}`, 'GET', undefined, 7000);
      // Read the authoritative, completed DocuPass, not a partial document scan
      // or a browser's redirect parameters. Refetching also handles reordered events.
      if (hosted.reference !== session.reference || hosted.customData !== key || hosted.profileId !== session.profileId
        || Number(hosted.mode) !== 0 || hosted.reusable === true || Number(hosted.reusable) > 0) {
        fail('failed-precondition', 'The verification session binding could not be confirmed.');
      }
      const transaction = hosted.finalTransaction || {};
      const transactionId = text(hosted.transactionId) || text(transaction.transactionId);
      const decision = text(hosted.decision) || text(transaction.decision);
      if (!hosted.completedAt || !transactionId || !resultFor(decision)) return {ok: true, status: 'In Progress'};
      if (event && (text(event.transactionId) !== transactionId
        || event.profileId && event.profileId !== session.profileId)) return {ok: true, ignored: 'unrelated transaction'};
      const targetRef = db.doc(`${session.subject === 'customer' ? 'users' : 'serviceProviders'}/${session.uid}`);
      return await db.runTransaction(async tx => {
        const locked = (await tx.get(ref)).data();
        const current = (await tx.get(targetRef)).data();
        const user = (await tx.get(db.doc(`users/${session.uid}`))).data();
        if (locked?.syncToken !== syncToken) fail('aborted', 'A newer status refresh is running.');
        if (!current || current.verificationProvider !== 'idanalyzer' || current.identitySessionKey !== key
          || current.diditSessionId !== session.reference) return {ok: true, ignored: 'superseded session'};
        const expectedRoles = session.subject === 'customer' ? ['customer', 'client'] : ['provider'];
        if (user?.accountStatus !== 'Active' || !expectedRoles.includes(text(user.role).toLowerCase())) {
          return {ok: true, ignored: 'inactive or changed account'};
        }
        // Some DocuPass responses omit expiry despite a per-link expiry override.
        // Enforce the platform deadline independently of the hosted page.
        const completedMs = Number(hosted.completedAt) * 1000;
        const quality=assessIdentity(transaction);
        const effectiveDecision = quality.blocked || !Number.isFinite(completedMs) || completedMs > millis(session.expiresAt)
          ? 'reject' : decision;
        const patch = {...resultFor(effectiveDecision, current),verificationRetakeRequired:quality.retakeRequired,
          verificationIssueCodes:quality.codes};
        const changed = Object.entries(patch).some(([k, value]) => JSON.stringify(current[k]) !== JSON.stringify(value));
        if (changed) tx.update(targetRef, {...patch, verificationUpdatedAt: stamp(), updatedAt: stamp()});
        tx.update(ref, {decision: patch.verificationDecision, transactionId, completedAt: stamp(),
          qualityPolicyVersion:quality.policyVersion,qualityPassed:!quality.blocked,retakeRequired:quality.retakeRequired,issueCodes:quality.codes});
        return {ok: true, status: patch.diditStatus, changed};
      });
    } finally {
      await db.runTransaction(async tx => {
        if ((await tx.get(ref)).data()?.syncToken === syncToken) tx.update(ref, {syncToken: null});
      });
    }
  }

  async function refresh(userId, subject) {
    const target = (await db.doc(`${subject === 'customer' ? 'users' : 'serviceProviders'}/${userId}`).get()).data();
    if (target?.verificationProvider !== 'idanalyzer' || !target.identitySessionKey) fail('failed-precondition', 'No ID Analyzer session exists for this account.');
    const result = await synchronize(target.identitySessionKey);
    return {...result, diditStatus: result.status || target.diditStatus, subject, userId};
  }

  const webhookHandler = async (req, res) => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    let c;
    try { c = config(); } catch (_) { return res.status(503).send('Not configured'); }
    if (!verifySignature(req, c.webhookSecret, now())) return res.status(401).send('Invalid signature');
    const event = req.body || {};
    if (!['docupass_conclusive', 'update'].includes(event.event)) return res.status(200).json({ok: true, ignored: 'non-final event'});
    try { return res.status(200).json(await synchronize(req.query?.session, event)); }
    catch (_) {
      functions.logger.warn('ID Analyzer webhook synchronization failed; delivery may be retried.');
      return res.status(503).send('Please retry');
    }
  };
  const webhook = functions.region(region).https.onRequest(webhookHandler);
  return {createSession, refresh, synchronize, webhook, webhookHandler};
};
module.exports.verifySignature = verifySignature;
module.exports.resultFor = resultFor;
module.exports.returnUrl = returnUrl;
