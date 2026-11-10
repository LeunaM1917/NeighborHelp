'use strict';
const { FieldValue, Timestamp, FieldPath } = require('firebase-admin/firestore');
const crypto = require('node:crypto');
const { complete, active, hasMatchingCertificate, tokenId } = require('./domain');
const reviewStatusNotifications = require('./review_status_notifications');

module.exports = function platformOperations({ db, admin, functions, region, messaging = require('firebase-admin/messaging').getMessaging }) {
  const out = {};
  const stamp = () => FieldValue.serverTimestamp();
  const publicProfile = (id, u) => ({ userId: id, fullName: u.fullName || '', profilePhotoUrl: u.profilePhotoUrl || null,
    bio: u.bio || '', role: u.role || 'Customer', accountStatus: u.accountStatus || 'Pending',
    isVerified: Boolean(u.isVerified), verificationStatus: u.verificationStatus || 'Pending',
    createdAt: u.createdAt?.toMillis() || 0, updatedAt: u.updatedAt?.toMillis() || 0 });
  async function publicProvider(id, p) {
    const area=require('./provider_area').publicArea(p);
    if(!area)return null;
    const owner = (await db.collection('users').doc(p.userId || id).get()).data();
    if (owner?.accountStatus !== 'Active' || !(p.isVerified || p.verificationStatus === 'Approved')) return null;
    const services = await db.collection('services').where('providerId', '==', id).get();
    const eligible = services.docs.filter(d => { const s = d.data(); return s.isActive && s.approvalStatus === 'Approved' && hasMatchingCertificate(p, s.category, s.serviceTitle); });
    if (!eligible.length) return null;
    const {serviceFamily,eligibleCertificate} = require('./marketplace_policy');
    const result = { providerId: id, marketplacePolicyVersion:3, eligibleServiceIds: eligible.map(d => d.id),eligibleServiceExpiries:{},...area };
    for(const doc of eligible) {
      const s=doc.data(), family=serviceFamily(s.category,s.serviceTitle);
      const certificates=(p.certificationHistory || []).filter(c => eligibleCertificate(c,new Set(p.approvedCertificationIds || []),family));
      result.eligibleServiceExpiries[doc.id]=Math.max(...certificates.map(c => new Date(`${c.expirationDate}T23:59:59.999+08:00`).getTime()));
    }
    for (const field of ['userId', 'bio', 'averageRating', 'reviewCount', 'completedBookings', 'acceptedBookings',
      'isVerified', 'verificationStatus', 'education', 'educationHistory', 'employmentHistory', 'portfolioUrls', 'portfolioProjects',
      'videoIntroUrl', 'otherExperiences', 'linkedAccounts', 'profileTraits', 'weeklyAvailability', 'approvedCertificationIds']) if (p[field] !== undefined) result[field] = p[field];
    result.timeOff=(p.timeOff||[]).filter(b=>b.end?.toMillis()>Date.now()).map(b=>({startMs:b.start.toMillis(),endMs:b.end.toMillis()}));
    result.createdAt = p.createdAt?.toMillis() || 0;
    result.updatedAt = p.updatedAt?.toMillis() || 0;
    result.certificationHistory = (p.certificationHistory || []).filter(c => (p.approvedCertificationIds || []).includes(c.id)).map(c => ({ id: c.id, name: c.name || '', provider: c.provider || '', issueDate: c.issueDate || '', expirationDate: c.expirationDate || '', status: 'Approved' }));
    return result;
  }
  const eventKey = s => crypto.createHash('sha256').update(s).digest('hex');
  const fail = (code, msg) => { throw new functions.https.HttpsError(code, msg); };
  async function assertAdmin(context) {
    if (!context.auth) fail('unauthenticated', 'Sign in required.');
    const user = (await db.collection('users').doc(context.auth.uid).get()).data();
    if (user?.role !== 'Administrator' || user.accountStatus !== 'Active') fail('permission-denied', 'An active administrator account is required.');
    await require('./admin_security').assertAdminToken(context,fail,db);
    return user;
  }
  async function notify(key, userId, title, message, bookingId = '', type = 'Update') {
    if (!userId) return;
    await db.collection('notifications').doc(eventKey(`${key}:${userId}`)).create({ userId, title, message, relatedBookingId: bookingId,
      notificationType: type, isRead: false, createdAt: stamp() }).catch(e => { if (e.code !== 6) throw e; });
  }
  out.bookingCommand = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(require('./booking_commands')({ db, admin, functions }));
  out.inquiryCommand = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(require('./inquiry_commands')({db, functions}));
  out.certificateCommand = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(require('./certificate_commands')({db, functions}));
  out.contractCommand = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(require('./contract_commands')({db,functions}));
  out.providerAvailability = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(require('./availability_command')({db,functions}));
  out.providerTimeOff=functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK==='true'}).https.onCall(require('./time_off_commands')({db,functions}));
  out.providerArea=functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK==='true'}).https.onCall(require('./provider_area').command({db,functions}));
  out.migrateProviderLocations=functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK==='true'}).https.onCall(async(data,context)=>{
    await assertAdmin(context);
    return require('./provider_location_migration')(db,{cursor:String(data.cursor||''),apply:data.apply===true});
  });
  out.expireContractOffers=functions.region(region).pubsub.schedule('every 15 minutes').onRun(()=>require('./offer_expiry').sweep(db));
  out.agreementCommand = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(require('./agreement_commands')({db,functions}));
  out.paymentCommand = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(require('./payment_commands')({db,functions}));
  out.reportCommand = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(require('./report_commands')({db,functions}));
  out.settlementCommand=functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK==='true'}).https.onCall(require('./settlement_commands')({db,functions}));
  const workCases=require('./work_cases')({db,functions});
  out.workCaseCommand=functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK==='true'}).https.onCall(workCases.command);
  out.unresolvedWorkReminders=functions.region(region).pubsub.schedule('every 30 minutes').onRun(workCases.sweep);
  out.cleanupAbuseLimits=functions.region(region).pubsub.schedule('every 6 hours').onRun(async()=>{
    for(const collection of ['rateLimits','inquiryUploads','reportUploads']) {
      const expired=await db.collection(collection).where('expiresAt','<',Timestamp.now()).limit(450).get();
      if(!expired.empty){const batch=db.batch();for(const doc of expired.docs)batch.delete(doc.ref);await batch.commit();}
    }
    return null;
  });
  // Refresh old projections and hide expired/unsupported listings without deleting history.
  out.enforceMarketplacePolicy = functions.region(region).pubsub.schedule('every 6 hours').onRun(async () => {
    const providers=await db.collection('serviceProviders').get();
    for(const doc of providers.docs) {
      const p=doc.data(),services=await db.collection('services').where('providerId','==',doc.id).get();
      for(const service of services.docs) {
        const s=service.data();
        if(s.isActive && !hasMatchingCertificate(p,s.category,s.serviceTitle)) await service.ref.update({isActive:false,approvalStatus:'Pending',rejectionReason:'A matching current TESDA registry review is required under the updated service policy.',updatedBy:'system',updatedAt:stamp()});
      }
      const projected=await publicProvider(doc.id,p),ref=db.doc(`publicProviders/${doc.id}`);
      if(projected) await ref.set(projected); else await ref.delete();
    }
    return null;
  });
  out.registerPushDevice = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(async (data, context) => {
    if (!context.auth) fail('unauthenticated', 'Sign in required.');
    const uid = context.auth.uid, token = String(data?.token || '');
    if (token.length < 20 || token.length > 4096) fail('invalid-argument', 'Invalid device token.');
    const id = tokenId(token), binding = db.collection('deviceRegistrations').doc(id);
    return db.runTransaction(async tx => {
      const existing = (await tx.get(binding)).data();
      const actor = (await tx.get(db.collection('users').doc(uid))).data();
      const device = db.collection('users').doc(uid).collection('devices').doc(id);
      if (data.action === 'unregister') {
        if (existing?.userId === uid) { tx.delete(device); tx.delete(binding); }
      } else {
        if (actor?.accountStatus !== 'Active') fail('permission-denied', 'An active account is required.');
        if (existing?.userId && existing.userId !== uid) tx.delete(db.collection('users').doc(existing.userId).collection('devices').doc(id));
        tx.set(binding, {userId: uid, updatedAt: stamp()});
        tx.set(device, {token, platform: String(data.platform || '').slice(0, 32), updatedAt: stamp()});
      }
      return {id};
    });
  });

  out.onBookingUpdated = functions.region(region).firestore.document('bookings/{bookingId}').onUpdate(async (change, context) => {
    const a = change.before.data(), b = change.after.data();
    const statusChanged = a.status !== b.status;
    const requestChanged = JSON.stringify(a.rescheduleRequest || null) !== JSON.stringify(b.rescheduleRequest || null);
    // Expiry notifications are committed with the transition, once per participant.
    if(b.status==='Expired')return null;
    if (!statusChanged && !requestChanged && a.scheduledDate?.toMillis?.() === b.scheduledDate?.toMillis?.()) return null;
    const title = statusChanged ? `Booking ${b.status}` : b.rescheduleRequest ? 'Reschedule requested' : 'Reschedule response';
    const message = statusChanged ? b.status === 'Changes Requested' ? `The provider requested changes: ${b.changeRequest}. Discuss the changes and send a new offer.` : `Your booking is now ${b.status.toLowerCase()}.` : b.rescheduleRequest ? 'The customer proposed a new date. Open the booking to respond.' : 'Open your booking to check the agreed schedule.';
    await Promise.all([b.customerId, b.providerId].filter(uid => uid !== b.updatedBy).map(uid => notify(context.eventId, uid, title, message, change.after.id, 'Booking Update')));
    if (complete(b) && !complete(a)) await Promise.all([b.customerId, b.providerId].map(uid => notify(`${context.eventId}:review`, uid, 'Leave a review', 'Your service is complete. Share feedback about this booking.', change.after.id, 'Review Request')));
    return null;
  });
  for (const collection of ['users', 'serviceProviders', 'services', 'bookingUserReports']) {
    out[`audit${collection[0].toUpperCase()}${collection.slice(1)}`] = functions.region(region).firestore.document(`${collection}/{id}`).onWrite(async (change, context) => {
      const before = change.before.data() || {}, after = change.after.data() || {};
      // Ignore presence updates and server aggregate recalculations.
      const changed = Object.keys({ ...before, ...after }).filter(k => !['lastActive', 'updatedAt', 'updatedBy', 'updatedByRole', 'averageRating', 'reviewCount', 'completedBookings', 'acceptedBookings'].includes(k) && JSON.stringify(before[k]) !== JSON.stringify(after[k]));
      const aggregateChanged = collection === 'serviceProviders' && ['averageRating', 'reviewCount', 'completedBookings', 'acceptedBookings'].some(k => before[k] !== after[k]);
      if (!changed.length && !aggregateChanged) return null;
      if (collection === 'users') {
        const publicRef = db.collection('publicProfiles').doc(context.params.id);
        if (change.after.exists) await publicRef.set(publicProfile(context.params.id, after));
        else await publicRef.delete();
      }
      const providerId = collection === 'serviceProviders' || collection === 'users' ? context.params.id : collection === 'services' ? after.providerId || before.providerId : null;
      let reviewOwnerId = collection === 'users' ? context.params.id : after.userId || context.params.id;
      if (providerId) {
        const provider = (await db.collection('serviceProviders').doc(providerId).get()).data();
        if (collection === 'services') reviewOwnerId = provider?.userId || providerId;
        const projected = provider ? await publicProvider(providerId, provider) : null;
        const ref = db.collection('publicProviders').doc(providerId);
        if (projected) await ref.set(projected); else await ref.delete();
      }
      if (!changed.length) return null;
      const identityChanged = before.verificationStatus !== after.verificationStatus || before.isVerified !== after.isVerified;
      const createdBy = !change.before.exists ? collection === 'users' ? context.params.id : after.userId || after.providerId || after.reporterId : null;
      const actorId = identityChanged && before.diditStatus !== after.diditStatus ? 'didit' : after.updatedBy || createdBy || 'system';
      const actor = !['system', 'didit'].includes(actorId) ? (await db.collection('users').doc(actorId).get()).data() : null;
      await db.collection('auditLogs').doc(eventKey(context.eventId)).set({ actorId, actorRole: actorId === 'didit' ? 'Identity service' : actor?.role || 'System',
        action: `${collection}.${!change.before.exists ? 'created' : !change.after.exists ? 'deleted' : 'updated'}`, collection,
        referenceId: context.params.id, changedFields: changed, createdAt: stamp() });
      if (change.after.exists) {
        const notices = reviewStatusNotifications({collection, id: context.params.id, before, after, ownerId: reviewOwnerId});
        for (const notice of notices) {
          if (!notice.data.userId) continue;
          await db.collection('notifications').doc(eventKey(`${context.eventId}:${collection}:${notice.key}:${notice.data.userId}`))
            .create({...notice.data, isRead: false, createdAt: stamp()})
            .catch(e => { if (e.code !== 6) throw e; });
        }
      }
      return null;
    });
  }
  out.deliverPushNotification = functions.region(region).firestore.document('notifications/{id}').onCreate(async (snap) => {
    const n = snap.data();
    if (n.pushEnabled === false) return null;
    const devices = await db.collection('users').doc(n.userId).collection('devices').get();
    if (devices.empty) return null;
    // Each device is sent once per trigger invocation; the notification id lets
    // clients coalesce a retried delivery into the same visible notification.
    for (let i = 0; i < devices.size; i += 500) {
      const docs = devices.docs.slice(i, i + 500);
      const result = await messaging().sendEachForMulticast({ tokens: docs.map(d => d.data().token),
        notification: { title: n.title, body: n.message }, data: { notificationId: snap.id, bookingId: n.relatedBookingId || '',inquiryId:n.relatedInquiryId || '' },
        android: { notification: { tag: snap.id } }, webpush: { notification: { tag: snap.id } } });
      await Promise.all(result.responses.map((r, index) => !r.success && ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(r.error?.code) ? docs[index].ref.delete() : Promise.resolve()));
    }
    return null;
  });
  out.queueAnnouncement = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(async (data, context) => {
    await assertAdmin(context);
    const title = String(data?.title || '').trim(), message = String(data?.message || '').trim();
    const when = Number(data?.scheduledAt);
    if (!title || title.length > 150 || !message || message.length > 3000 || !Number.isFinite(when) || when < Date.now()) fail('invalid-argument', 'Enter a title, message and future send time.');
    if (!['All users', 'Customers only', 'Providers only', 'specific'].includes(data.audience)) fail('invalid-argument', 'Choose a valid audience.');
    if (data.audience === 'specific' && !(await db.collection('users').doc(String(data.userId || '')).get()).exists) fail('not-found', 'Target user not found.');
    const ref = await db.collection('scheduledAnnouncements').add({ title, message, audience: data.audience, userId: String(data.userId || ''), pushEnabled: data.pushEnabled !== false,
      scheduledAt: Timestamp.fromMillis(when), status: 'Scheduled', createdBy: context.auth.uid, createdAt: stamp() });
    await db.collection('auditLogs').add({ actorId: context.auth.uid, actorRole: 'Administrator', action: 'notification.scheduled', collection: 'scheduledAnnouncements', referenceId: ref.id, createdAt: stamp() });
    return { id: ref.id };
  });
  out.appointmentReminders = functions.region(region).pubsub.schedule('every 15 minutes').timeZone('Asia/Manila').onRun(async () => {
    const now = Date.now();
    const announcements = await db.collection('scheduledAnnouncements').where('status', '==', 'Scheduled')
      .where('scheduledAt', '<=', Timestamp.fromMillis(now)).limit(20).get();
    for (const announcement of announcements.docs) {
      const a = announcement.data();
      const users = a.audience === 'specific' ? [await db.collection('users').doc(a.userId).get()] : (await db.collection('users').get()).docs;
      const audience = users.filter(d => d.exists && d.data().accountStatus === 'Active' && (a.audience === 'Customers only' ? d.data().role === 'Customer' : a.audience === 'Providers only' ? d.data().role === 'Provider' : ['Customer', 'Provider', 'Administrator'].includes(d.data().role)));
      for (let i = 0; i < audience.length; i += 25) await Promise.all(audience.slice(i, i + 25).map(d => db.collection('notifications').doc(eventKey(`announcement:${announcement.id}:${d.id}`)).create({ userId: d.id, title: a.title, message: a.message, notificationType: 'Announcement', pushEnabled: a.pushEnabled !== false, isRead: false, createdAt: stamp() }).catch(e => { if (e.code !== 6) throw e; })));
      await announcement.ref.update({status: 'Sent', sentAt: stamp()});
    }
    const due = await db.collection('bookings').where('scheduledDate', '>=', Timestamp.fromMillis(now))
      .where('scheduledDate', '<=', Timestamp.fromMillis(now + 60 * 60000)).get();
    for (const d of due.docs) {
      const b = d.data();
      if (!active(b)) continue;
      await Promise.all([b.customerId, b.providerId].map(uid => {
        const ref = db.collection('notifications').doc(eventKey(`reminder:${d.id}:${b.scheduledDate.toMillis()}:${uid}`));
        return ref.create({ userId: uid, title: 'Upcoming appointment', message: 'Your appointment starts within the next hour.',
          relatedBookingId: d.id, notificationType: 'Reminder', isRead: false, createdAt: stamp() }).catch(e => { if (e.code !== 6) throw e; });
      }));
    }
    return null;
  });
  out.adminDataOperation = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(async (data, context) => {
    await assertAdmin(context);
    const { action, collection } = data || {};
    const allowed = ['bookings', 'services', 'reviews', 'notifications', 'bookingUserReports', 'auditLogs', 'users', 'serviceProviders'];
    if (!allowed.includes(collection)) fail('invalid-argument', 'Unsupported collection.');
    if (action === 'recordExport') {
      await db.collection('auditLogs').add({ actorId: context.auth.uid, actorRole: 'Administrator', action: 'data.export', collection,
        recordCount: Math.max(0, Math.min(100000, Number(data.count) || 0)), createdAt: stamp() });
      return { ok: true };
    }
    if (!['archive', 'restore', 'listArchived'].includes(action) || !['bookings', 'notifications', 'bookingUserReports'].includes(collection)) fail('invalid-argument', 'Only closed bookings, resolved reports, and notifications can be archived.');
    if (action === 'listArchived') {
      const rows = await db.collection(collection).where('archived', '==', true).limit(100).get();
      return { records: rows.docs.map(d => ({ id: d.id, archivedAt: d.data().archivedAt?.toDate().toISOString(), status: d.data().status || d.data().title || '', reason: d.data().archiveReason || '' })) };
    }
    const ids = [...new Set(data.ids || [])];
    if (!ids.length || ids.length > 50 || ids.some(id => typeof id !== 'string' || id.includes('/'))) fail('invalid-argument', 'Select between 1 and 50 records.');
    if (String(data.reason || '').trim().length < 10) fail('invalid-argument', 'Provide a retention reason of at least 10 characters.');
    return db.runTransaction(async tx => {
      const refs = ids.map(id => db.collection(collection).doc(id));
      const docs = await tx.getAll(...refs);
      for (const d of docs) {
        if (!d.exists) fail('not-found', 'A selected record no longer exists.');
        const row = d.data();
        if (action === 'archive') {
          const closed = collection === 'bookings' ? complete(row) || ['cancelled', 'declined'].includes(String(row.status).toLowerCase()) : collection === 'bookingUserReports' ? ['resolved', 'dismissed', 'closed'].includes(String(row.status).toLowerCase()) : row.isRead;
          const date = row.updatedAt || row.createdAt;
          if (!closed || !date || date.toMillis() > Date.now() - 180 * 86400000) fail('failed-precondition', 'Archive only closed/read records last updated at least 180 days ago.');
        }
      }
      for (const d of docs) tx.update(d.ref, { archived: action === 'archive', archivedAt: action === 'archive' ? stamp() : FieldValue.delete(),
        archiveReason: String(data.reason).trim(), updatedBy: context.auth.uid, updatedByRole: 'Administrator' });
      tx.create(db.collection('auditLogs').doc(), { actorId: context.auth.uid, actorRole: 'Administrator', action: `data.${action}`, collection,
        referenceIds: ids, reason: String(data.reason).trim(), createdAt: stamp() });
      return { count: ids.length };
    });
  });
  out.recordSessionEvent = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(async (data, context) => {
    if (!context.auth) fail('unauthenticated', 'Sign in required.');
    const user = (await db.collection('users').doc(context.auth.uid).get()).data();
    if (!user || user.accountStatus !== 'Active') fail('permission-denied', 'Account is restricted.');
    if (!['login', 'logout', 'timeout'].includes(data?.action)) fail('invalid-argument', 'Unknown session event.');
    await db.collection('auditLogs').add({ actorId: context.auth.uid, actorRole: user.role, action: `session.${data.action}`, collection: 'users', referenceId: context.auth.uid, createdAt: stamp() });
    return { ok: true };
  });
  // Read-through for historical profiles, so rollout never depends on a data migration.
  out.getPublicDirectory = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(async (data, context) => {
    if (!context.auth) fail('unauthenticated', 'Sign in required.');
    const actor = (await db.collection('users').doc(context.auth.uid).get()).data();
    if (actor?.accountStatus !== 'Active') fail('permission-denied', 'An active account is required.');
    if (data?.userId) {
      const doc = await db.collection('users').doc(String(data.userId)).get();
      return { records: doc.exists ? [publicProfile(doc.id, doc.data())] : [] };
    }
    let query = db.collection('users').orderBy(FieldPath.documentId()).limit(500);
    if (data?.after) query = query.startAfter(String(data.after));
    const docs = await query.get();
    return { records: docs.docs.map(d => publicProfile(d.id, d.data())), after: docs.size === 500 ? docs.docs.at(-1).id : null };
  });
  out.getPublicProviders = functions.region(region).runWith({enforceAppCheck:process.env.ENFORCE_APP_CHECK === 'true'}).https.onCall(async (data, context) => {
    if (!context.auth) fail('unauthenticated', 'Sign in required.');
    const actor = (await db.collection('users').doc(context.auth.uid).get()).data();
    if (actor?.accountStatus !== 'Active') fail('permission-denied', 'An active account is required.');
    let docs;
    if (data?.userId) {
      const d = await db.collection('serviceProviders').doc(String(data.userId)).get();
      docs = d.exists ? [d] : [];
    } else {
      let q = db.collection('serviceProviders').orderBy(FieldPath.documentId()).limit(100);
      if (data?.after) q = q.startAfter(String(data.after));
      docs = (await q.get()).docs;
    }
    const records = (await Promise.all(docs.map(d => publicProvider(d.id, d.data())))).filter(Boolean);
    return { records, after: !data?.userId && docs.length === 100 ? docs.at(-1).id : null };
  });
  return out;
};
