const {before, after, test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut} = require('firebase/auth');
const {getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, Timestamp, terminate} = require('firebase/firestore');
let env;
const apps = [];
before(async () => {
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'Registration tests require the Auth emulator');
  env = await initializeTestEnvironment({projectId: 'demo-neighborhelp', firestore: {
    rules: fs.readFileSync(path.join(__dirname, '../../firebase/firestore.rules'), 'utf8'),
  }});
});
after(async () => {
  for (const {app, db} of apps) { await terminate(db); await deleteApp(app); }
  await env?.cleanup();
});
function client(name) {
  const app = initializeApp({apiKey: 'demo-api-key', projectId: 'demo-neighborhelp'}, name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, {disableWarnings: true});
  const db = getFirestore(app);
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  connectFirestoreEmulator(db, host, Number(port));
  apps.push({app, db});
  return {auth, db};
}
for (const role of ['Customer', 'Provider']) {
  test(`real ${role} email/password signup can save and reload its full profile under production rules`, async () => {
    const {auth, db} = client(`signup-${role}`);
    const email = `registration-${role.toLowerCase()}-${Date.now()}@example.test`;
    const password = 'Emulator-password-123';
    const {user} = await createUserWithEmailAndPassword(auth, email, password);
    const userDoc = doc(db, 'users', user.uid);
    const providerDoc = doc(db, 'serviceProviders', user.uid);
    assert.equal((await getDoc(userDoc)).exists(), false);
    assert.equal((await getDoc(providerDoc)).exists(), false);
    const now = Timestamp.now();
    const profile = {
      fullName: 'Registration Test', email, contactNumber: null, country: 'Philippines', marketingOptIn: true,
      role, profilePhotoUrl: null, address: null, location: null, accountStatus: 'Active',
      createdAt: now, updatedAt: now, lastActive: now,
    };
    await setDoc(userDoc, profile);
    if (role === 'Provider') await setDoc(providerDoc, {
      userId: user.uid, bio: '', serviceArea: '', location: null, serviceRadiusKm: 5,
      averageRating: 0, completedBookings: 0, acceptedBookings: 0, isVerified: false,
      verificationStatus: 'Pending', diditStatus: '', diditSessionId: '', verificationProvider: '',
      governmentIdTypeCode: '', governmentIdTypeLabel: '', createdAt: now, updatedAt: now,
    });
    // This is the protected overwrite that competing automatic recovery used to attempt.
    await assertFails(setDoc(userDoc, {...profile, country: null, marketingOptIn: false, createdAt: Timestamp.fromMillis(now.toMillis() + 1)}));
    await signOut(auth);
    await signInWithEmailAndPassword(auth, email, password);
    assert.equal((await getDoc(userDoc)).data().role, role);
    if (role === 'Provider') {
      assert.equal((await getDoc(providerDoc)).data().isVerified, false);
      await assertFails(setDoc(providerDoc, {isVerified: true}, {merge: true}));
    }
    await assertFails(setDoc(userDoc, {role: 'Administrator'}, {merge: true}));
  });
}
