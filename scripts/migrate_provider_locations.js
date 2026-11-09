'use strict';
// Uses operator ADC. Plan by default; --apply deliberately scrubs current fields.
const requireFunctions=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {initializeApp,deleteApp}=requireFunctions('firebase-admin/app');
const {getFirestore}=requireFunctions('firebase-admin/firestore');
const migrate=require('../functions/provider_location_migration');
async function main(){
  const args=process.argv.slice(2),index=args.indexOf('--project'),projectId=args[index+1];
  if(index<0 || !projectId || !/^[a-z][a-z0-9-]{4,61}$/.test(projectId))throw Error('Provide --project PROJECT_ID. Add --apply only after reviewing the plan.');
  if(process.env.FIRESTORE_EMULATOR_HOST && !projectId.startsWith('demo-'))throw Error('Use a demo- project with the emulator.');
  const app=initializeApp({projectId}),db=getFirestore(app),apply=args.includes('--apply');
  const total={projectId,emulator:!!process.env.FIRESTORE_EMULATOR_HOST,apply,scanned:0,selected:0,needsSelection:0,scrubbed:0};
  try{
    let cursor='',more;
    do{const r=await migrate(db,{cursor,apply});for(const key of ['scanned','selected','needsSelection','scrubbed'])total[key]+=r[key];cursor=r.cursor;more=r.hasMore;}while(more);
    process.stdout.write(JSON.stringify(total,null,2)+'\n');
  }finally{await deleteApp(app);}
}
main().catch(e=>{process.stderr.write(e.message+'\n');process.exitCode=1;});
