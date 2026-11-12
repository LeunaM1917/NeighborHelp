'use strict';
const {validWindow} = require('./domain');
const {coversSchedule} = require('./scheduling');

// Direct requests use the listing's hourly rate or a fixed amount that the
// provider sees before accepting. Client-supplied hourly rates are never used.
module.exports = function directBooking(data, service, profile, fail) {
  if(data.requestVersion===2) {
    const estimate=listingEstimate(service,fail),start=Number(data.scheduledDate),end=start+estimate.durationHours*3600000;
    if(!validWindow(start,end)||start>Date.now()+180*86400000)fail('invalid-argument','Choose an available future start within 180 days.');
    if(String(data.notes||'').trim().length<10||String(data.notes||'').trim().length>3000)fail('invalid-argument','Describe the job in 10–3000 characters.');
    if(!coversSchedule(profile,{scheduledDate:start,scheduledEndDate:end}))fail('failed-precondition','The preferred schedule is outside working hours or time off.');
    return {start,end,...estimate,requestVersion:2,termsStatus:'Awaiting provider estimate',
      estimatedDurationHours:estimate.durationHours,estimatedTotalFee:estimate.totalFee};
  }
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

// Listing estimates are provider-authored. The customer's preferred start does
// not determine the duration, rate or final price of a version-2 request.
function listingEstimate(service,fail) {
  const raw=String(service.estimatedDuration||'').toLowerCase();
  const range=/(\d+(?:\.\d+)?)\s*(?:-|–|to)\s*(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?)/.exec(raw);
  const hours=/(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b/.exec(raw),minutes=/(\d+(?:\.\d+)?)\s*(?:minutes?|mins?)\b/.exec(raw);
  const parsed=range ? Number(range[2])*(range[3].startsWith('m')?1/60:1) : hours||minutes ? Number(hours?.[1]||0)+Number(minutes?.[1]||0)/60 : Number.parseFloat(raw)||1;
  const durationHours=Math.min(24,Math.max(.25,Math.ceil(parsed*4)/4));
  const pricingType=String(service.priceType).toLowerCase()==='hourly'?'hourly':'fixed';
  const rateCents=Math.round((Number(service.estimatedPrice)+Number.EPSILON)*100),rate=rateCents/100;
  const totalFee=(pricingType==='hourly'?Math.round(rateCents*durationHours):rateCents)/100;
  if(!Number.isFinite(rate)||rate<=0||!Number.isFinite(totalFee)||totalFee<=0||totalFee>1000000)fail('failed-precondition','The provider must publish a valid service estimate before requests can be sent.');
  return {pricingType,durationHours,totalFee,...(pricingType==='hourly'?{hourlyRate:rate}:{})};
}
module.exports.listingEstimate=listingEstimate;
