'use strict';
const {FieldPath,FieldValue,Timestamp}=require('firebase-admin/firestore');
const crypto=require('node:crypto');
const threadId=b=>crypto.createHash('sha256').update(JSON.stringify([b.customerId,b.providerId])).digest('hex');
module.exports=({db,functions})=>{
  const fail=(code,msg)=>{throw new functions.https.HttpsError(code,msg);};
  async function migrate(bookingId,uid) {
    if(!/^[\w-]{1,160}$/.test(bookingId))fail('invalid-argument','Invalid booking.');
    const bookingRef=db.doc(`bookings/${bookingId}`);
    const b=(await bookingRef.get()).data();
    if(!b || ![b.customerId,b.providerId].includes(uid))fail('permission-denied','This booking belongs to another account.');
    const id=threadId(b),ref=db.doc(`inquiries/${id}`),cursorRef=db.doc(`chatMigrations/${bookingId}`);
    return db.runTransaction(async tx=>{
      const actor=(await tx.get(db.doc(`users/${uid}`))).data();
      if(actor?.accountStatus!=='Active')fail('permission-denied','An active account is required.');
      const current=(await tx.get(bookingRef)).data();
      if(!current || current.customerId!==b.customerId || current.providerId!==b.providerId)fail('aborted','Booking changed. Retry.');
      const thread=(await tx.get(ref)).data(),cursor=(await tx.get(cursorRef)).data();
      if(cursor?.complete && current.inquiryId===id)return {inquiryId:id,hasMore:false};
      const customer=(await tx.get(db.doc(`users/${b.customerId}`))).data(),provider=(await tx.get(db.doc(`users/${b.providerId}`))).data();
      const service=(await tx.get(db.doc(`services/${b.serviceId}`))).data();
      let query=db.collection('messages').where('bookingId','==',bookingId).orderBy(FieldPath.documentId()).limit(100);
      if(cursor?.lastId)query=query.startAfter(cursor.lastId);
      const old=await tx.get(query),refs=old.docs.map(d=>ref.collection('messages').doc(`legacy_${d.id}`));
      const existing=refs.length?await tx.getAll(...refs):[];
      const patch=thread?{}:{customerId:b.customerId,providerId:b.providerId,participantIds:[b.customerId,b.providerId],
        customerName:customer?.fullName||'Customer',providerName:provider?.fullName||'Provider',serviceId:b.serviceId,serviceTitle:service?.serviceTitle||'Historical service',
        customerMessageCount:0,providerMessageCount:0,customerUnreadCount:0,providerUnreadCount:0,blockedBy:[],lastMessage:'Conversation history',createdAt:b.createdAt||Timestamp.now(),updatedAt:b.updatedAt||Timestamp.now()};
      let latest=thread?.updatedAt?.toMillis()||patch.updatedAt?.toMillis()||0;
      const counts={customerMessageCount:0,providerMessageCount:0,customerUnreadCount:0,providerUnreadCount:0};
      old.docs.forEach((d,i)=>{
        const m=d.data();
        if(existing[i].exists || ![b.customerId,b.providerId].includes(m.senderId) || m.receiverId!==(m.senderId===b.customerId?b.providerId:b.customerId))return;
        const role=m.senderId===b.customerId?'customer':'provider',other=role==='customer'?'provider':'customer';
        if(m.messageText?.trim())counts[`${role}MessageCount`]++;
        if(!m.isRead)counts[`${other}UnreadCount`]++;
        const sentAt=m.sentAt||b.createdAt||Timestamp.now();
        tx.create(refs[i],{senderId:m.senderId,receiverId:m.receiverId,text:m.messageText||'',mediaUrl:m.mediaUrl||'',sentAt,bookingId,legacyMessageId:d.id});
        if(sentAt.toMillis()>latest){latest=sentAt.toMillis();patch.updatedAt=sentAt;patch.lastMessage=m.messageText||'Photo';}
      });
      for(const [key,value] of Object.entries(counts))if(value)patch[key]=thread?FieldValue.increment(value):value;
      tx.set(ref,patch,{merge:true});
      if(current.inquiryId!==id)tx.update(bookingRef,{inquiryId:id});
      tx.set(cursorRef,{lastId:old.docs.at(-1)?.id||cursor?.lastId||'',complete:old.size<100,updatedAt:FieldValue.serverTimestamp()});
      return {inquiryId:id,hasMore:old.size===100};
    });
  }
  async function sync(data,uid,role) {
    if(!['Customer','Provider'].includes(role))fail('permission-denied','A customer or provider account is required.');
    let q=db.collection('bookings').where(role==='Customer'?'customerId':'providerId','==',uid).orderBy(FieldPath.documentId()).limit(5);
    if(data.cursor){if(!/^[\w-]{1,160}$/.test(data.cursor))fail('invalid-argument','Invalid cursor.');q=q.startAfter(data.cursor);}
    const bookings=await q.get();
    for(const b of bookings.docs){const result=await migrate(b.id,uid);if(result.hasMore)return {hasMore:true,cursor:data.cursor||''};}
    return {hasMore:bookings.size===5,cursor:bookings.docs.at(-1)?.id||''};
  }
  return {migrate,sync};
};
