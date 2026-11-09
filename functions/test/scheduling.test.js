'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {coversSchedule,conflicts,minutes,requestedWindow}=require('../scheduling');
const at=s=>Date.parse(`${s}+08:00`);
const request=(s,days=1,hours=1)=>({scheduledDate:at(s),numberOfDays:days,hoursPerDay:hours});
test('a request must fit every daily period, not just its start or today',()=>{
  const profile={};
  assert.equal(coversSchedule(profile,request('2026-11-09T16:00:00',1,1)),true);
  assert.equal(coversSchedule(profile,request('2026-11-09T16:00:00',1,2)),false);
  assert.equal(coversSchedule(profile,request('2026-11-14T09:00:00',2,1)),false);
  assert.equal(coversSchedule(profile,request('2026-11-09T09:00:00',3,6)),true);
});
test('overnight availability belongs to the day that started the shift',()=>{
  const profile={weeklyAvailability:{Monday:{enabled:true,start:'10:00 PM',end:'2:00 AM'},Tuesday:{enabled:false}}};
  assert.equal(coversSchedule(profile,request('2026-11-10T01:00:00',1,1)),true);
  assert.equal(coversSchedule(profile,request('2026-11-09T01:00:00',1,1)),false);
  assert.equal(coversSchedule(profile,request('2026-11-10T01:00:00',1,2)),false);
});
test('multi-day jobs leave overnight gaps free and need one travel buffer between jobs',()=>{
  const b=request('2026-11-09T09:00:00',2,2);
  assert.equal(conflicts(b,request('2026-11-10T10:30:00')),true);
  assert.equal(conflicts(b,request('2026-11-09T18:00:00')),false);
  assert.equal(conflicts(b,request('2026-11-09T11:14:00')),true);
  assert.equal(conflicts(b,request('2026-11-09T11:15:00')),false);
  assert.equal(conflicts(request('2026-11-09T07:45:00'),b),false);
});
test('malformed clock labels and abusive request sizes fail closed',()=>{
  for(const value of ['0:00 AM','13:00 PM','8:60 AM','junk'])assert.equal(minutes(value),null);
  const fail=(code,message)=>{throw new Error(message);};
  for(const patch of [{numberOfDays:1000000},{hoursPerDay:NaN},{scheduledDate:0}])assert.throws(()=>requestedWindow({scheduledDate:Date.now()+86400000,numberOfDays:1,hoursPerDay:1,...patch},fail));
});
