const { test } = require('node:test');
const assert = require('node:assert/strict');
const { complete, overlaps, validWindow, hasMatchingCertificate, csvCell, distanceKm } = require('../domain');
test('both historical and milestone completion states count as complete', () => {
  assert.ok(complete({status: 'Completed'})); assert.ok(complete({status: 'Milestone Complete'}));
  assert.equal(complete({status: 'In Progress'}), false);
});
test('adjacent appointments are allowed but overlapping appointments are rejected', () => {
  assert.equal(overlaps({scheduledDate: 100, scheduledEndDate: 200}, {scheduledDate: 200, scheduledEndDate: 300}), false);
  assert.equal(overlaps({scheduledDate: 100, scheduledEndDate: 201}, {scheduledDate: 200, scheduledEndDate: 300}), true);
  assert.equal(validWindow(500, 600, 100), true); assert.equal(validWindow(50, 600, 100), false);
});
test('an unrelated, expired, or undocumented credential does not qualify a technical service', () => {
  const profile = require('./marketplace_fixtures').credentials('Carpentry NC II');
  assert.equal(hasMatchingCertificate(profile, 'Home Repair', 'Plumbing'), false);
  assert.equal(hasMatchingCertificate(profile, 'Home Repair', 'Carpentry'), true);
  profile.certificationHistory[0].expirationDate = '2020-01-01';
  assert.equal(hasMatchingCertificate(profile, 'Home Repair', 'Carpentry'), false);
});
test('exports escape embedded quotes, commas and spreadsheet formulas', () => {
  assert.equal(csvCell('hello,"world"'), '"hello,""world"""');
  assert.equal(csvCell('=IMPORTXML("x")'), '"\'=IMPORTXML(""x"")"');
});
test('coverage distance uses kilometers', () => {
  assert.equal(distanceKm({latitude: 7,longitude:125}, {latitude:7,longitude:125}), 0);
  assert.ok(distanceKm({latitude:7,longitude:125}, {latitude:8,longitude:125}) > 110);
});
test('multi-day agreements reserve the agreed work hours rather than overnight gaps',()=>{
  const days={agreement:{},scheduledDate:1000000000,numberOfDays:3,hoursPerDay:8};
  assert.equal(overlaps(days,{scheduledDate:1000000000+25*3600000,scheduledEndDate:1000000000+26*3600000}),true);
  assert.equal(overlaps(days,{scheduledDate:1000000000+12*3600000,scheduledEndDate:1000000000+13*3600000}),false);
});
