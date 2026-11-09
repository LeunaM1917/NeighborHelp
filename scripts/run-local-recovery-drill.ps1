[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskDirectory=Join-Path $taskRoot ('artifacts/recovery-'+[guid]::NewGuid().ToString('N'))
$snapshot=Join-Path $taskDirectory 'snapshot'
$cli=Join-Path $taskRoot 'functions/node_modules/firebase-tools/lib/bin/firebase.js'
$config=Join-Path $taskRoot 'firebase.recovery.test.json'
$script=Join-Path $PSScriptRoot 'recovery-drill.cjs'
New-Item -ItemType Directory -Path $taskDirectory -Force | Out-Null
$env:CI='true'
$env:GCLOUD_PROJECT='demo-neighborhelp-recovery'
# CLI starts and stops its own demo emulator. No cloud endpoint or production database is used.
$seed='node "'+$script+'" write "'+$taskDirectory+'"'
& node $cli emulators:exec --config $config --project demo-neighborhelp-recovery --only firestore "--export-on-exit=$snapshot" $seed
if($LASTEXITCODE -ne 0){throw 'Recovery fixture export failed.'}
$verify='node "'+$script+'" verify "'+$taskDirectory+'"'
& node $cli emulators:exec --config $config --project demo-neighborhelp-recovery --only firestore "--import=$snapshot" $verify
if($LASTEXITCODE -ne 0){throw 'Recovery fixture import or verification failed.'}
Write-Output (Join-Path $taskDirectory 'result.json')
