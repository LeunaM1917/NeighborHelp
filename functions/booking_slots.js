'use strict';
const {availability}=require('./scheduling');
const {active,windowFor,hasMatchingCertificate}=require('./domain');
const {listingEstimate}=require('./direct_booking');
const DAY=86400000,PH=8*3600000;

function slotsForDays(profile,jobs,{startDay,days,durationHours,now=Date.now()}) {
  const daysWithSlots=[];
  jobs=jobs.filter(b=>active(b)&&windowFor(b).end>=startDay-15*60000&&windowFor(b).start<=startDay+days*DAY+15*60000);
  for(let day=0;day<days;day++) {
    const midnight=startDay+day*DAY,starts=[];
    for(let minute=0;minute<1440;minute+=15) {
      const start=midnight+minute*60000,end=start+durationHours*3600000;
      if(start<=now||start>now+180*DAY)continue;
      if(availability(profile,{scheduledDate:start,scheduledEndDate:end},jobs).available)starts.push(start);
    }
    if(starts.length)daysWithSlots.push({day:midnight,starts});
  }
  return daysWithSlots;
}
async function command({db,data,uid,user,fail}) {
  const providerId=data.providerIds[0],serviceId=String(data.serviceId||'');
  if(data.providerIds.length!==1||!/^[\w-]{1,160}$/.test(serviceId))fail('invalid-argument','Choose one provider and service.');
  const now=Date.now(),today=Math.floor((now+PH)/DAY)*DAY-PH,startDay=Number(data.startDay),days=Number(data.days||90);
  if(!Number.isFinite(startDay)||(startDay+PH)%DAY!==0||startDay<today||startDay>today+180*DAY||!Number.isInteger(days)||days<1||days>90)fail('invalid-argument','Choose 1–90 calendar days within the next 180 days.');
  const [profileSnap,providerSnap,serviceSnap,jobsSnap]=await Promise.all([
    db.doc(`serviceProviders/${providerId}`).get(),db.doc(`users/${providerId}`).get(),db.doc(`services/${serviceId}`).get(),
    db.collection('bookings').where('providerId','==',providerId).get()]);
  const profile=profileSnap.data(),service=serviceSnap.data();
  if(!profile?.isVerified||providerSnap.data()?.accountStatus!=='Active'||!service||service.providerId!==providerId||!service.isActive||service.approvalStatus!=='Approved')fail('failed-precondition','The provider or service is unavailable.');
  if(!hasMatchingCertificate(profile,service.category,service.serviceTitle))fail('failed-precondition','The provider no longer has a current qualification for this service.');
  const estimate=listingEstimate(service,fail);
  let durationHours=estimate.durationHours;
  if(data.durationHours!=null) {
    if(uid!==providerId||user.role!=='Provider')fail('permission-denied','Only the provider can choose the estimated duration.');
    durationHours=Number(data.durationHours);
    if(!Number.isFinite(durationHours)||durationHours<.25||durationHours>24||!Number.isInteger(durationHours*4))fail('invalid-argument','Choose a duration in 15-minute increments, up to 24 hours.');
  }
  const exclude=String(data.excludeBookingId||'');
  if(exclude) {
    if(!/^[\w-]{1,160}$/.test(exclude))fail('invalid-argument','Invalid booking reference.');
    const booking=jobsSnap.docs.find(d=>d.id===exclude)?.data();
    if(!booking||![booking.customerId,booking.providerId].includes(uid))fail('permission-denied','Only a booking participant may exclude its current reservation.');
    // Customer reschedules keep the provider-confirmed duration.
    if(uid!==providerId)durationHours=Number(booking.durationHours)||estimate.durationHours;
  }
  const jobs=jobsSnap.docs.filter(d=>d.id!==exclude).map(d=>d.data());
  return {timezone:'Asia/Manila',checkedAt:now,travelBufferMinutes:15,estimatedDurationHours:durationHours,
    estimatedTotalFee:estimate.totalFee,pricingType:estimate.pricingType,hourlyRate:estimate.hourlyRate||null,
    days:slotsForDays(profile,jobs,{startDay,days,durationHours,now})};
}
module.exports={command,slotsForDays};
