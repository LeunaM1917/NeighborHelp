'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const direct=require('../direct_booking');
const {terms,baseHash}=require('../booking_estimates');
const {slotsForDays}=require('../booking_slots');
const {futureWorkStart,credentials}=require('./marketplace_fixtures');
const fail=(code,message)=>{throw new Error(`${code}: ${message}`);};
test('new customer requests cannot choose duration, pricing mode, hourly rate or final fee',()=>{
  const result=direct({requestVersion:2,scheduledDate:futureWorkStart(),scheduledEndDate:futureWorkStart()+20*3600000,
    durationHours:20,hourlyRate:.01,totalFee:.01,pricingType:'fixed',notes:'Clean the living room and kitchen.'},
    {priceType:'hourly',estimatedPrice:125.5,estimatedDuration:'1 hour 30 minutes'},credentials(),fail);
  assert.equal(result.durationHours,1.5);assert.equal(result.hourlyRate,125.5);assert.equal(result.totalFee,188.25);
  assert.equal(result.pricingType,'hourly');assert.equal(result.termsStatus,'Awaiting provider estimate');
  assert.throws(()=>direct({requestVersion:2,scheduledDate:futureWorkStart(),notes:'short'},
    {priceType:'fixed',estimatedPrice:200},credentials(),fail),/Describe/);
});
test('provider listing duration parsing and money calculations retain quarter hours and cents',()=>{
  for(const [text,hours] of [['45 minutes',.75],['1–2 hours',2],['1 hour 30 min',1.5],['Varies',1]]) {
    assert.equal(direct.listingEstimate({estimatedPrice:125.55,estimatedDuration:text,priceType:'hourly'},fail).durationHours,hours);
  }
  const base={scheduledDate:futureWorkStart(),durationHours:1.75,pricingType:'hourly',proposedRate:125.55};
  assert.equal(terms(base,{},fail).totalFee,219.71);
  assert.equal(terms({...base,proposedRate:1.14,durationHours:.75},{},fail).totalFee,.86);
  assert.equal(terms({...base,pricingType:'fixed',proposedRate:675.25},{},fail).totalFee,675.25);
  assert.throws(()=>terms({...base,durationHours:1.1},{},fail),/15-minute/);
  assert.throws(()=>terms({...base,proposedRate:0},{},fail),/positive rate/);
});
test('available starts exclude closed days, time off, accepted work and exactly one travel buffer',()=>{
  const day=Date.UTC(2027,0,3,16); // Monday midnight in Manila.
  const at=hours=>day+hours*3600000;
  const schedule=Object.fromEntries(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].map(name=>[name,{enabled:name==='Monday',start:'8:00 AM',end:'5:00 PM'}]));
  const profile={weeklyAvailability:schedule,timeOff:[{start:at(8),end:at(10)}]};
  const jobs=[{scheduledDate:at(12),scheduledEndDate:at(14),status:'Accepted'},
    {scheduledDate:at(15),scheduledEndDate:at(16),status:'Pending'}];
  const result=slotsForDays(profile,jobs,{startDay:day,days:2,durationHours:1,now:day-1});
  assert.equal(result.length,1);const starts=result[0].starts;
  assert.equal(starts.includes(at(9)),false);assert.equal(starts.includes(at(10)),true);
  assert.equal(starts.includes(at(10.75)),true);assert.equal(starts.includes(at(11)),false);
  assert.equal(starts.includes(at(14)),false);assert.equal(starts.includes(at(14.25)),true);
  assert.equal(starts.includes(at(15)),true);assert.equal(starts.includes(at(16)),true);assert.equal(starts.includes(at(16.25)),false);
});
test('changing agreed scope, location or price invalidates a pending estimate fingerprint',()=>{
  const base={scheduledDate:futureWorkStart(),durationHours:2,totalFee:300,serviceLocation:'Original address',notes:'Original job description',location:{latitude:7.3,longitude:125.6}};
  for(const patch of [{totalFee:400},{serviceLocation:'New address'},{notes:'Changed job description'},{location:{latitude:7.4,longitude:125.6}}]) {
    assert.notEqual(baseHash(base),baseHash({...base,...patch}));
  }
});
