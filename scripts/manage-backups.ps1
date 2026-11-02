[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[a-z][a-z0-9-]+$')][string]$ProjectId,
  [ValidateSet('Inspect', 'ScheduleDaily', 'RestoreDrill')][string]$Action = 'Inspect',
  [string]$BackupName,
  [ValidatePattern('^neighborhelp-recovery-[a-z0-9-]+$')][string]$DestinationDatabase = 'neighborhelp-recovery-drill',
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
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
    $gcloudCommand = Get-Command gcloud.cmd -ErrorAction Stop
    & $gcloudCommand.Source @arguments
    if ($LASTEXITCODE -ne 0) { throw "Backup operation failed with exit code $LASTEXITCODE" }
  }
}
