'use strict';
const catalog = require('./service_policy.json');
const qualifications = {
  carpentry: ['Carpentry NC II', 'Carpentry NC III'],
  domestic: ['Domestic Work NC II'],
  computer: ['Computer Systems Servicing NC II'],
  rac: ['RAC Servicing (DomRAC) NC II', 'RAC Servicing (Domestic) NC II'],
};
const normalize = value => String(value || '').trim().replace(/\s+/g, ' ').toLowerCase();
function serviceFamily(category, title) {
  const group = Object.keys(catalog).find(k => normalize(k) === normalize(category));
  const name = Object.keys(catalog[group] || {}).find(k => normalize(k) === normalize(title));
  return name ? catalog[group][name] : null;
}
function credentialFamily(name) {
  return Object.keys(qualifications).find(k => qualifications[k].some(n => normalize(n) === normalize(name))) || null;
}
function eligibleCertificate(c, approved, family, now = new Date()) {
  const expiry = /^\d{4}-\d{2}-\d{2}$/.test(c.expirationDate || '') ? new Date(`${c.expirationDate}T23:59:59.999+08:00`) : null;
  return approved.has(c.id) && c.status === 'Approved' && c.verificationSource === 'TESDA Registry of Certified Workers'
    && Boolean(c.reviewedBy) && Boolean(c.reviewedAt) && Boolean(c.certificationId) && Boolean(c.url)
    && normalize(c.provider) === 'tesda' && credentialFamily(c.name) === family
    && expiry !== null && Number.isFinite(expiry.getTime()) && expiry >= now;
}
module.exports = {catalog, qualifications, normalize, serviceFamily, credentialFamily, eligibleCertificate};
