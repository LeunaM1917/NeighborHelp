'use strict';
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
// Read first; apply only after the caller has finished all transaction reads.
async function quota(tx,db,uid,kind,limits,fail,now=Date.now()) {
  const entries=[];
  for (const [milliseconds,limit] of limits) {
    const bucket=Math.floor(now/milliseconds), ref=db.doc(`rateLimits/${uid}_${kind}_${milliseconds}_${bucket}`);
    const count=(await tx.get(ref)).data()?.count || 0;
    if(count>=limit) fail('resource-exhausted',`Too many ${kind} requests. Retry in ${Math.ceil(((bucket+1)*milliseconds-now)/1000)} seconds.`);
    entries.push({ref,count,expiresAt:Timestamp.fromMillis((bucket+2)*milliseconds)});
  }
  return ()=>{ for(const e of entries) tx.set(e.ref,{count:e.count+1,expiresAt:e.expiresAt,updatedAt:FieldValue.serverTimestamp()}); };
}
module.exports={quota};
