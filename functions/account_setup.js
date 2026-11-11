'use strict';
const ids = new Set(require('./panabo_barangays.json').barangays.map(b => b.id));
const phoneValid = value => /^\+?[0-9]{7,15}$/.test(String(value || '').replace(/[\s()-]/g, ''));
function detailsComplete(user, profile) {
  if (String(user?.fullName || '').trim().length < 2 || !phoneValid(user?.contactNumber)) return false;
  if (user?.role === 'Provider') return ids.has(profile?.baseBarangayId)
    && Array.isArray(profile?.serviceBarangayIds) && profile.serviceBarangayIds.length > 0
    && profile.serviceBarangayIds.every(id => ids.has(id));
  return user?.role === 'Customer' && String(user.address || '').trim().length >= 5;
}
const verified = user => user?.isVerified === true || user?.verificationStatus === 'Approved';
module.exports = {phoneValid, detailsComplete, verified};
