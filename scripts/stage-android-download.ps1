param([string]$ApkPath = "build/app/outputs/flutter-apk/app-release.apk")
$ErrorActionPreference = "Stop"
$taskRoot = Split-Path -Parent $PSScriptRoot
$apk = Get-Item -LiteralPath (Join-Path $taskRoot $ApkPath)
$sdkRoot = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA "Android/Sdk" }
$tools = Get-ChildItem -LiteralPath (Join-Path $sdkRoot "build-tools") -Directory |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (!$tools) { throw "Android build tools are required to verify the APK." }
if (!$env:JAVA_HOME) {
    $env:JAVA_HOME = Join-Path $env:ProgramFiles "Android/Android Studio/jbr"
}
$metadata = & (Join-Path $tools.FullName "aapt2.exe") dump badging $apk.FullName
if ($LASTEXITCODE -ne 0) { throw "Could not inspect the APK." }
$packageLine = $metadata | Where-Object { $_ -match "^package:" } | Select-Object -First 1
$package = [regex]::Match($packageLine, "name='([^']+)'").Groups[1].Value
$versionName = [regex]::Match($packageLine, "versionName='([^']+)'").Groups[1].Value
$buildNumber = [regex]::Match($packageLine, "versionCode='([^']+)'").Groups[1].Value
if ($package -ne "com.neighborhelp.app" -or $versionName -notmatch '^[0-9.]+$' -or !$buildNumber) {
    throw "Expected a versioned NeighborHelp APK."
}
$certificate = & (Join-Path $tools.FullName "apksigner.bat") verify --print-certs $apk.FullName
if ($LASTEXITCODE -ne 0 -or ($certificate -join "`n") -match 'CN=Android Debug') {
    throw "Only a verified APK signed with the release key can be staged."
}
$destination = Join-Path $taskRoot "web/downloads"
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$filename = "neighborhelp-$versionName-$buildNumber.apk"
$target = Join-Path $destination $filename
Copy-Item -LiteralPath $apk.FullName -Destination $target -Force
$digest = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$target.sha256" -Value "$digest  $filename" -Encoding ascii
[ordered]@{
    package = $package
    version = $versionName
    build = [int]$buildNumber
    filename = $filename
    bytes = $apk.Length
    sha256 = $digest
    url = "https://neighborhelp.web.app/downloads/$filename"
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination "latest-android.json") -Encoding utf8
Write-Output "Verified release APK staged: $filename"
Write-Output "SHA-256: $digest"
Write-Output "Build the web release, then deploy Firebase Hosting to publish the download."
