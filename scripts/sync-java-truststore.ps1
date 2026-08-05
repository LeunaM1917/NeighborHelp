# Sync Windows root certificates into a project-local Java truststore for Gradle.
# Fixes: PKIX path building failed / SSL handshake exception on flutter build apk
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$trustDir = Join-Path $root "android\java-truststore"
New-Item -ItemType Directory -Force -Path $trustDir | Out-Null

$jbrHome = "C:\Program Files\Android\Android Studio\jbr"
$keytool = Join-Path $jbrHome "bin\keytool.exe"
$sourceCacerts = Join-Path $jbrHome "lib\security\cacerts"
$destCacerts = Join-Path $trustDir "cacerts"
$storePass = "changeit"

if (-not (Test-Path $keytool)) {
    throw "Android Studio JBR keytool not found at $keytool"
}

if (-not (Test-Path $destCacerts)) {
    Copy-Item -Path $sourceCacerts -Destination $destCacerts -Force
    Write-Host "Copied base cacerts to $destCacerts"
}

$imported = 0
$skipped = 0

# Avast (and similar AV) HTTPS scanning uses a local root not in the default JRE cacerts.
$avastRoots = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {
    $_.Subject -match 'Avast|AVG|Kaspersky|Bitdefender|ESET|Web/Mail Shield'
}
foreach ($cert in $avastRoots) {
    $thumb = $cert.Thumbprint
    if (-not $thumb) { continue }
    $alias = "av-root-$thumb"
    $tempCert = Join-Path $env:TEMP "nh-cert-$thumb.cer"
    try {
        Export-Certificate -Cert $cert -FilePath $tempCert -Force | Out-Null
        & $keytool -importcert -noprompt -trustcacerts `
            -alias $alias `
            -file $tempCert `
            -keystore $destCacerts `
            -storepass $storePass 2>$null
        if ($LASTEXITCODE -eq 0) { $imported++ } else { $skipped++ }
    } catch {
        $skipped++
    } finally {
        Remove-Item -Path $tempCert -Force -ErrorAction SilentlyContinue
    }
}

$roots = Get-ChildItem -Path Cert:\LocalMachine\Root
foreach ($cert in $roots) {
    $thumb = $cert.Thumbprint
    if (-not $thumb) { continue }
    $alias = "win-root-$thumb"
    $tempCert = Join-Path $env:TEMP "nh-cert-$thumb.cer"
    try {
        Export-Certificate -Cert $cert -FilePath $tempCert -Force | Out-Null
        & $keytool -importcert -noprompt -trustcacerts `
            -alias $alias `
            -file $tempCert `
            -keystore $destCacerts `
            -storepass $storePass 2>$null
        if ($LASTEXITCODE -eq 0) {
            $imported++
        } else {
            $skipped++
        }
    } catch {
        $skipped++
    } finally {
        Remove-Item -Path $tempCert -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Truststore ready: $destCacerts (imported $imported Windows root certs, skipped $skipped)"
Write-Host "Gradle is configured to use this truststore via android/gradle.properties"
