'use strict';
const RETAKE_CODES = new Set(['UNRECOGNIZED_DOCUMENT','UNRECOGNIZED_BACK_DOCUMENT','INVALID_BACK_DOCUMENT',
  'IMAGE_TOO_BLURRY','IMAGE_TOO_SMALL','LOW_TEXT_CONFIDENCE','DOCUMENT_FACE_NOT_FOUND','SELFIE_FACE_NOT_FOUND',
  'SELFIE_MULTIPLE_FACES','INVALID_CAMERA_PERSPECTIVE','DOCUMENT_FACE_LANDMARK_ERR','SELFIE_FACE_LANDMARK_ERR',
  'MISSING_NAME','MISSING_DOCUMENT_NUMBER','PHYSICAL_DOCUMENT_MISSING']);
const REJECT_CODES = new Set(['FAKE_ID','FACE_MISMATCH','FACE_LIVENESS_ERR','RECAPTURED_FACE',
  'DOCUMENT_EXPIRED','COUNTRY_NOT_ACCEPTED','TYPE_NOT_ACCEPTED']);
// Version 2 applies readability requirements prospectively, when a link is created.
const QUALITY_POLICY_VERSION = 2;
const mandatoryDecisions = () => Object.fromEntries([...RETAKE_CODES,...REJECT_CODES]
  .map(code=>[code,{enabled:true,review:-1,reject:0,weight:1}]));
function values(data,key) {
  const field=data?.[key];
  return (Array.isArray(field)?field:[field]).map(item=>typeof item==='string'?item:item?.value)
    .filter(value=>typeof value==='string'&&value.trim()).map(value=>value.trim());
}
function assessIdentity(transaction={}, {enforceReadability=true}={}) {
  const codes=new Set((Array.isArray(transaction.warning)?transaction.warning:[])
    .map(w=>w?.code).filter(code=>typeof code==='string'&&/^[A-Z][A-Z0-9_]{0,79}$/.test(code)));
  const data=transaction.data;
  if(!values(data,'documentType').length)codes.add('UNRECOGNIZED_DOCUMENT');
  if(!values(data,'fullName').length && !(values(data,'firstName').length&&values(data,'lastName').length))codes.add('MISSING_NAME');
  if(!values(data,'documentNumber').length)codes.add('MISSING_DOCUMENT_NUMBER');
  const retakeRequired=enforceReadability && [...codes].some(code=>RETAKE_CODES.has(code));
  const blocked=retakeRequired || [...codes].some(code=>REJECT_CODES.has(code));
  return {codes:[...codes].sort(),retakeRequired,blocked,policyVersion:QUALITY_POLICY_VERSION};
}
module.exports={RETAKE_CODES,REJECT_CODES,QUALITY_POLICY_VERSION,mandatoryDecisions,assessIdentity};
