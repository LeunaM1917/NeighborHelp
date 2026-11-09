'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {coversSchedule,conflicts,minutes,requestedWindow}=require('../scheduling');
const {credentials,futureWorkStart}=require('./marketplace_fixtures');
const at=s=>Date.parse(`${s}+08:00`);
const request=(s,days=1,hours=1)=>({scheduledDate:at(s),numberOfDays:days,hoursPerDay:hours});
test('positive booking fixtures stay within working hours at every runner hour and across date rollovers',()=>{
  const profile=credentials();
  for(const date of ['2026-11-09','2026-12-31','2028-02-28','2028-02-29']) {
    for(let hour=0;hour<24;hour++)for(const minute of [0,31,59]) {
      const now=Date.parse(`${date}T${String(hour).padStart(2,'0')}:${String(minute).padStart(2,'0')}:00Z`),start=futureWorkStart(now);
      assert.ok(start>now);assert.ok(start-now<2*86400000);
      const local=new Date(start+8*3600000);
      assert.equal(local.getUTCHours(),9);assert.equal(local.getUTCMinutes(),0);
      assert.equal(coversSchedule(profile,{scheduledDate:start,numberOfDays:3,hoursPerDay:6}),true,`runner time ${new Date(now).toISOString()}`);
    }
  }
});
test('the failed CI start crosses midnight; the corrected fixture preserves schedule enforcement',()=>{
  const now=Date.parse('2026-11-09T14:31:37Z'),profile=credentials();
  const booking={scheduledDate:now+86400000,numberOfDays:3,hoursPerDay:6};
  assert.equal(coversSchedule(profile,booking),false);
  assert.equal(coversSchedule(profile,{...booking,scheduledDate:futureWorkStart(now)}),true);
});
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
