'use strict';

const crypto = require('node:crypto');
const complete = b => ['completed', 'milestone complete'].includes(String(b.status).toLowerCase());
const active = b => ['accepted', 'in progress', 'awaiting confirmation'].includes(String(b.status).toLowerCase());
const millis = v => v && typeof v.toMillis === 'function' ? v.toMillis() : Number(v);
function windowFor(b) {
  const start = millis(b.scheduledDate);
  const end = b.scheduledEndDate ? millis(b.scheduledEndDate) : start + (Number(b.durationHours) || 1) * 3600000;
  return { start, end };
}
function overlaps(a, b) {
  const periods = b => {
    const bounds=windowFor(b);
    if (!b.agreement || !b.numberOfDays || !b.hoursPerDay) return [bounds];
    return Array.from({length:b.numberOfDays},(_,i)=>({start:bounds.start+i*86400000,end:bounds.start+i*86400000+b.hoursPerDay*3600000}));
  };
  return periods(a).some(x=>periods(b).some(y=>x.start<y.end && y.start<x.end));
}
function validWindow(start, end, now = Date.now()) {
  return Number.isFinite(start) && Number.isFinite(end) && start > now && end > start && end - start <= 24 * 3600000;
}
function certificateFamily(category, title) {
  return require('./marketplace_policy').serviceFamily(category, title);
}
function hasMatchingCertificate(profile, category, title, now = new Date()) {
  const family = certificateFamily(category, title);
  if (!profile) return false;
  const approved = new Set(profile.approvedCertificationIds || []);
  const policy=require('./marketplace_policy');
  if(family) return (profile.certificationHistory || []).some(c => policy.eligibleCertificate(c, approved, family, now));
  return Object.values(profile.approvedServiceProposals || {}).some(grant => grant.status==='Approved'
    && grant.reviewedBy && grant.reviewedAt && policy.normalize(grant.category)===policy.normalize(category)
    && policy.normalize(grant.serviceTitle)===policy.normalize(title)
    && (profile.certificationHistory || []).some(c=>policy.normalize(c.name)===policy.normalize(grant.qualificationName)
      && policy.eligibleTesdaCertificate(c,approved,now)));
}
function distanceKm(a, b) {
  const rad = x => x * Math.PI / 180;
  const dLat = rad(b.latitude - a.latitude), dLng = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}
function csvCell(v) {
  let text = v == null ? '' : String(v);
  if (/^[\s]*[=+@\-]/.test(text)) text = `'${text}`;
  return `"${text.replace(/"/g, '""')}"`;
}
const tokenId = token => crypto.createHash('sha256').update(token).digest('hex');
module.exports = { complete, active, millis, windowFor, overlaps, validWindow, certificateFamily, hasMatchingCertificate, distanceKm, csvCell, tokenId };
