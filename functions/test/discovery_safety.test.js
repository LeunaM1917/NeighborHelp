'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const area=require('../provider_area'),catalog=require('../panabo_barangays.json').barangays;
const expiry=require('../offer_expiry'),{coversSchedule}=require('../scheduling');
test('forty unique Panabo barangays have valid approximate centers and coverage geometries',()=>{
  assert.equal(catalog.length,40);assert.equal(new Set(catalog.map(b=>b.id)).size,40);
  for(const b of catalog){assert.match(b.id,/^1102315\d{3}$/);assert.ok(b.latitude>7&&b.latitude<8);assert.ok(b.longitude>125&&b.longitude<126);assert.ok(b.polygons.length);}
  assert.ok(catalog.some(b=>b.name==='Santo Niño (Pob.)'));
  assert.equal(area.covers({serviceBarangayIds:catalog.map(b=>b.id)},{latitude:7.3,longitude:125.6}),true);
  assert.equal(area.covers({serviceBarangayIds:catalog.map(b=>b.id)},{latitude:14.6,longitude:121}),false);
  assert.equal(area.covers({serviceBarangayIds:['fake']},{latitude:7.3,longitude:125.6}),false);
});
test('offer deadlines use 72 hours or the start, with exact inclusive expiry and accepted work excluded',()=>{
  const now=100000,start=now+3600000;
  assert.equal(expiry.deadline(start,now),start);assert.equal(expiry.deadline(now+5*86400000,now),now+72*3600000);
  assert.equal(expiry.expired({status:'Pending',offerExpiresAt:start},start-1),false);
  assert.equal(expiry.expired({status:'Pending',offerExpiresAt:start},start),true);
  assert.equal(expiry.expired({status:'Accepted',offerExpiresAt:start},start),false);
});
test('time off checks each daily work period and permits time outside the actual work periods',()=>{
  const start=Date.parse('2026-11-09T01:00:00Z'),booking={scheduledDate:start,numberOfDays:2,hoursPerDay:2,agreement:{}};
  const weeklyAvailability=Object.fromEntries(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].map(day=>[day,{enabled:true,start:'8:00 AM',end:'5:00 PM'}]));
  const p={weeklyAvailability,timeOff:[{start:start+86400000,end:start+86400000+3600000}]};
  assert.equal(coversSchedule(p,booking),false);
  p.timeOff=[{start:start+2*3600000,end:start+86400000}];assert.equal(coversSchedule(p,booking),true);
  p.timeOff=[{start:NaN,end:NaN}];assert.equal(coversSchedule(p,booking),false);
});
