# Reads secrets.local.json and writes gitignored Android / web secret artifacts.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$secretsPath = Join-Path $root "secrets.local.json"

if (-not (Test-Path $secretsPath)) {
  Write-Error "Missing secrets.local.json. Copy secrets.example.json and fill in your keys."
}

$secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
$mapsWebKey = ($secrets.GOOGLE_MAPS_WEB_API_KEY).Trim()
$mapsAndroidKey = ($secrets.GOOGLE_MAPS_ANDROID_API_KEY).Trim()
$androidFirebaseKey = ($secrets.FIREBASE_ANDROID_API_KEY).Trim()

if ([string]::IsNullOrWhiteSpace($mapsWebKey)) {
  Write-Error "GOOGLE_MAPS_WEB_API_KEY is empty in secrets.local.json"
}
if ([string]::IsNullOrWhiteSpace($mapsAndroidKey)) {
  Write-Error "GOOGLE_MAPS_ANDROID_API_KEY is empty in secrets.local.json"
}
if ([string]::IsNullOrWhiteSpace($androidFirebaseKey)) {
  Write-Error "FIREBASE_ANDROID_API_KEY is empty in secrets.local.json"
}

$androidSecretsPath = Join-Path $root "android\secrets.properties"
Set-Content -Path $androidSecretsPath -Value "GOOGLE_MAPS_API_KEY=$mapsAndroidKey" -NoNewline

$gsExample = Join-Path $root "android\app\google-services.json.example"
$gsOut = Join-Path $root "android\app\google-services.json"
if (-not (Test-Path $gsExample)) {
  Write-Error "Missing android/app/google-services.json.example"
}
$gsJson = Get-Content $gsExample -Raw
$gsJson = $gsJson.Replace("__FIREBASE_ANDROID_API_KEY__", $androidFirebaseKey)
Set-Content -Path $gsOut -Value $gsJson -NoNewline

$escapedKey = $mapsWebKey -replace '\\', '\\\\' -replace "'", "\'"
$nl = [Environment]::NewLine
$mapsLoader = "(function () {$nl" +
  "  var key = '$escapedKey';$nl" +
  "  if (!key) return;$nl" +
  "  var s = document.createElement('script');$nl" +
  "  s.async = true;$nl" +
  "  s.defer = true;$nl" +
  "  s.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(key);$nl" +
  "  document.head.appendChild(s);$nl" +
  "})();"
$mapsLoaderPath = Join-Path $root "web\maps_loader.js"
Set-Content -Path $mapsLoaderPath -Value $mapsLoader -NoNewline

Write-Host "Synced secrets to android/secrets.properties, android/app/google-services.json, web/maps_loader.js"
