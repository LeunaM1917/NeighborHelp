'use strict';
async function assertAdminToken(context,fail,db,tx) {
  if(context.auth?.token?.email_verified!==true)fail('permission-denied','Verify your administrator email, then sign in again.');
  const policy=db ? (await (tx?tx.get(db.doc('securityPolicy/admin')):db.doc('securityPolicy/admin').get())).data() : null;
  const factor=context.auth?.token?.firebase?.sign_in_second_factor;
  if(policy?.requireMfa===true&&(typeof factor!=='string'||!factor))fail('permission-denied','Two-step administrator sign-in is required.');
}
module.exports={assertAdminToken};
