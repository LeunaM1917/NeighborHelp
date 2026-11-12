'use strict';
const {validWindow} = require('./domain');
const {coversSchedule} = require('./scheduling');

// Direct requests use the listing's hourly rate or a fixed amount that the
// provider sees before accepting. Client-supplied hourly rates are never used.
module.exports = function directBooking(data, service, profile, fail) {
  const start = Number(data.scheduledDate), end = Number(data.scheduledEndDate);
  if (!validWindow(start, end) || start > Date.now() + 180 * 86400000) {
    fail('invalid-argument', 'Choose a future booking within 180 days lasting up to 24 hours.');
  }
  const pricingType = data.pricingType ||
    (String(service.priceType).toLowerCase().includes('hour') ? 'hourly' : 'fixed');
  if (!['hourly', 'fixed'].includes(pricingType)) fail('invalid-argument', 'Choose hourly or fixed pricing.');
  const durationHours = (end - start) / 3600000;
  const rate = Number(service.estimatedPrice);
  const fee = pricingType === 'hourly' ? rate * durationHours : Number(data.totalFee ?? rate);
  if (!Number.isFinite(rate) || rate <= 0 || !Number.isFinite(fee) || fee <= 0 || fee > 1000000) {
    fail('invalid-argument', 'Enter a valid booking price.');
  }
  const totalFee = Math.round((fee + Number.EPSILON) * 100) / 100;
  if (totalFee <= 0) fail('invalid-argument', 'Enter a valid booking price of at least one centavo.');
  if (!coversSchedule(profile, {scheduledDate: start, scheduledEndDate: end})) {
    fail('failed-precondition', 'The requested booking is outside the provider\'s working hours or time off.');
  }
  return {start, end, pricingType, durationHours, totalFee,
    ...(pricingType === 'hourly' ? {hourlyRate: rate} : {})};
};
