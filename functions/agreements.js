'use strict';
const crypto = require('node:crypto');
const VERSION = 'NH-SERVICE-2026-11-09-v2';
const TERMS = `1. Scope and qualifications. The provider will perform only the work described in this agreement, within their verified competence. No professional design, sign-off, regulated electrical work, master plumbing or other work requiring an unsupported licence is authorised. Required permits, supervision and licences must be obtained before any work that requires them.
2. Price and payment. Amounts are in Philippine pesos. A fixed amount covers only the agreed scope. A daily amount covers the agreed number of working days and hours per day. No automatic charges for overtime, partial days, extra days, materials or additional work are authorised. Any change requires a written amendment or new offer accepted by both parties before the additional work starts. Every accepted version remains on record. Payments are made directly between the parties using the stated payment arrangement; NeighborHelp does not hold funds, provide escrow or guarantee payment.
3. Responsibilities and safety. The customer provides lawful access, accurate job information and disclosure of known hazards. The provider supplies the agreed tools and protective equipment, follows applicable safety requirements, and may stop unsafe work. Each party remains responsible for obligations and harm attributable to their acts or omissions under applicable law. This agreement does not waive mandatory rights or exclude liability that cannot lawfully be excluded.
4. Completion and concerns. The provider reports completion against the stated deliverables and completion criteria. Fixed-price work may be reported finished early when the deliverables are ready. The customer must inspect and explicitly confirm completion or request specific corrections. Please respond within 72 hours; there is no automatic approval or waiver if no response arrives. Unresolved concerns may be reported for administrative review. Daily-priced work follows the agreed work periods unless both parties accept an amendment. A completion status does not itself prove payment or waive remedies.
5. Cancellation and unfinished work. Either party may request cancellation with a recorded reason. The parties must document work completed, any payment made, materials supplied, and any agreed balance or refund. There is no automatic forfeiture or cancellation penalty. Disputed amounts remain subject to agreement or lawful resolution.
6. Disputes. First record the concern and supporting evidence in the conversation. Platform reporting supports administrative review and account action; it is not a court decision or an escrow service. Neither party loses access to barangay processes, regulators, courts or other remedies available under Philippine law.
7. Consent and records. Both parties must be at least 18 and legally able to enter this agreement, review its complete terms, and voluntarily accept the same version. The accepted text, identities, timestamps and document fingerprint are retained. Changes cannot silently overwrite an accepted agreement. A message exchange is an inquiry within the app and does not reserve a job; applicable law determines the legal effect of communications.
8. Applicable law. Philippine law applies. Statutory employment, consumer, privacy, safety and professional regulation obligations apply where relevant regardless of labels or payment type. This template does not determine employment status. Personal data is used and disclosed only as necessary for service coordination, recordkeeping and lawful dispute handling.`;
function validateOffer(data, fail) {
  const type = data.pricingType;
  const amount = Number(data.proposedRate), days = Number(data.numberOfDays);
  const hours = Number(data.hoursPerDay);
  if (!['fixed', 'daily'].includes(type)) fail('invalid-argument', 'Choose fixed or daily pricing. Hourly offers are no longer supported.');
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1000000 || Math.abs(amount * 100 - Math.round(amount * 100)) > 0.000001) fail('invalid-argument', 'Enter a positive peso amount with at most two decimal places.');
  if (!Number.isInteger(days) || days < 1 || days > 30 || !Number.isFinite(hours) || hours < 0.5 || hours > 8 || !Number.isInteger(hours * 2)) fail('invalid-argument', 'Choose 1–30 days and a working day of 0.5–8 hours in half-hour steps.');
  const details = {};
  for (const key of ['scope', 'deliverables', 'exclusions', 'materials', 'paymentTerms', 'completionCriteria', 'responsibilities']) {
    const value = String(data[key] || '').trim();
    if (value.length < 5 || value.length > 3000) fail('invalid-argument', `Describe ${key} in 5–3000 characters. Use "None agreed" where appropriate.`);
    details[key] = value;
  }
  if (data.acceptAgreement !== true || data.templateVersion !== VERSION) fail('failed-precondition', 'Review and accept the current service agreement before sending.');
  return {pricingType: type, proposedRate: amount, numberOfDays: days, hoursPerDay: hours,
    totalFee: Math.round(amount * (type === 'daily' ? days : 1) * 100) / 100, ...details};
}
function makeAgreement({id, offer, customer, provider, service, address, start, end}) {
  const text = `NEIGHBORHELP SERVICE AGREEMENT\nAgreement ${id}\nTemplate ${VERSION}\nCustomer: ${customer.fullName} (${customer.id})\nProvider: ${provider.fullName} (${provider.id})\nService: ${service}\nLocation: ${address}\nStart (Asia/Manila): ${new Date(start + 8 * 3600000).toISOString().replace('T', ' ').slice(0,16)}\nLast work period ends (Asia/Manila): ${new Date(end + 8 * 3600000).toISOString().replace('T', ' ').slice(0,16)}\nPricing: ${offer.pricingType}; PHP ${offer.proposedRate.toFixed(2)}${offer.pricingType === 'daily' ? ' per day' : ' total'}\nWorking days: ${offer.numberOfDays}; hours per day: ${offer.hoursPerDay}\nTotal labour fee: PHP ${offer.totalFee.toFixed(2)}\n\n${Object.entries(offer).filter(([k]) => ['scope','deliverables','exclusions','materials','paymentTerms','completionCriteria','responsibilities'].includes(k)).map(([k,v]) => `${k}: ${v}`).join('\n\n')}\n\n${TERMS}`;
  return {version: VERSION, text, hash: crypto.createHash('sha256').update(text).digest('hex')};
}
module.exports = {VERSION, TERMS, validateOffer, makeAgreement};
