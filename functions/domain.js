'use strict';

const crypto = require('node:crypto');
const complete = b => ['completed', 'milestone complete'].includes(String(b.status).toLowerCase());
const active = b => ['accepted', 'in progress'].includes(String(b.status).toLowerCase());
const millis = v => v && typeof v.toMillis === 'function' ? v.toMillis() : Number(v);
function windowFor(b) {
  const start = millis(b.scheduledDate);
  const end = b.scheduledEndDate ? millis(b.scheduledEndDate) : start + (Number(b.durationHours) || 1) * 3600000;
  return { start, end };
}
function overlaps(a, b) {
  const x = windowFor(a), y = windowFor(b);
  return x.start < y.end && y.start < x.end;
}
function validWindow(start, end, now = Date.now()) {
  return Number.isFinite(start) && Number.isFinite(end) && start > now && end > start && end - start <= 24 * 3600000;
}
function certificateFamily(category, title) {
  const text = `${category} ${title}`.toLowerCase();
  const families = {
    electrical: /electric|wiring/,
    plumbing: /plumb/,
    carpentry: /carpen|woodwork/,
    aircon: /aircon|air.condition|hvac|refrigerat|refrigerant/,
    computer: /computer|laptop|desktop|network|ict/,
    welding: /weld|metalwork/,
    gas: /gas line|gas fitting/,
    appliance: /appliance/,
  };
  for (const [family, pattern] of Object.entries(families)) if (pattern.test(text)) return family;
  return /repair.*technical|technical.*service/.test(text) ? 'technical' : null;
}
function hasMatchingCertificate(profile, category, title, now = new Date()) {
  const family = certificateFamily(category, title);
  if (!family) return true;
  const approved = new Set(profile.approvedCertificationIds || []);
  return (profile.certificationHistory || []).some(c => {
    if (!approved.has(c.id)) return false;
    if (c.expirationDate && new Date(`${c.expirationDate}T23:59:59+08:00`) < now) return false;
    const text = `${c.name || ''} ${c.description || ''}`;
    const patterns = {
      electrical: /electric|wiring/i, plumbing: /plumb/i, carpentry: /carpen|woodwork/i,
      aircon: /aircon|air.condition|hvac|refrigerat|rac servicing/i,
      computer: /computer|hardware|css nc|ict|network/i, welding: /weld|metalwork/i,
      gas: /gas|pipefitting/i, appliance: /appliance|electronic.*servic/i,
      technical: /repair|technical|servicing/i,
    };
    return patterns[family].test(text) && Boolean(c.url);
  });
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
