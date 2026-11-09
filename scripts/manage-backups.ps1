[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[a-z][a-z0-9-]+$')][string]$ProjectId,
  [ValidateSet('Inspect', 'ScheduleDaily', 'RestoreDrill', 'LocalDrill')][string]$Action = 'Inspect',
  [string]$BackupName,
  [ValidatePattern('^neighborhelp-recovery-[a-z0-9-]+$')][string]$DestinationDatabase = 'neighborhelp-recovery-drill',
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
if ($Action -eq 'LocalDrill') {
  if ($ProjectId -ne 'demo-neighborhelp-recovery') { throw 'The local recovery drill is restricted to demo-neighborhelp-recovery.' }
  & (Join-Path $PSScriptRoot 'run-local-recovery-drill.ps1')
  return
}
$gcloudCommand = Get-Command gcloud.cmd -ErrorAction SilentlyContinue
if (-not $gcloudCommand) { $gcloudCommand = Get-Command gcloud -ErrorAction SilentlyContinue }
if ($Action -eq 'Inspect' -and -not $gcloudCommand) {
  $cli = Join-Path (Split-Path -Parent $PSScriptRoot) 'functions/node_modules/firebase-tools/lib/bin/firebase.js'
  if (-not (Test-Path -LiteralPath $cli)) { throw 'Install the Functions Node dependencies or Google Cloud SDK before inspection.' }
  foreach ($command in @('firestore:backups:schedules:list', 'firestore:backups:list')) {
    $arguments = @($cli, $command, '--project', $ProjectId, '--json')
    if ($command -eq 'firestore:backups:schedules:list') { $arguments += @('--database', '(default)') }
    Write-Output ('node ' + ($arguments -join ' '))
    if ($Apply -and $PSCmdlet.ShouldProcess($ProjectId, $command)) {
      & node @arguments
      if ($LASTEXITCODE -ne 0) { throw 'Read-only backup inspection failed.' }
    }
  }
  return
}
if ($Action -eq 'Inspect') {
  $commands = @(
    @('firestore', 'backups', 'schedules', 'list', '--database=(default)', "--project=$ProjectId", '--format=json'),
    @('firestore', 'backups', 'list', "--project=$ProjectId", '--format=json')
  )
} elseif ($Action -eq 'ScheduleDaily') {
  $commands = @(,@('firestore', 'backups', 'schedules', 'create', '--database=(default)', '--retention=14d', '--recurrence=daily', "--project=$ProjectId"))
} else {
  if ($BackupName -notmatch '^projects/[a-z0-9-]+/locations/[a-z0-9-]+/backups/[a-zA-Z0-9-]+$') {
    throw 'Supply the full source backup resource name returned by Inspect.'
  }
  if (-not $BackupName.StartsWith("projects/$ProjectId/", [StringComparison]::Ordinal)) {
    throw 'The backup must belong to the explicitly selected project.'
  }
  $commands = @(,@('firestore', 'databases', 'restore', "--source-backup=$BackupName", "--destination-database=$DestinationDatabase", "--project=$ProjectId"))
}

foreach ($arguments in $commands) {
  Write-Output ("gcloud " + ($arguments -join ' '))
  # Default is a reviewable command plan. No cloud operation is performed.
  if ($Apply -and $PSCmdlet.ShouldProcess($ProjectId, ($arguments -join ' '))) {
    if (-not $gcloudCommand) { throw 'Install Google Cloud SDK before creating a cloud schedule or restoring a cloud backup.' }
    & $gcloudCommand.Source @arguments
    if ($LASTEXITCODE -ne 0) { throw "Backup operation failed with exit code $LASTEXITCODE" }
  }
}
