const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const crypto = require('crypto');
const path = require('path');

// Load functions/.env for local emulator; production uses env vars set at deploy time.
try {
  require('dotenv').config({ path: path.join(__dirname, '.env') });
} catch (_) {
  /* dotenv optional */
}

admin.initializeApp();

const db = admin.firestore();
const C = 10;

// ---------------------------------------------------------------------------
// Didit identity verification (KYC) for service providers.
//
// Config (set in functions/.env or via Secret Manager):
//   DIDIT_API_KEY        – API key from Didit console (x-api-key header)
//   DIDIT_WORKFLOW_ID    – Workflow UUID from Didit console
//   DIDIT_WEBHOOK_SECRET – Per-destination secret_shared_key for signing
// ---------------------------------------------------------------------------

const DIDIT_SESSION_URL = 'https://verification.didit.me/v3/session/';
const ALLOWED_DIDIT_DOCUMENT_TYPES = new Set(['P', 'ID', 'DL', 'RP']);

/** Read Didit secrets from deploy-time env (.env). Trim in case of stray whitespace. */
function diditEnv() {
  return {
    apiKey: (process.env.DIDIT_API_KEY || '').trim(),
    workflowId: (process.env.DIDIT_WORKFLOW_ID || '').trim(),
    webhookSecret: (process.env.DIDIT_WEBHOOK_SECRET || '').trim(),
  };
}

// Log once per cold start so Firebase logs show whether deploy loaded .env.
functions.logger.info('Didit env at cold start', {
  hasApiKey: Boolean(diditEnv().apiKey),
  hasWorkflowId: Boolean(diditEnv().workflowId),
  hasWebhookSecret: Boolean(diditEnv().webhookSecret),
});

/**
 * Map a Didit session status to our provider verification fields.
 * Terminal: Approved -> verified, Declined -> rejected.
 * Everything else stays in the "pending" bucket so admins still see it.
 */
/**
 * Didit terminal statuses update diditStatus only. Platform badge requires admin
 * approval (adminVerifyProvider sets isVerified + verificationStatus Approved).
 */
function mapDiditStatus(diditStatus) {
  const norm = String(diditStatus || '')
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_');
  switch (norm) {
    case 'approved':
      return { isVerified: false, verificationStatus: 'Pending' };
    case 'declined':
      return { isVerified: false, verificationStatus: 'Rejected' };
    default:
      // Not Started, In Progress, In Review, Resubmitted, Awaiting User, Expired, ...
      return { isVerified: false, verificationStatus: 'Pending' };
  }
}

/**
 * When we return a hosted Didit URL, reflect that the user is in the flow.
 * Didit often returns "Not Started" on session creation even though the link is open.
 * @param {string|undefined} apiStatus
 * @returns {string}
 */
function diditStatusWhenLaunchingHostedFlow(apiStatus) {
  const raw = typeof apiStatus === 'string' ? apiStatus.trim() : '';
  const norm = raw.toLowerCase().replace(/[\s-]+/g, '_');
  if (!raw || norm === 'not_started') return 'In Progress';
  return raw;
}

/**
 * Read current Didit session status from server-side API.
 * @param {string} sessionId
 * @returns {Promise<{ diditStatus: string, sessionId: string|null }>}
 */
async function fetchDiditSessionStatus(sessionId) {
  const { apiKey } = diditEnv();
  if (!apiKey) {
    throw verificationFailure(
      'failed-precondition',
      'Didit API key missing on the server. Redeploy functions with DIDIT_API_KEY.'
    );
  }
  if (!sessionId || typeof sessionId !== 'string') {
    throw verificationFailure('invalid-argument', 'Didit session ID is required.');
  }

  const base = DIDIT_SESSION_URL.replace(/\/+$/, '');
  const encodedSessionId = encodeURIComponent(sessionId);
  const candidateUrls = [
    `${base}/${encodedSessionId}/decision/`,
    `${base}/${encodedSessionId}/decision`,
    `${base}/${encodedSessionId}/`,
    `${base}/${encodedSessionId}`,
  ];

  /** @type {{ status: number, json: any, url: string }|null} */
  let lastFailure = null;

  for (const sessionUrl of candidateUrls) {
    let resp;
    try {
      resp = await fetch(sessionUrl, {
        method: 'GET',
        headers: { 'x-api-key': apiKey },
      });
    } catch (err) {
      functions.logger.error('Didit status request failed', { sessionId, sessionUrl, err });
      throw verificationFailure('unavailable', 'Could not reach Didit to refresh status.');
    }

    const json = await resp.json().catch(() => null);
    const diditStatus = extractDiditStatus(json);
    const resolvedSessionId =
      json && typeof json.session_id === 'string' && json.session_id.trim().length > 0
        ? json.session_id
        : sessionId;

    if (resp.ok && diditStatus) {
      return { diditStatus, sessionId: resolvedSessionId };
    }

    lastFailure = { status: resp.status, json, url: sessionUrl };
    if (resp.status !== 404) break;
  }

  const detail = formatDiditError(lastFailure?.json, lastFailure?.status || 500);
  functions.logger.error('Didit status error', {
    status: lastFailure?.status || 500,
    json: lastFailure?.json || null,
    detail,
    sessionId,
    attemptedUrl: lastFailure?.url || null,
  });
  throw verificationFailure('failed-precondition', detail);
}

/**
 * List recent sessions for a vendor_data id and return the best candidate.
 * @param {string} vendorData
 * @returns {Promise<{ diditStatus: string, sessionId: string|null }|null>}
 */
async function fetchBestDiditSessionForVendor(vendorData) {
  const { apiKey } = diditEnv();
  if (!apiKey || !vendorData) return null;

  const qs = new URLSearchParams({
    vendor_data: vendorData,
    limit: '20',
  });
  const url = `https://verification.didit.me/v3/sessions?${qs.toString()}`;

  let resp;
  try {
    resp = await fetch(url, {
      method: 'GET',
      headers: { 'x-api-key': apiKey },
    });
  } catch (err) {
    functions.logger.warn('Didit sessions list request failed', { vendorData, err });
    return null;
  }

  if (!resp.ok) {
    const json = await resp.json().catch(() => null);
    functions.logger.warn('Didit sessions list error', {
      vendorData,
      status: resp.status,
      body: json,
    });
    return null;
  }

  const json = await resp.json().catch(() => null);
  const results = Array.isArray(json?.results) ? json.results : [];
  if (results.length === 0) return null;

  const score = (status) => {
    const norm = String(status || '')
      .trim()
      .toLowerCase()
      .replace(/[\s-]+/g, '_');
    switch (norm) {
      case 'approved':
        return 5;
      case 'in_review':
      case 'active':
      case 'awaiting_user':
      case 'resubmitted':
        return 4;
      case 'in_progress':
        return 3;
      case 'declined':
      case 'rejected':
        return 2;
      case 'not_started':
      default:
        return 1;
    }
  };

  results.sort((a, b) => {
    const byStatus = score(b?.status) - score(a?.status);
    if (byStatus !== 0) return byStatus;
    const ta = Date.parse(String(a?.created_at || '')) || 0;
    const tb = Date.parse(String(b?.created_at || '')) || 0;
    return tb - ta;
  });

  const best = results[0] || {};
  const diditStatus =
    typeof best.status === 'string' && best.status.trim().length > 0
      ? best.status.trim()
      : '';
  const sessionId =
    typeof best.session_id === 'string' && best.session_id.trim().length > 0
      ? best.session_id.trim()
      : null;
  if (!diditStatus) return null;
  return { diditStatus, sessionId };
}

/**
 * Extract status from any known Didit retrieve-session payload shape.
 * @param {any} json
 * @returns {string}
 */
function extractDiditStatus(json) {
  if (!json || typeof json !== 'object') return '';
  if (typeof json.status === 'string' && json.status.trim().length > 0) {
    return json.status.trim();
  }
  if (
    json.session &&
    typeof json.session === 'object' &&
    typeof json.session.status === 'string' &&
    json.session.status.trim().length > 0
  ) {
    return json.session.status.trim();
  }
  if (
    Array.isArray(json.features) &&
    json.features.length > 0 &&
    json.features[0] &&
    typeof json.features[0] === 'object' &&
    typeof json.features[0].status === 'string' &&
    json.features[0].status.trim().length > 0
  ) {
    return json.features[0].status.trim();
  }
  return '';
}

/**
 * Callable: force-sync a user's Didit status into Firestore.
 * Intended as a safe fallback when webhook updates are delayed or missed.
 */
exports.refreshDiditStatus = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    const callerUid = context.auth && context.auth.uid;
    if (!callerUid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    }

    const callerSnap = await db.collection('users').doc(callerUid).get();
    const callerRole = (callerSnap.data()?.role || '').trim().toLowerCase();
    if (!(callerRole === 'admin' || callerRole === 'administrator')) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required.');
    }

    const userId = data && typeof data.userId === 'string' ? data.userId.trim() : '';
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'userId is required.');
    }

    let subject = data && typeof data.subject === 'string' ? data.subject.trim().toLowerCase() : '';
    if (subject !== 'customer' && subject !== 'provider') {
      const targetUserSnap = await db.collection('users').doc(userId).get();
      const targetRole = targetUserSnap.exists ? targetUserSnap.data().role : '';
      subject = resolveVerificationSubject({}, targetRole);
    }

    const docRef =
      subject === 'customer'
        ? db.collection('users').doc(userId)
        : db.collection('serviceProviders').doc(userId);
    const targetSnap = await docRef.get();
    const diditSessionId = (targetSnap.data()?.diditSessionId || '').trim();
    if (!diditSessionId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'No Didit session found on this profile yet.'
      );
    }

    try {
      let latest = await fetchDiditSessionStatus(diditSessionId);
      const latestNorm = String(latest.diditStatus || '').trim().toLowerCase();
      // If stored session is stale at "Not Started", query vendor sessions and
      // choose the most relevant recent session (often the one user actually finished).
      if (latestNorm === 'not started' || latestNorm === 'not_started') {
        const fallback = await fetchBestDiditSessionForVendor(userId);
        if (fallback && fallback.diditStatus.trim().length > 0) {
          latest = fallback;
        }
      }
      const mapped = mapDiditStatus(latest.diditStatus);
      await docRef.set(
        {
          verificationProvider: 'didit',
          diditStatus: latest.diditStatus,
          diditSessionId: latest.sessionId || diditSessionId,
          isVerified: mapped.isVerified,
          verificationStatus: mapped.verificationStatus,
          verificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return { ok: true, diditStatus: latest.diditStatus, subject, userId };
    } catch (err) {
      if (err && err.code && err.message) {
        throw new functions.https.HttpsError(err.code, err.message);
      }
      functions.logger.error('refreshDiditStatus unexpected error', { userId, subject, err });
      throw new functions.https.HttpsError('internal', 'Could not refresh Didit status.');
    }
  });

const functionsRegion = 'us-central1';
const cors = require('cors')({ origin: true });

/** @typedef {{ code: string, message: string }} VerificationFailure */

/**
 * Shared Didit session creation (callable + CORS HTTP for Flutter web).
 * @returns {Promise<{ url: string, sessionId: string|null }>}
 */
function resolveVerificationSubject(data, userRole) {
  const raw = data && typeof data.subject === 'string' ? data.subject.trim().toLowerCase() : '';
  if (raw === 'customer' || raw === 'provider') return raw;
  const role = (userRole || '').trim().toLowerCase();
  if (role === 'customer' || role === 'client') return 'customer';
  return 'provider';
}

async function createDiditSessionCore(uid, data) {
  const documentType =
    data && typeof data.documentType === 'string' ? data.documentType.trim().toUpperCase() : '';
  const userSnap = await db.collection('users').doc(uid).get();
  const userRole = userSnap.exists ? userSnap.data().role : '';
  let subject = resolveVerificationSubject(data, userRole);
  const roleNorm = (userRole || '').trim().toLowerCase();
  if (roleNorm === 'customer' || roleNorm === 'client') {
    subject = 'customer';
  }
  functions.logger.info('createDiditSession start', { uid, documentType, subject });

  const { apiKey, workflowId } = diditEnv();
  if (!apiKey || !workflowId) {
    functions.logger.error('Didit env missing on createDiditSession', {
      hasApiKey: Boolean(apiKey),
      hasWorkflowId: Boolean(workflowId),
    });
    throw verificationFailure(
      'failed-precondition',
      'Didit keys missing on the server. Redeploy: firebase deploy --only functions'
    );
  }

  if (!ALLOWED_DIDIT_DOCUMENT_TYPES.has(documentType)) {
    throw verificationFailure(
      'invalid-argument',
      'Select a valid Philippine government ID type before verifying.'
    );
  }
  const documentLabel =
    data && typeof data.documentLabel === 'string' ? data.documentLabel.trim() : '';

  const body = {
    workflow_id: workflowId,
    vendor_data: uid,
    language: 'en',
    expected_details: {
      expected_document_types: [documentType],
      id_country: 'PHL',
    },
    metadata: {
      government_id_type: documentType,
      government_id_label: documentLabel || documentType,
      country: 'PHL',
      subject,
    },
  };
  if (data && typeof data.callback === 'string' && data.callback.length > 0) {
    body.callback = data.callback;
  }

  let resp;
  try {
    resp = await fetch(DIDIT_SESSION_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      },
      body: JSON.stringify(body),
    });
  } catch (err) {
    functions.logger.error('Didit session request failed', err);
    throw verificationFailure('unavailable', 'Could not reach Didit.');
  }

  const json = await resp.json().catch(() => null);
  const sessionUrl = json && (json.url || json.session_url);
  if (!resp.ok || !sessionUrl) {
    const detail = formatDiditError(json, resp.status);
    functions.logger.error('Didit session error', { status: resp.status, json, detail });
    throw verificationFailure('failed-precondition', detail);
  }

  const verificationPatch = {
    verificationProvider: 'didit',
    diditSessionId: json.session_id || null,
    diditStatus: diditStatusWhenLaunchingHostedFlow(json.status),
    verificationStatus: 'Pending',
    isVerified: false,
    governmentIdTypeCode: documentType,
    governmentIdTypeLabel: documentLabel || documentType,
    verificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    if (subject === 'customer') {
      await db.collection('users').doc(uid).set(
        {
          ...verificationPatch,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } else {
      await db.collection('serviceProviders').doc(uid).set(
        {
          ...verificationPatch,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  } catch (err) {
    functions.logger.error('Failed to store verification session', { subject, err });
    throw verificationFailure(
      'internal',
      'Didit session was created but could not save to your profile. Try again.'
    );
  }

  functions.logger.info('createDiditSession ok', { uid, subject, sessionId: json.session_id || null });
  return { url: sessionUrl, sessionId: json.session_id || null };
}

/** @returns {VerificationFailure} */
function verificationFailure(code, message) {
  return { code, message };
}

function httpStatusForVerificationCode(code) {
  switch (code) {
    case 'unauthenticated':
      return 401;
    case 'invalid-argument':
      return 400;
    case 'failed-precondition':
      return 412;
    case 'unavailable':
      return 503;
    default:
      return 500;
  }
}

// ---------------------------------------------------------------------------
// Google Distance Matrix (driving) — server-side key only.
// Config: GOOGLE_MAPS_API_KEY in functions/.env (enable Distance Matrix API).
// ---------------------------------------------------------------------------

function mapsApiKey() {
  return (process.env.GOOGLE_MAPS_API_KEY || '').trim();
}

function sentimentEnv() {
  return {
    apiUrl: (process.env.SENTIMENT_API_URL || '').trim(),
    apiToken: (process.env.SENTIMENT_API_TOKEN || '').trim(),
    timeoutMs: Math.max(
      1000,
      Number.parseInt((process.env.SENTIMENT_API_TIMEOUT_MS || '10000').trim(), 10) || 10000
    ),
  };
}

function normalizeSentimentLabel(label) {
  const norm = String(label || '')
    .trim()
    .toLowerCase();
  if (norm === 'negative' || norm === 'neutral' || norm === 'positive') return norm;
  return 'neutral';
}

function keywordSentimentFallback(text) {
  const lower = text.toLowerCase();
  const positive = ['great', 'excellent', 'amazing', 'love', 'wonderful', 'fantastic', 'perfect', 'thank', 'care', 'best', 'happy', 'good', 'awesome', 'helpful', 'professional', 'recommend'];
  const negative = ['bad', 'terrible', 'awful', 'worst', 'hate', 'poor', 'rude', 'never', 'disappoint', 'horrible', 'late', 'unprofessional', 'slow', 'mess'];
  let pos = 0;
  let neg = 0;
  for (const w of positive) if (lower.includes(w)) pos += 1;
  for (const w of negative) if (lower.includes(w)) neg += 1;
  const label = pos > neg ? 'positive' : neg > pos ? 'negative' : 'neutral';
  return {
    label,
    confidence: 0.55,
    probabilities: label === 'positive'
      ? { negative: 0.1, neutral: 0.2, positive: 0.7 }
      : label === 'negative'
        ? { negative: 0.7, neutral: 0.2, positive: 0.1 }
        : { negative: 0.15, neutral: 0.7, positive: 0.15 },
    modelVersion: 'keyword-fallback',
    analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
    source: 'keyword',
  };
}

async function predictReviewSentiment(review) {
  const { apiUrl, apiToken, timeoutMs } = sentimentEnv();
  const text = typeof review.comment === 'string' ? review.comment.trim() : '';
  if (!text) return null;

  if (!apiUrl) return keywordSentimentFallback(text);

  const url = apiUrl.endsWith('/predict-sentiment')
    ? apiUrl
    : `${apiUrl.replace(/\/+$/, '')}/predict-sentiment`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(apiToken ? { Authorization: `Bearer ${apiToken}` } : {}),
      },
      body: JSON.stringify({
        review_text: text,
        review_id: review.reviewId || null,
        provider_id: review.providerId || null,
      }),
      signal: controller.signal,
    });
    const json = await resp.json().catch(() => null);
    if (!resp.ok || !json) {
      functions.logger.warn('Sentiment API request failed', {
        status: resp.status,
        body: json,
      });
      return keywordSentimentFallback(text);
    }
    const probabilities = json.probabilities && typeof json.probabilities === 'object'
      ? {
          negative: Number(json.probabilities.negative) || 0,
          neutral: Number(json.probabilities.neutral) || 0,
          positive: Number(json.probabilities.positive) || 0,
        }
      : null;
    return {
      label: normalizeSentimentLabel(json.sentiment),
      confidence: Number(json.confidence) || 0,
      probabilities,
      modelVersion: typeof json.model_version === 'string' ? json.model_version : null,
      analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'lstm',
    };
  } catch (err) {
    functions.logger.warn('Sentiment prediction failed', { err: String(err) });
    return keywordSentimentFallback(text);
  } finally {
    clearTimeout(timer);
  }
}

/**
 * @param {{ lat: number, lng: number }} origin
 * @param {{ id: string, lat: number, lng: number }[]} destinations — max 25
 * @returns {Promise<Record<string, number>>} destination id → km
 */
async function fetchDrivingDistancesKm(origin, destinations) {
  const key = mapsApiKey();
  if (!key) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'GOOGLE_MAPS_API_KEY is not configured for Cloud Functions.'
    );
  }
  if (!origin || typeof origin.lat !== 'number' || typeof origin.lng !== 'number') {
    throw new functions.https.HttpsError('invalid-argument', 'origin lat/lng required.');
  }
  if (!Array.isArray(destinations) || destinations.length === 0) {
    return {};
  }
  if (destinations.length > 25) {
    throw new functions.https.HttpsError('invalid-argument', 'At most 25 destinations per request.');
  }

  const destParam = destinations.map((d) => `${d.lat},${d.lng}`).join('|');
  const url =
    'https://maps.googleapis.com/maps/api/distancematrix/json?' +
    `origins=${origin.lat},${origin.lng}` +
    `&destinations=${encodeURIComponent(destParam)}` +
    '&mode=driving&units=metric' +
    `&key=${encodeURIComponent(key)}`;

  const res = await fetch(url);
  if (!res.ok) {
    functions.logger.error('Distance Matrix HTTP error', { status: res.status });
    throw new functions.https.HttpsError('unavailable', 'Distance service unavailable.');
  }

  const body = await res.json();
  if (body.status !== 'OK') {
    functions.logger.warn('Distance Matrix status', { status: body.status, error: body.error_message });
    throw new functions.https.HttpsError('unavailable', body.error_message || 'Distance Matrix failed.');
  }

  const elements = body.rows?.[0]?.elements;
  if (!Array.isArray(elements)) {
    return {};
  }

  const out = {};
  for (let i = 0; i < destinations.length; i++) {
    const el = elements[i];
    const meters = el?.status === 'OK' ? el.distance?.value : null;
    if (typeof meters === 'number' && meters > 0) {
      out[destinations[i].id] = Math.round((meters / 1000) * 100) / 100;
    }
  }
  return out;
}

exports.getDrivingDistances = functions
  .region(functionsRegion)
  .https.onCall(async (data, context) => {
    const uid = context.auth && context.auth.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    }
    try {
      const distances = await fetchDrivingDistancesKm(data?.origin, data?.destinations);
      return { distances };
    } catch (err) {
      if (err instanceof functions.https.HttpsError) throw err;
      functions.logger.error('getDrivingDistances unexpected error', err);
      throw new functions.https.HttpsError('internal', 'Could not compute driving distances.');
    }
  });

/**
 * Callable: create a Didit hosted verification session for the signed-in
 * provider and return the hosted `url` the client should open.
 */
exports.createDiditSession = functions
  .region(functionsRegion)
  .https.onCall(async (data, context) => {
    try {
      const uid = context.auth && context.auth.uid;
      if (!uid) {
        throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
      }
      return await createDiditSessionCore(uid, data);
    } catch (err) {
      if (err instanceof functions.https.HttpsError) throw err;
      if (err && err.code && err.message) {
        throw new functions.https.HttpsError(err.code, err.message);
      }
      functions.logger.error('createDiditSession unexpected error', err);
      throw new functions.https.HttpsError(
        'internal',
        err && err.message ? String(err.message) : 'Unexpected verification error.'
      );
    }
  });

/**
 * CORS-enabled HTTP endpoint for Flutter web (callable URLs block browser fetch).
 * Auth: Authorization: Bearer <Firebase ID token>
 * Body: { documentType, documentLabel, callback? }
 */
exports.createDiditSessionHttp = functions
  .region(functionsRegion)
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }
      if (req.method !== 'POST') {
        res.status(405).json({ code: 'invalid-argument', error: 'Method not allowed.' });
        return;
      }

      try {
        const authHeader = req.get('Authorization') || '';
        const match = authHeader.match(/^Bearer\s+(.+)$/i);
        if (!match) {
          res.status(401).json({ code: 'unauthenticated', error: 'Sign in required.' });
          return;
        }

        let uid;
        try {
          const decoded = await admin.auth().verifyIdToken(match[1]);
          uid = decoded.uid;
        } catch (err) {
          functions.logger.warn('createDiditSessionHttp invalid token', err);
          res.status(401).json({ code: 'unauthenticated', error: 'Please sign in again.' });
          return;
        }

        const result = await createDiditSessionCore(uid, req.body || {});
        res.status(200).json(result);
      } catch (err) {
        if (err && err.code && err.message) {
          res.status(httpStatusForVerificationCode(err.code)).json({
            code: err.code,
            error: err.message,
          });
          return;
        }
        functions.logger.error('createDiditSessionHttp unexpected error', err);
        res.status(500).json({
          code: 'internal',
          error: err && err.message ? String(err.message) : 'Unexpected verification error.',
        });
      }
    });
  });

/** Human-readable Didit API error for the Flutter snackbar. */
function formatDiditError(json, status) {
  if (!json) {
    return `Didit verification failed (HTTP ${status}). Check API key and workflow in functions/.env.`;
  }
  const raw = json.detail ?? json.message ?? json.error ?? json.errors;
  if (typeof raw === 'string' && raw.trim()) return raw.trim();
  if (Array.isArray(raw)) {
    const parts = raw.map((x) => (typeof x === 'string' ? x : x?.msg ?? x?.message ?? JSON.stringify(x)));
    if (parts.length) return parts.join(' ');
  }
  if (raw && typeof raw === 'object') {
    try {
      return JSON.stringify(raw);
    } catch (_) {
      /* fall through */
    }
  }
  return `Didit verification failed (HTTP ${status}). Confirm DIDIT_API_KEY and DIDIT_WORKFLOW_ID, then redeploy functions.`;
}

/** Recursively sort object keys to reproduce Didit's canonical JSON form. */
function sortKeys(obj) {
  if (Array.isArray(obj)) return obj.map(sortKeys);
  if (obj !== null && typeof obj === 'object') {
    return Object.keys(obj)
      .sort()
      .reduce((acc, key) => {
        acc[key] = sortKeys(obj[key]);
        return acc;
      }, {});
  }
  return obj;
}

/** Match Didit: whole-valued floats are serialised as integers. */
function shortenFloats(data) {
  if (Array.isArray(data)) return data.map(shortenFloats);
  if (data !== null && typeof data === 'object') {
    return Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, shortenFloats(v)])
    );
  }
  if (typeof data === 'number' && !Number.isInteger(data) && data % 1 === 0) {
    return Math.trunc(data);
  }
  return data;
}

function timingSafeEqualHex(a, b) {
  if (!a || !b) return false;
  const ab = Buffer.from(a, 'utf8');
  const bb = Buffer.from(b, 'utf8');
  return ab.length === bb.length && crypto.timingSafeEqual(ab, bb);
}

/**
 * Verify a Didit webhook. Prefers X-Signature-V2 (canonical JSON), then falls
 * back to X-Signature over the raw bytes. Rejects stale (>5 min) deliveries.
 */
function verifyDiditWebhook(req, secret) {
  const timestamp = req.get('X-Timestamp');
  if (!timestamp) return false;
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - parseInt(timestamp, 10)) > 300) return false;

  const sigV2 = req.get('X-Signature-V2');
  if (sigV2) {
    const canonical = JSON.stringify(sortKeys(shortenFloats(req.body)));
    const expected = crypto.createHmac('sha256', secret).update(canonical, 'utf8').digest('hex');
    if (timingSafeEqualHex(expected, sigV2)) return true;
  }

  const sigRaw = req.get('X-Signature');
  if (sigRaw && req.rawBody) {
    const expected = crypto.createHmac('sha256', secret).update(req.rawBody).digest('hex');
    if (timingSafeEqualHex(expected, sigRaw)) return true;
  }

  return false;
}

/**
 * HTTPS endpoint Didit calls when a session status changes. Verifies the
 * signature, then writes the result onto serviceProviders/{vendor_data}.
 * Auto-approves on "Approved"; admins can still override afterwards.
 */
exports.diditWebhook = functions.region(functionsRegion).https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const secret = diditEnv().webhookSecret;
  if (!secret) {
    functions.logger.error('DIDIT_WEBHOOK_SECRET not configured');
    res.status(500).send('Not configured');
    return;
  }

  if (!verifyDiditWebhook(req, secret)) {
    res.status(401).send('Invalid signature');
    return;
  }

  const event = req.body || {};
  if (event.webhook_type !== 'status.updated') {
    res.status(200).json({ ok: true, ignored: event.webhook_type });
    return;
  }

  const userId = event.vendor_data;
  const diditStatus = event.status;
  if (!userId || !diditStatus) {
    res.status(200).json({ ok: true, ignored: 'missing vendor_data or status' });
    return;
  }

  const meta = event.metadata && typeof event.metadata === 'object' ? event.metadata : {};
  let subject = typeof meta.subject === 'string' ? meta.subject.trim().toLowerCase() : '';
  const userSnap = await db.collection('users').doc(userId).get();
  const userRole = userSnap.exists ? userSnap.data().role : '';
  const roleNorm = (userRole || '').trim().toLowerCase();
  if (roleNorm === 'customer' || roleNorm === 'client') {
    subject = 'customer';
  } else if (subject !== 'customer' && subject !== 'provider') {
    subject = resolveVerificationSubject({}, userRole);
  }

  const mapped = mapDiditStatus(diditStatus);
  const patch = {
    verificationProvider: 'didit',
    diditStatus,
    diditSessionId: event.session_id || null,
    isVerified: mapped.isVerified,
    verificationStatus: mapped.verificationStatus,
    verificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    if (subject === 'customer') {
      await db.collection('users').doc(userId).set(patch, { merge: true });
    } else {
      await db.collection('serviceProviders').doc(userId).set(patch, { merge: true });
    }
  } catch (err) {
    functions.logger.error('Failed to update verification', { subject, err });
    // 5xx so Didit retries.
    res.status(500).send('Update failed');
    return;
  }

  res.status(200).json({ ok: true });
});

/**
 * Callable: submit milestone feedback (customer→provider or provider→customer).
 * Uses Admin SDK so review writes succeed even when client Firestore rules are
 * stale or not yet deployed.
 */
exports.submitMilestoneReview = functions
  .region(functionsRegion)
  .https.onCall(async (data, context) => {
    const uid = context.auth && context.auth.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    }

    const bookingId = data && typeof data.bookingId === 'string' ? data.bookingId.trim() : '';
    const reviewerRole =
      data && typeof data.reviewerRole === 'string' ? data.reviewerRole.trim().toLowerCase() : '';
    const rating = data && typeof data.rating === 'number' ? data.rating : NaN;
    const comment = data && typeof data.comment === 'string' ? data.comment.trim() : '';

    if (!bookingId) {
      throw new functions.https.HttpsError('invalid-argument', 'bookingId is required.');
    }
    if (reviewerRole !== 'customer' && reviewerRole !== 'provider') {
      throw new functions.https.HttpsError('invalid-argument', 'reviewerRole must be customer or provider.');
    }
    if (!Number.isFinite(rating) || rating < 1 || rating > 5) {
      throw new functions.https.HttpsError('invalid-argument', 'Rating must be between 1 and 5.');
    }

    const bookingSnap = await db.collection('bookings').doc(bookingId).get();
    if (!bookingSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Booking not found.');
    }
    const booking = bookingSnap.data() || {};

    const status = String(booking.status || '').trim().toLowerCase();
    const milestoneComplete =
      status === 'milestone complete' ||
      status === 'completed' ||
      booking.completedAt != null;
    if (!milestoneComplete) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Reviews unlock after the provider marks the milestone complete.'
      );
    }

    if (reviewerRole === 'customer' && booking.customerId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only the customer can leave this review.');
    }
    if (reviewerRole === 'provider' && booking.providerId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only the provider can leave this review.');
    }

    const existingSnap = await db.collection('reviews').where('bookingId', '==', bookingId).limit(25).get();
    const alreadyReviewed = existingSnap.docs.some((d) => (d.data().reviewerId || '') === uid);
    if (alreadyReviewed) {
      throw new functions.https.HttpsError('already-exists', 'You already reviewed this milestone.');
    }

    const revieweeId = reviewerRole === 'customer' ? booking.providerId : booking.customerId;
    const payload = {
      bookingId,
      customerId: booking.customerId,
      providerId: booking.providerId,
      serviceId: booking.serviceId || '',
      rating: Math.round(rating),
      reviewerId: uid,
      revieweeId,
      reviewerRole,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (comment) payload.comment = comment;
    if (booking.contractId) payload.contractId = booking.contractId;
    if (booking.milestoneNumber != null) payload.milestoneNumber = booking.milestoneNumber;

    const ref = await db.collection('reviews').add(payload);
    return { reviewId: ref.id };
  });

/**
 * Recalculate Bayesian average for a provider from reviews subcollection pattern
 * or denormalized reviews query. This stub updates `serviceProviders/{id}` using
 * a single aggregate read of `reviews` where providerId matches.
 */
exports.onReviewCreated = functions.firestore
  .document('reviews/{reviewId}')
  .onCreate(async (snap) => {
    const review = snap.data() || {};
    review.reviewId = snap.id;
    const providerId = review.providerId;
    const reviewerRole = (review.reviewerRole || '').toLowerCase();
    const isCustomerReview = reviewerRole === 'customer';

    const sentiment = await predictReviewSentiment(review);
    if (sentiment) {
      await snap.ref.set(
        {
          sentiment,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    if (!providerId || !isCustomerReview) return null;

    const reviewsSnap = await db
      .collection('reviews')
      .where('providerId', '==', providerId)
      .where('reviewerRole', '==', 'customer')
      .get();

    let sum = 0;
    let n = 0;
    reviewsSnap.forEach((d) => {
      const r = d.data().rating;
      if (typeof r === 'number') {
        sum += r;
        n += 1;
      }
    });

    const globalSnap = await db.collection('serviceProviders').limit(200).get();
    let gSum = 0;
    let gN = 0;
    globalSnap.forEach((d) => {
      const v = d.data().averageRating;
      if (typeof v === 'number' && v > 0) {
        gSum += v;
        gN += 1;
      }
    });
    const m = gN === 0 ? 3.5 : gSum / gN;
    const bayes = (C * m + sum) / (C + n);

    return db.collection('serviceProviders').doc(providerId).update({
      averageRating: Number(bayes.toFixed(2)),
      reviewCount: n,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

exports.onMessageCreated = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap) => {
    const message = snap.data() || {};
    const receiverId = message.receiverId;
    const senderId = message.senderId;
    if (!receiverId || !senderId || receiverId === senderId) return null;

    const text = (message.messageText || '').toString().trim();
    const preview = text.length > 120 ? `${text.slice(0, 117)}…` : text;
    const title = 'New message';
    const body = preview.length > 0 ? preview : 'You have a new message.';

    return db.collection('notifications').add({
      userId: receiverId,
      title,
      message: body,
      notificationType: 'Message',
      relatedBookingId: message.bookingId || '',
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

exports.onBookingCreated = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snap) => {
    const booking = snap.data();
    const providerId = booking.providerId;
    if (!providerId) return null;

    const providerUserSnap = await db.collection('serviceProviders').doc(providerId).get();
    const userId = providerUserSnap.data()?.userId;
    if (!userId) return null;

    return db.collection('notifications').add({
      userId,
      title: 'New booking request',
      message: 'A customer submitted a new booking request.',
      notificationType: 'Booking Request',
      relatedBookingId: snap.id,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
