'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {verifySignature, resultFor, returnUrl} = require('../id_analyzer');
const {assessIdentity,mandatoryDecisions,RETAKE_CODES}=require('../identity_quality');

test('identity quality fails closed on missing OCR and ignored readability warnings',()=>{
  const valid={data:{documentType:[{value:'D'}],fullName:[{value:'SYNTHETIC TEST PERSON'}],documentNumber:[{value:'TEST-NOT-REAL'}]},warning:[]};
  assert.equal(assessIdentity(valid).blocked,false);
  assert.equal(assessIdentity({}).retakeRequired,true);
  for(const code of RETAKE_CODES) {
    assert.equal(assessIdentity({...valid,warning:[{code,decision:'accept'}]}).retakeRequired,true);
    assert.equal(mandatoryDecisions()[code].reject,0);
  }
  assert.equal(assessIdentity({...valid,warning:[{code:'IMAGE_EDITED',decision:'review'}]}).blocked,false);
  assert.equal(assessIdentity({...valid,warning:[{code:'FAKE_ID',decision:'review'}]}).blocked,true);
  assert.equal(assessIdentity({...valid,warning:[{code:'UNRECOGNIZED_BACK_DOCUMENT'}]},{enforceReadability:false}).blocked,false);
  assert.equal(assessIdentity({...valid,warning:[{code:'FAKE_ID'}]},{enforceReadability:false}).blocked,true);
  assert.equal(resultFor('review',{verificationManualDecision:'Approved'}).isVerified,true);
  assert.equal(resultFor('reject',{verificationManualDecision:'Approved'}).isVerified,false);
});

test('ID Analyzer signatures authenticate exact bytes and expire after five minutes', () => {
  const now = 1800000000000, secret = 'test-secret', timestamp = String(now / 1000);
  const rawBody = Buffer.from('{ "event": "docupass_conclusive", "note": "test" }');
  const signature = 'v1=' + crypto.createHmac('sha256', secret).update(timestamp + '.').update(rawBody).digest('hex');
  const req = {rawBody, get: name => name === 'X-IDA-Timestamp' ? timestamp : signature};
  assert.equal(verifySignature(req, secret, now), true);
  assert.equal(verifySignature(req, 'wrong', now), false);
  assert.equal(verifySignature(req, secret, now + 301000), false);
  assert.equal(verifySignature({...req, rawBody: Buffer.from(JSON.stringify(JSON.parse(rawBody)))}, secret, now), false);
  assert.equal(verifySignature({...req, rawBody: undefined}, secret, now), false);
  assert.equal(verifySignature({...req, get: name => name === 'X-IDA-Timestamp' ? 'NaN' : signature}, secret, now), false);
});

test('ID Analyzer maps decisions without bypassing a manual rejection', () => {
  assert.deepEqual(resultFor('accept'), {verificationDecision:'accept',diditStatus:'Approved',isVerified:true,verificationStatus:'Approved'});
  assert.equal(resultFor('review').verificationStatus, 'Pending');
  assert.equal(resultFor('reject').isVerified, false);
  assert.equal(resultFor('accept', {verificationManualDecision:'Rejected'}).verificationStatus, 'Rejected');
  assert.equal(resultFor('unknown'), null);
});

test('verification redirects allow only this Firebase project and local development', () => {
  assert.equal(returnUrl('https://neighborhelp-63771.web.app/?nh_role=customer', 'neighborhelp-63771'), 'https://neighborhelp-63771.web.app/?nh_role=customer');
  assert.equal(returnUrl('http://localhost:59896/', 'neighborhelp-63771'), 'http://localhost:59896/');
  for (const host of ['neighborhelp.web.app', 'neighborhelp.firebaseapp.com']) {
    assert.equal(returnUrl(`https://${host}/?nh_role=customer`, 'neighborhelp-63771'), `https://${host}/?nh_role=customer`);
    assert.throws(() => returnUrl(`https://${host}/`, 'unrelated-project'), {code:'invalid-argument'});
  }
  for (const url of ['https://evil.example/', 'javascript:alert(1)', 'https://neighborhelp-63771.web.app.evil.example/',
    'https://neighborhelp.web.app.evil.example/', 'https://unrelated.web.app/',
    'https://attacker@neighborhelp-63771.web.app/', 'http://neighborhelp-63771.web.app/']) {
    assert.throws(() => returnUrl(url, 'neighborhelp-63771'), {code:'invalid-argument'});
  }
});
