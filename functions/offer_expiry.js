'use strict';
const {Timestamp,FieldValue}=require('firebase-admin/firestore');
const {millis}=require('./domain');
const RESPONSE_WINDOW=72*3600000;
const expiresAt=b=>b.offerExpiresAt?millis(b.offerExpiresAt):millis(b.scheduledDate);
const expired=(b,now=Date.now())=>b?.status==='Pending'&&Number.isFinite(expiresAt(b))&&expiresAt(b)<=now;
function deadline(start,now=Date.now()){return Math.min(start,now+RESPONSE_WINDOW);}
async function expire(db,id,now=Date.now()){
  return db.runTransaction(async tx=>{
    const ref=db.doc(`bookings/${id}`),b=(await tx.get(ref)).data();
    if(!expired(b,now))return false;
    tx.update(ref,{status:'Expired',expiredAt:FieldValue.serverTimestamp(),updatedBy:'system',updatedByRole:'System',updatedAt:FieldValue.serverTimestamp()});
    for(const userId of [b.customerId,b.providerId])tx.create(db.collection('notifications').doc(),{userId,title:'Contract offer expired',message:'This unanswered offer passed its response deadline. Discuss a new schedule and send a new offer if you still want the work.',relatedBookingId:id,notificationType:'Offer',isRead:false,createdAt:FieldValue.serverTimestamp()});
    tx.create(db.collection('auditLogs').doc(),{actorId:'system',actorRole:'System',action:'booking.expire',collection:'bookings',referenceId:id,createdAt:FieldValue.serverTimestamp()});
    return true;
  });
}
module.exports={deadline,expired,expiresAt,expire,RESPONSE_WINDOW,
  sweep:async db=>{
    const now=Date.now();
    for(const field of ['offerExpiresAt','scheduledDate']){
      const docs=await db.collection('bookings').where('status','==','Pending').where(field,'<=',Timestamp.fromMillis(now)).limit(200).get();
      for(const row of docs.docs)await expire(db,row.id,now);
    }
    return null;
  },
};
