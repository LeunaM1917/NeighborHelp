'use strict';
const {windowFor, active} = require('./domain');
const DAY = 86400000, MINUTE = 60000, PH = 8 * 3600000;
const names = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
const defaults = Object.fromEntries(names.map(name => [name, {enabled:name !== 'Sunday',
  start:name === 'Wednesday' ? '8:30 AM' : name === 'Saturday' ? '9:00 AM' : '8:00 AM',
  end:name === 'Wednesday' ? '5:30 PM' : name === 'Saturday' ? '1:00 PM' : '5:00 PM'}]));
function minutes(label) {
  const m = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/i.exec(String(label).trim());
  if (!m || +m[1] < 1 || +m[1] > 12 || +m[2] > 59) return null;
  return (+m[1] % 12 + (m[3].toUpperCase() === 'PM' ? 12 : 0)) * 60 + +m[2];
}
function periods(b) {
  const bounds = windowFor(b);
  if (!(b.numberOfDays && b.hoursPerDay)) return [bounds];
  return Array.from({length:b.numberOfDays}, (_,i) => ({start:bounds.start + i*DAY,end:bounds.start + i*DAY + b.hoursPerDay*3600000}));
}
function coversSchedule(profile, booking) {
  return periods(booking).every(({start,end}) => {
    if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return false;
    const local = new Date(start + PH);
    const midnight = Date.UTC(local.getUTCFullYear(),local.getUTCMonth(),local.getUTCDate()) - PH;
    // The previous day's overnight shift may cover an early morning request.
    const shifts = [-1,0,1].flatMap(offset => {
      const base = midnight + offset*DAY;
      const name = names[new Date(base+PH).getUTCDay()];
      const raw = profile.weeklyAvailability?.[name];
      const s = typeof raw === 'boolean' ? {...defaults[name],enabled:raw} : {...defaults[name],...raw};
      const from = minutes(s.start), to = minutes(s.end);
      if (!s.enabled || from == null || to == null || from === to) return [];
      return [{start:base+from*MINUTE,end:base+to*MINUTE+(to<from ? DAY : 0)}];
    }).sort((a,b)=>a.start-b.start);
    let cursor = start;
    for (const shift of shifts) { if (shift.start <= cursor && shift.end > cursor) cursor = shift.end; }
    return cursor >= end;
  });
}
// Fifteen minutes between jobs, counted once (not twice at either edge).
const TRAVEL_BUFFER_MS = 15 * MINUTE;
function conflicts(a,b) {
  return periods(a).some(x=>periods(b).some(y=>x.start < y.end+TRAVEL_BUFFER_MS && y.start < x.end+TRAVEL_BUFFER_MS));
}
function availability(profile, request, bookings) {
  if (!coversSchedule(profile,request)) return {available:false,reason:'Outside the provider\'s working hours on one or more requested days.'};
  if (bookings.some(b=>active(b) && conflicts(request,b))) return {available:false,reason:'An accepted job or travel buffer overlaps this schedule.'};
  return {available:true,reason:'Available for all requested work periods.'};
}
function requestedWindow(data,fail) {
  const start=Number(data.scheduledDate), days=Number(data.numberOfDays), hours=Number(data.hoursPerDay);
  if (!Number.isFinite(start) || start<=Date.now() || start>Date.now()+180*DAY || !Number.isInteger(days) || days<1 || days>30 || !Number.isFinite(hours) || hours<0.5 || hours>8 || !Number.isInteger(hours*2)) fail('invalid-argument','Choose a future schedule within 180 days, 1–30 days and 0.5–8 hours per day.');
  return {scheduledDate:start,scheduledEndDate:start+(days-1)*DAY+hours*3600000,numberOfDays:days,hoursPerDay:hours};
}
module.exports={coversSchedule,conflicts,availability,periods,requestedWindow,minutes,defaults,TRAVEL_BUFFER_MS};
