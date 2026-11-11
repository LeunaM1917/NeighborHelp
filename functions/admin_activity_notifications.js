'use strict';
module.exports=({collection,before,after,created})=>{
  const notices=[];
  const add=(key,title,message,tab)=>notices.push({key,data:{title,message,adminTab:tab,inAppOnly:true,notificationType:'Admin Activity'}});
  const name=after.fullName||after.businessName||'A user';
  if(collection==='users'&&created&&['Customer','Provider'].includes(after.role))
    add('registered','New '+after.role.toLowerCase()+' registered',`${name} registered a ${after.role.toLowerCase()} account.`,after.role==='Provider'?2:1);
  if(collection==='serviceProviders'){
    const previous=new Map((before.certificationHistory||[]).map(c=>[c.id,c]));
    for(const c of after.certificationHistory||[]){
      if(!c.id||String(c.status||'Pending')!=='Pending')continue;
      const prior=previous.get(c.id),fields=['name','url','certificationId','issueDate','expirationDate'];
      if(!prior||String(prior.status||'Pending')!=='Pending'||fields.some(f=>prior[f]!==c[f]))
        add('certificate:'+c.id,'Certificate awaiting review',`${c.name||'A TESDA certificate'} was submitted for authentication. Open Certificates to review the holder and qualification.`,5);
    }
  }
  if(['users','serviceProviders'].includes(collection)&&after.diditStatus!==before.diditStatus
    &&['Approved','In Review','Declined'].includes(after.diditStatus))
    add('identity','Identity verification update',`${name} has a new identity result: ${after.diditStatus}. Open Verification for details.`,4);
  if(collection==='services'&&after.approvalStatus==='Pending'&&before.approvalStatus!=='Pending')
    add('listing','Service listing awaiting review',`${after.serviceTitle||'A service listing'} was submitted for review.`,6);
  if(collection==='bookingUserReports'&&created)
    add('report','New user report',`A user submitted a report: ${after.reason||'Open User Reports to review the case.'}`,3);
  return notices;
};
