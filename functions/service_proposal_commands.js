'use strict';
const crypto=require('node:crypto');
const {FieldValue}=require('firebase-admin/firestore');
const policy=require('./marketplace_policy');
const account=require('./account_setup');
module.exports=({db,functions})=>async(data,context)=>{
  const fail=(code,message)=>{throw new functions.https.HttpsError(code,message);};
  const uid=context.auth?.uid,action=String(data?.action||'');
  if(!uid)fail('unauthenticated','Sign in required.');
  if(!['submit','approve','reject','restoreDraft'].includes(action))fail('invalid-argument','Choose a valid proposal action.');
  const stamp=()=>FieldValue.serverTimestamp();
  const draft=(p,id)=>({providerId:p.providerId,serviceTitle:p.serviceTitle,category:p.category,description:p.description,
    serviceProposalId:id,requiredQualification:p.qualificationName,estimatedPrice:0,priceType:'negotiable',estimatedDuration:'1–2 hours',
    availability:{},serviceImages:[],requiresCertification:true,isActive:false,approvalStatus:'Draft',rejectionReason:'',createdAt:stamp(),updatedAt:stamp()});
  return db.runTransaction(async tx=>{
    const actor=(await tx.get(db.doc('users/'+uid))).data();
    if(actor?.accountStatus!=='Active')fail('permission-denied','An active account is required.');
    const notify=(userId,title,message,id,extra={})=>tx.create(db.collection('notifications').doc(),{
      userId,title,message,notificationType:'Service Proposal',relatedProposalId:id,isRead:false,createdAt:stamp(),...extra});
    let id,ref,p,profile,owner,cert;
    if(action==='submit'){
      if(actor.role!=='Provider')fail('permission-denied','Only providers may propose services.');
      const serviceTitle=String(data.serviceTitle||'').trim(),category=String(data.category||'').trim(),description=String(data.description||'').trim();
      if(serviceTitle.length<3||serviceTitle.length>100||/[\r\n\x00-\x1f]/.test(serviceTitle)||description.length<20||description.length>500
        ||![...Object.keys(policy.catalog),'Other TESDA Services'].includes(category))fail('invalid-argument','Enter a service name (3–100 characters), description (20–500 characters) and suggested category.');
      if(Object.values(policy.catalog).some(group=>Object.keys(group).some(name=>policy.normalize(name)===policy.normalize(serviceTitle))))fail('failed-precondition','This service is already in the catalog. Choose its existing category and matching certificate.');
      id=crypto.createHash('sha256').update(uid+'|'+policy.normalize(category)+'|'+policy.normalize(serviceTitle)).digest('hex');
      ref=db.doc('serviceProposals/'+id);p=(await tx.get(ref)).data();
      profile=(await tx.get(db.doc('serviceProviders/'+uid))).data();
      if(!account.detailsComplete(actor,profile)||!account.verified(profile))fail('failed-precondition','Complete your profile and identity verification before proposing a service.');
      cert=(profile.certificationHistory||[]).find(c=>c.id===String(data.certificationEntryId||''));
      if(!cert||!policy.eligibleTesdaCertificate(cert,new Set(profile.approvedCertificationIds||[])))fail('failed-precondition','Choose a current TESDA certificate authenticated and approved by the administrator.');
      if(p&&p.status!=='Rejected'){
        if(p.status==='Pending'&&p.description===description&&p.certificationEntryId===cert.id)return {proposalId:id,duplicate:true};
        fail('already-exists',p.status==='Approved'?'This proposal is approved. Edit its draft listing from Services.':'This proposal is already awaiting review.');
      }
      const admins=await tx.get(db.collection('users').where('role','==','Administrator'));
      const quota=await require('./rate_limits').quota(tx,db,uid,'service_proposals',[[3600000,3],[86400000,10]],fail);
      quota();
      tx.set(ref,{providerId:uid,providerName:actor.fullName||'Provider',serviceTitle,category,description,
        certificationEntryId:cert.id,qualificationName:cert.name,status:'Pending',reviewNotes:'',
        createdAt:p?.createdAt||stamp(),updatedAt:stamp()});
      for(const admin of admins.docs)if(admin.data().accountStatus==='Active')notify(admin.id,'New service proposal',`${actor.fullName||'A provider'} proposed ${serviceTitle}. Review the service scope and TESDA qualification in Services.`,id,{adminTab:6,inAppOnly:true});
    }else if(action==='restoreDraft'){
      id=String(data.proposalId||'');if(!/^[a-f0-9]{64}$/.test(id))fail('invalid-argument','Invalid proposal reference.');
      ref=db.doc('serviceProposals/'+id);p=(await tx.get(ref)).data();
      if(actor.role!=='Provider'||p?.providerId!==uid||p.status!=='Approved')fail('permission-denied','Only the provider may restore their approved proposal draft.');
      profile=(await tx.get(db.doc('serviceProviders/'+uid))).data();
      const serviceId='proposed_'+id,serviceRef=db.doc('services/'+serviceId),existing=await tx.get(serviceRef);
      if(!account.detailsComplete(actor,profile)||!account.verified(profile)
        ||profile.approvedServiceProposals?.[id]?.serviceId!==serviceId
        ||!require('./domain').hasMatchingCertificate(profile,p.category,p.serviceTitle))fail('failed-precondition','A current approved matching certificate and verified profile are required.');
      if(existing.exists)return {serviceId,duplicate:true};
      tx.create(serviceRef,draft(p,id));
    }else{
      if(actor.role!=='Administrator')fail('permission-denied','Administrator access required.');
      await require('./admin_security').assertAdminToken(context,fail,db,tx);
      id=String(data.proposalId||'');if(!/^[a-f0-9]{64}$/.test(id))fail('invalid-argument','Invalid proposal reference.');
      ref=db.doc('serviceProposals/'+id);p=(await tx.get(ref)).data();
      if(!p)fail('not-found','Service proposal not found.');
      if(p.status!=='Pending')fail('failed-precondition','This proposal was already reviewed. Refresh the list.');
      const notes=String(data.notes||'').trim();
      if(notes.length<10||notes.length>1000)fail('invalid-argument','Explain the review decision in 10–1000 characters.');
      const profileRef=db.doc('serviceProviders/'+p.providerId);
      profile=(await tx.get(profileRef)).data();owner=(await tx.get(db.doc('users/'+p.providerId))).data();
      const serviceId='proposed_'+id,serviceRef=db.doc('services/'+serviceId);
      const existing=await tx.get(serviceRef);
      cert=(profile?.certificationHistory||[]).find(c=>c.id===p.certificationEntryId);
      if(action==='approve'){
        if(data.scopeConfirmed!==true)fail('failed-precondition','Confirm that the work matches this TESDA qualification and does not require an unsupported professional licence.');
        if(owner?.role!=='Provider'||owner.accountStatus!=='Active'||!account.detailsComplete(owner,profile)||!account.verified(profile)
          ||!cert||policy.normalize(cert.name)!==policy.normalize(p.qualificationName)||!policy.eligibleTesdaCertificate(cert,new Set(profile.approvedCertificationIds||[])))fail('failed-precondition','The provider needs a complete, verified profile and the same current approved TESDA certificate.');
        const grants={...(profile.approvedServiceProposals||{})};
        if(Object.keys(grants).length>=50&&!grants[id])fail('resource-exhausted','This provider has reached the approved service proposal limit.');
        if(existing.exists)fail('already-exists','A draft already exists for this proposal.');
        grants[id]={status:'Approved',serviceTitle:p.serviceTitle,category:p.category,certificationEntryId:cert.id,
          qualificationName:cert.name,serviceId,reviewedBy:uid,reviewedAt:stamp()};
        tx.update(profileRef,{approvedServiceProposals:grants,updatedAt:stamp()});
        tx.create(serviceRef,draft(p,id));
      }
      tx.update(ref,{status:action==='approve'?'Approved':'Rejected',reviewNotes:notes,reviewedBy:uid,reviewedAt:stamp(),updatedAt:stamp(),
        ...(action==='approve'?{draftServiceId:serviceId}:{})});
      notify(p.providerId,action==='approve'?'Service proposal approved':'Service proposal rejected',action==='approve'
        ?`${p.serviceTitle} was approved. A private draft is ready in Services. Add pricing and submit the listing for review.`
        :`${p.serviceTitle}: ${notes}`,id);
    }
    tx.create(db.collection('auditLogs').doc(),{actorId:uid,actorRole:actor.role,action:'serviceProposal.'+action,
      collection:'serviceProposals',referenceId:id,createdAt:stamp(),
      ...(['approve','reject'].includes(action)?{notes:String(data.notes).trim(),scopeConfirmed:action==='approve'}:{})});
    return {proposalId:id,status:action==='submit'?'Pending':action==='reject'?'Rejected':'Approved'};
  });
};
