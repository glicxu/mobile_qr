$ErrorActionPreference = 'Stop'

dart run tool/generate_verification_fixtures.dart

$artifactDirectory = Join-Path (Resolve-Path 'build') 'zxing'
New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null

$artifacts = @{
    'core-3.5.3.jar' = 'https://repo1.maven.org/maven2/com/google/zxing/core/3.5.3/core-3.5.3.jar'
    'javase-3.5.3.jar' = 'https://repo1.maven.org/maven2/com/google/zxing/javase/3.5.3/javase-3.5.3.jar'
    'jcommander-1.82.jar' = 'https://repo1.maven.org/maven2/com/beust/jcommander/1.82/jcommander-1.82.jar'
}

foreach ($artifact in $artifacts.GetEnumerator()) {
    $destination = Join-Path $artifactDirectory $artifact.Key
    if (-not (Test-Path -LiteralPath $destination)) {
        Invoke-WebRequest -Uri $artifact.Value -OutFile $destination
    }
}

$classPath = @(
    (Join-Path $artifactDirectory 'core-3.5.3.jar')
    (Join-Path $artifactDirectory 'javase-3.5.3.jar')
    (Join-Path $artifactDirectory 'jcommander-1.82.jar')
) -join ';'

foreach ($fixtureName in @('ascii', 'unicode')) {
    $pngPath = (Resolve-Path "build/qr_fixtures/$fixtureName.png").Path
    $pngUri = 'file:///' + ($pngPath -replace '\\', '/')
    $expected = (Get-Content -LiteralPath "build/qr_fixtures/$fixtureName.txt" -Raw -Encoding utf8).Trim()
    $output = java '-Dfile.encoding=UTF-8' '-Dstdout.encoding=UTF-8' -cp $classPath com.google.zxing.client.j2se.CommandLineRunner $pngUri 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "ZXing failed to decode $fixtureName.png.`n$output"
    }
    if (-not $output.Contains($expected)) {
        throw "ZXing did not return the exact payload for $fixtureName.png.`n$output"
    }
    Write-Output "ZXing exact round trip passed: $fixtureName"
}
