'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {validateOffer,makeAgreement}=require('../agreements');
const {offer}=require('./marketplace_fixtures');
const fail=(code,message)=>{throw Error(message);};
test('fixed fees stay fixed across multiple days and daily fees multiply decimal pesos exactly',()=>{
  assert.equal(validateOffer({...offer(),numberOfDays:3,proposedRate:199.95},fail).totalFee,199.95);
  assert.equal(validateOffer({...offer(),pricingType:'daily',numberOfDays:3,proposedRate:199.95},fail).totalFee,599.85);
  assert.throws(()=>validateOffer({...offer(),proposedRate:100.001},fail),/decimal/);
});
test('the fingerprint changes when a party, scope, price or schedule changes',()=>{
  const data={id:'b',offer:validateOffer(offer(),fail),customer:{id:'c',fullName:'Customer'},provider:{id:'p',fullName:'Provider'},service:'House Cleaning',address:'Panabo City',start:1900000000000,end:1900003600000};
  const a=makeAgreement(data);assert.equal(makeAgreement(data).hash,a.hash);
  for(const patch of [{offer:{...data.offer,scope:'Different scope'}},{offer:{...data.offer,totalFee:1000}},{start:data.start+3600000},{provider:{id:'p2',fullName:'Other provider'}}]) assert.notEqual(makeAgreement({...data,...patch}).hash,a.hash);
});
