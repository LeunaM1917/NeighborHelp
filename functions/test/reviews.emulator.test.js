const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');
const {before,after,beforeEach,test} = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const admin = require('firebase-admin');
const {initializeTestEnvironment} = require('@firebase/rules-unit-testing');
let env, db, app, api, server, prediction;
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Demo emulator required.');
  process.env.GCLOUD_PROJECT = 'demo-neighborhelp';
  prediction = {sentiment:'positive',confidence:0.95,model_version:'test-fixture',probabilities:{positive:0.95,neutral:0.03,negative:0.02}};
  server = http.createServer((req,res) => { res.setHeader('Content-Type','application/json'); res.end(JSON.stringify(prediction)); });
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  process.env.SENTIMENT_API_URL = `http://127.0.0.1:${server.address().port}`;
  env = await initializeTestEnvironment({projectId:'demo-neighborhelp'});
  api = require('../index'); app = require('firebase-admin/app').getApp(); db = getFirestore(app);
});
after(async () => {await require('firebase-admin/app').deleteApp(app);await env?.cleanup();await new Promise(resolve=>server?.close(resolve));});
beforeEach(async () => {
  await env.clearFirestore();
  await db.doc('users/customer').set({role:'Customer',accountStatus:'Active'});
  await db.doc('users/provider').set({role:'Provider',accountStatus:'Active'});
  await db.doc('serviceProviders/provider').set({averageRating:0,reviewCount:0});
  await db.doc('bookings/booking').set({customerId:'customer',providerId:'provider',serviceId:'service',status:'Milestone Complete',completedAt:Timestamp.now()});
  prediction.sentiment='positive';
  delete prediction.model_family;
});
const auth = uid => ({auth:{uid,token:{email_verified:true}}});
test('a sentiment disagreement is advisory and the reviewer can post their own stars and words', async () => {
  prediction.sentiment='negative';
  const data={bookingId:'booking',reviewerRole:'customer',rating:5,comment:'The work was terrible and very disappointing.'};
  const result=await api.submitMilestoneReview.run(data,auth('customer'));
  assert.equal(result.requiresConfirmation,true);assert.match(result.warning,/post it as written/);
  assert.equal((await db.collection('reviews').get()).size,0);
  await api.submitMilestoneReview.run({...data,confirmSentimentMismatch:true},auth('customer'));
  const review=(await db.collection('reviews').get()).docs[0].data();assert.equal(review.rating,5);assert.equal(review.comment,data.comment);assert.equal(review.sentimentMismatchAcknowledged,true);
});
test('concurrent feedback submissions store one review; rating aggregation remains stable on retries', async () => {
  const data={bookingId:'booking',reviewerRole:'customer',rating:5,comment:'The provider did excellent work today.'};
  const results=await Promise.allSettled([api.submitMilestoneReview.run(data,auth('customer')),api.submitMilestoneReview.run(data,auth('customer'))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const review=(await db.collection('reviews').get()).docs[0];
  await api.onReviewCreated.run(review);
  const first=(await db.doc('serviceProviders/provider').get()).data();
  await api.onReviewCreated.run(await review.ref.get());
  const second=(await db.doc('serviceProviders/provider').get()).data();
  assert.equal(first.averageRating,second.averageRating); assert.equal(second.reviewCount,1);
  assert.equal(review.data().sentiment.source,'lstm');
});
test('unfinished bookings and suspended accounts cannot submit feedback', async () => {
  await db.doc('bookings/booking').update({status:'Accepted',completedAt:FieldValue.delete()});
  await assert.rejects(api.submitMilestoneReview.run({bookingId:'booking',reviewerRole:'customer',rating:5},auth('customer')),/unlock/);
  await db.doc('bookings/booking').update({status:'Awaiting Confirmation'});
  await assert.rejects(api.submitMilestoneReview.run({bookingId:'booking',reviewerRole:'customer',rating:5},auth('customer')),/unlock/);
  await db.doc('users/customer').update({accountStatus:'Suspended'});
  await assert.rejects(api.submitMilestoneReview.run({bookingId:'booking',reviewerRole:'customer',rating:5},auth('customer')),/active account/);
});
test('linear sentiment candidates retain their model family and advisory warning',async()=>{
  prediction.model_family='tfidf_logistic';
  await api.submitMilestoneReview.run({bookingId:'booking',reviewerRole:'customer',rating:5,comment:'The provider did excellent work today.'},auth('customer'));
  assert.equal((await db.collection('reviews').get()).docs[0].data().sentiment.source,'tfidf_logistic');
  await db.doc('bookings/second').set({customerId:'customer',providerId:'provider',serviceId:'service',status:'Milestone Complete',completedAt:Timestamp.now()});
  prediction.sentiment='negative';
  const warning=await api.submitMilestoneReview.run({bookingId:'second',reviewerRole:'customer',rating:5,comment:'The work was terrible and very disappointing.'},auth('customer'));assert.equal(warning.requiresConfirmation,true);
});

test('incoming messages update conversation activity and create one alert on trigger retries', async () => {
  const ref=db.doc('messages/message');
  await ref.set({bookingId:'booking',senderId:'customer',receiverId:'provider',messageText:'Can we confirm the appointment?'});
  await api.onMessageCreated.run(await ref.get());
  await api.onMessageCreated.run(await ref.get());
  assert.equal((await db.collection('notifications').get()).size,1);
  assert.ok((await db.doc('bookings/booking').get()).data().lastMessageAt);
});
