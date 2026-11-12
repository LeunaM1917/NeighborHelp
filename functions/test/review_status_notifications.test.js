'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const notices = require('../review_status_notifications');
const adminNotices = require('../admin_activity_notifications');

test('admin notification destinations retain exact record IDs without private identity payloads', () => {
  const base = {before:{},created:true};
  const cases = [
    {collection:'users',id:'customer',after:{role:'Customer'},field:'relatedUserId',value:'customer'},
    {collection:'serviceProviders',id:'provider',after:{certificationHistory:[{id:'cert',status:'Pending'}]},field:'relatedCertificationId',value:'cert'},
    {collection:'services',id:'service',after:{approvalStatus:'Pending'},field:'relatedServiceId',value:'service'},
    {collection:'bookingUserReports',id:'report',after:{bookingId:'booking'},field:'relatedReportId',value:'report'},
  ];
  for (const row of cases) {
    const [notice] = adminNotices({...base,...row,after:{...row.after,governmentIdNumber:'private',identitySessionUrl:'private'}});
    assert.equal(notice.data[row.field],row.value);
    assert.equal(notice.data.sourceCollection,row.collection);
    assert.equal(JSON.stringify(notice).includes('private'),false);
  }
  const [identity] = adminNotices({...base,collection:'serviceProviders',id:'provider',after:{diditStatus:'Approved'}});
  assert.equal(identity.data.relatedUserId,'provider');
  assert.equal(identity.data.adminTab,4);
});

for (const collection of ['users', 'serviceProviders']) {
  test(`${collection}: identity submission and all review results identify the status`, () => {
    let before = {verificationStatus: 'Pending', isVerified: false};
    for (const status of ['Pending', 'Approved', 'Rejected', 'Pending']) {
      const after = {...before, verificationStatus: status, isVerified: status === 'Approved', diditSessionId: 'session-1'};
      const result = notices({collection, id: 'profile', ownerId: 'owner', before, after});
      assert.equal(result.length, 1);
      assert.equal(result[0].data.userId, 'owner');
      assert.equal(result[0].data.reviewStatus, status);
      assert.match(result[0].data.message, new RegExp(status, 'i'));
      before = after;
    }
    assert.deepEqual(notices({collection, id: 'profile', before, after: {...before, bio: 'Changed'}}), []);
  });
}

test('default pending account/profile creation is not an identity submission', () => {
  for (const collection of ['users', 'serviceProviders']) {
    assert.deepEqual(notices({collection, id: 'owner', after: {verificationStatus: 'Pending', isVerified: false}}), []);
  }
});

test('a fresh identity session notifies pending once while repeated pending webhooks do not', () => {
  const before = {verificationStatus: 'Pending', diditSessionId: 'first', diditStatus: 'Not Started'};
  const after = {...before, diditSessionId: 'second'};
  assert.equal(notices({collection: 'users', id: 'u', before, after}).length, 1);
  assert.deepEqual(notices({collection: 'users', id: 'u', before: after, after: {...after, diditStatus: 'In Review'}}), []);
});

test('service draft/submission/approval/rejection/resubmission has no draft or stale-reason alerts', () => {
  assert.deepEqual(notices({collection: 'services', id: 's', after: {approvalStatus: 'Draft'}}), []);
  let before = {serviceTitle: 'House cleaning', approvalStatus: 'Draft', rejectionReason: 'Previous rejection'};
  for (const status of ['Pending', 'Approved', 'Rejected', 'Pending']) {
    const after = {...before, approvalStatus: status};
    const [notice] = notices({collection: 'services', id: 's', ownerId: 'provider-user', before, after});
    assert.equal(notice.data.userId, 'provider-user');
    assert.equal(notice.data.relatedServiceId, 's');
    assert.equal(notice.data.reviewStatus, status);
    assert.equal(notice.data.message.includes('Previous rejection'), status === 'Rejected');
    assert.deepEqual(notices({collection: 'services', id: 's', before: after, after: {...after, description: 'Edit'}}), []);
    before = after;
  }
});

test('each certificate independently notifies pending, rejected, resubmitted and approved', () => {
  const cert = {id: 'cert-1', name: 'Carpentry NC II', status: 'Pending'};
  let before = {userId: 'provider-user', certificationHistory: []};
  for (const status of ['Pending', 'Rejected', 'Pending', 'Approved']) {
    const after = {userId: 'provider-user', certificationHistory: [{...cert, status, rejectionReason: 'Details need correction'}]};
    const [notice] = notices({collection: 'serviceProviders', id: 'profile', before, after});
    assert.equal(notice.data.userId, 'provider-user');
    assert.equal(notice.data.relatedCertificationId, cert.id);
    assert.equal(notice.data.relatedProviderId, 'profile');
    assert.equal(notice.data.reviewStatus, status);
    assert.equal(notice.data.message.includes('Details need correction'), status === 'Rejected');
    before = after;
  }
});

test('a pending certificate review notifies its follow-up notes without requiring an approval-list change', () => {
  const cert = {id: 'c', name: 'Domestic Work NC II', status: 'Pending'};
  const before = {certificationHistory: [cert], approvedCertificationIds: []};
  const after = {...before, certificationHistory: [{...cert, reviewedAt: {seconds: 100}, verificationNotes: 'Awaiting TESDA confirmation.'}]};
  const [notice] = notices({collection: 'serviceProviders', id: 'p', before, after});
  assert.equal(notice.data.reviewStatus, 'Pending');
  assert.match(notice.data.message, /Awaiting TESDA confirmation/);
  assert.deepEqual(notices({collection: 'serviceProviders', id: 'p', before: after, after}), []);
});

test('certificate keys remain distinct, with no alerts for reordering, removals or approval metadata alone', () => {
  const certificates = [{id: 'one', status: 'Pending'}, {id: 'two', status: 'Pending'}];
  const before = {certificationHistory: certificates};
  const result = notices({collection: 'serviceProviders', id: 'p', before, after: {
    certificationHistory: certificates.map(c => ({...c, status: 'Rejected'})),
  }});
  assert.equal(new Set(result.map(n => n.key)).size, 2);
  for (const certificationHistory of [[...certificates].reverse(), [certificates[0]], certificates]) {
    assert.deepEqual(notices({collection: 'serviceProviders', id: 'p', before, after: {certificationHistory, approvedCertificationIds: ['one']}}), []);
  }
  assert.deepEqual(notices({collection: 'bookingUserReports', id: 'r', after: {verificationStatus: 'Approved'}}), []);
});
