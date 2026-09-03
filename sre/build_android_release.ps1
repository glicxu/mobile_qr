param(
    [ValidateSet('aab', 'apk')]
    [string]$Artifact = 'aab',
    [string]$BuildName = '',
    [int]$BuildNumber = 0,
    [switch]$NoPubGet,
    [switch]$UploadToPlay,
    [string]$ServiceAccountJson = '',
    [string]$PackageName = 'com.dalifin.qr',
    [string]$Track = 'internal',
    [ValidateSet('draft', 'inProgress', 'completed', 'halted')]
    [string]$Status = 'draft',
    [string]$ReleaseName = '',
    [string]$ReleaseNotes = '',
    [string]$ReleaseNotesFile = '',
    [switch]$Commit
)

$ErrorActionPreference = 'Stop'

$sreDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $sreDir
Set-Location $repoDir

function Get-PubspecVersion {
    $match = Select-String -Path (Join-Path $repoDir 'pubspec.yaml') -Pattern '^\s*version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+\d+)?\s*$'
    if (-not $match) {
        throw 'Could not find semantic version in pubspec.yaml'
    }
    return $match.Matches[0].Groups[1].Value
}

function Get-DefaultBuildNumber {
    $now = Get-Date
    return [int]($now.ToString('yyyyMMddHH'))
}

$resolvedBuildNumber = if ($BuildNumber -gt 0) { $BuildNumber } else { Get-DefaultBuildNumber }
if ($resolvedBuildNumber -gt 2100000000) {
    throw "Build number must stay within Android versionCode limits: $resolvedBuildNumber"
}

$resolvedBuildName = if ([string]::IsNullOrWhiteSpace($BuildName)) {
    Get-PubspecVersion
} else {
    $BuildName.Trim()
}

$keyPropertiesPath = Join-Path $repoDir 'android\key.properties'
if (-not (Test-Path $keyPropertiesPath)) {
    throw "Missing release signing config: $keyPropertiesPath"
}

if ($UploadToPlay.IsPresent -and $Artifact -ne 'aab') {
    throw 'Google Play uploads require -Artifact aab.'
}

if (-not $NoPubGet) {
    flutter pub get
}

$flutterCommand = if ($Artifact -eq 'aab') { 'appbundle' } else { 'apk' }
$flutterArgs = @(
    'build', $flutterCommand,
    '--release',
    '--build-name', $resolvedBuildName,
    '--build-number', "$resolvedBuildNumber"
)

Write-Host "Building Android $($Artifact.ToUpper())..." -ForegroundColor Cyan
Write-Host "  Package:      $PackageName"
Write-Host "  Build name:   $resolvedBuildName"
Write-Host "  Build number: $resolvedBuildNumber"

& flutter @flutterArgs
if ($LASTEXITCODE -ne 0) {
    throw "flutter build $flutterCommand failed with exit code $LASTEXITCODE"
}

$artifactPath = if ($Artifact -eq 'aab') {
    Join-Path $repoDir "build\app\outputs\bundle\release\app-release.aab"
} else {
    Join-Path $repoDir "build\app\outputs\flutter-apk\app-release.apk"
}
if (-not (Test-Path $artifactPath)) {
    throw "Expected artifact not found: $artifactPath"
}

Write-Host ''
Write-Host 'Build complete.' -ForegroundColor Green
Get-Item $artifactPath | Select-Object FullName, Length, LastWriteTime | Format-List

if ($UploadToPlay.IsPresent) {
    $uploadScript = Join-Path $repoDir 'scripts\upload_google_play_bundle.py'
    if (-not (Test-Path $uploadScript)) {
        $uploadScript = Join-Path (Split-Path -Parent $repoDir) 'interprete\scripts\upload_google_play_bundle.py'
    }
    if (-not (Test-Path $uploadScript)) {
        throw "Google Play upload script not found: $uploadScript"
    }

    $uploadArgs = @(
        $uploadScript,
        '--aab', $artifactPath,
        '--package-name', $PackageName,
        '--track', $Track,
        '--status', $Status
    )
    if (-not [string]::IsNullOrWhiteSpace($ServiceAccountJson)) {
        $uploadArgs += @('--service-account-json', $ServiceAccountJson)
    }
    if (-not [string]::IsNullOrWhiteSpace($ReleaseName)) {
        $uploadArgs += @('--release-name', $ReleaseName)
    }
    if (-not [string]::IsNullOrWhiteSpace($ReleaseNotes)) {
        $uploadArgs += @('--release-notes', $ReleaseNotes)
    }
    if (-not [string]::IsNullOrWhiteSpace($ReleaseNotesFile)) {
        $uploadArgs += @('--release-notes-file', $ReleaseNotesFile)
    }
    if ($Commit.IsPresent) {
        $uploadArgs += '--commit'
    }

    Write-Host ''
    Write-Host "Uploading to Google Play track '$Track'..." -ForegroundColor Cyan
    & python @uploadArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Google Play upload failed with exit code $LASTEXITCODE"
    }
}
