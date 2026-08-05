# Downloads Android Gradle deps via Windows HTTPS (works when Java/Gradle SSL fails).
# Run before: flutter build apk --release
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$mavenRoot = Join-Path $root "android\local-maven"

function Install-MavenArtifact {
    param(
        [string]$GroupId,
        [string]$ArtifactId,
        [string]$Version
    )

    $groupPath = ($GroupId -replace '\.', '\')
    $destDir = Join-Path $mavenRoot (Join-Path $groupPath (Join-Path $ArtifactId $Version))
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    $baseUrl = "https://repo.maven.apache.org/maven2/$($GroupId -replace '\.', '/')/$ArtifactId/$Version"
    $jarName = "$ArtifactId-$Version.jar"
    $pomName = "$ArtifactId-$Version.pom"

    $jarPath = Join-Path $destDir $jarName
    $pomPath = Join-Path $destDir $pomName

    if (-not (Test-Path $jarPath)) {
        Write-Host "Downloading ${GroupId}:${ArtifactId}:${Version} ..."
        Invoke-WebRequest -Uri "$baseUrl/$jarName" -OutFile $jarPath -UseBasicParsing
    }
    if (-not (Test-Path $pomPath)) {
        Invoke-WebRequest -Uri "$baseUrl/$pomName" -OutFile $pomPath -UseBasicParsing
    }
}

# cloud_functions / Firebase Android SDK transitive deps that often fail on Java SSL.
$artifacts = @(
    @{ GroupId = "com.squareup.okio"; ArtifactId = "okio"; Version = "1.15.0" },
    @{ GroupId = "com.squareup.okio"; ArtifactId = "okio"; Version = "3.4.0" },
    @{ GroupId = "com.squareup.okhttp3"; ArtifactId = "okhttp"; Version = "3.12.13" },
    @{ GroupId = "com.squareup.okhttp3"; ArtifactId = "okhttp"; Version = "4.12.0" },
    @{ GroupId = "org.jetbrains.kotlin"; ArtifactId = "kotlin-stdlib"; Version = "1.9.24" },
    @{ GroupId = "org.jetbrains.kotlin"; ArtifactId = "kotlin-stdlib"; Version = "2.0.21" }
)

foreach ($a in $artifacts) {
    Install-MavenArtifact -GroupId $a.GroupId -ArtifactId $a.ArtifactId -Version $a.Version
}

Write-Host "Done. Local Maven repo: $mavenRoot"
