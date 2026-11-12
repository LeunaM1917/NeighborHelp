'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const directBooking = require('../direct_booking');
const {credentials, futureWorkStart} = require('./marketplace_fixtures');
const fail = (code, message) => { throw new Error(`${code}: ${message}`); };
const request = (extra = {}) => ({scheduledDate: futureWorkStart(),
  scheduledEndDate: futureWorkStart() + 1.5 * 3600000, ...extra});
const service = {estimatedPrice: 125.5, priceType: 'Hourly'};

test('direct hourly bookings use the server listing rate and actual duration', () => {
  const result = directBooking(request({totalFee: 1, hourlyRate: 1}), service, credentials(), fail);
  assert.equal(result.totalFee, 188.25);
  assert.equal(result.hourlyRate, 125.5);
  assert.equal(result.durationHours, 1.5);
  assert.equal(result.agreement, undefined);
});
test('a fixed request preserves the amount shown to the accepting provider', () => {
  const result = directBooking(request({pricingType: 'fixed', totalFee: 675.25}), service, credentials(), fail);
  assert.equal(result.totalFee, 675.25);
  assert.equal(result.hourlyRate, undefined);
});
test('invalid amounts, windows, pricing and provider time off are rejected', () => {
  for (const totalFee of [-1, 0, 0.001, Infinity, NaN, 'bad', 1000001]) {
    assert.throws(() => directBooking(request({pricingType: 'fixed', totalFee}), service, credentials(), fail), /price/);
  }
  assert.throws(() => directBooking(request({pricingType: 'daily'}), service, credentials(), fail), /pricing/);
  for (const extra of [{scheduledDate: 1}, {scheduledEndDate: futureWorkStart()},
    {scheduledEndDate: futureWorkStart() + 25 * 3600000}]) {
    assert.throws(() => directBooking(request(extra), service, credentials(), fail), /future booking/);
  }
  const data = request();
  assert.throws(() => directBooking(data, service,
    {...credentials(), timeOff: [{start: data.scheduledDate, end: data.scheduledEndDate}]}, fail), /time off/);
});
