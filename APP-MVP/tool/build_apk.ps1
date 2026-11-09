param(
    [string]$ConfigFile = "config/production.json"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$resolvedConfig = Join-Path $projectRoot $ConfigFile

if (-not (Test-Path -LiteralPath $resolvedConfig)) {
    throw "No existe el archivo de configuración: $ConfigFile"
}

$versionLine = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9]+)?\s*$'
if (-not $versionLine) {
    throw "No se pudo obtener la versión desde pubspec.yaml."
}

$versionName = $versionLine.Matches[0].Groups[1].Value
$outputDirectory = Join-Path $projectRoot "build/app/outputs/flutter-apk"
$flutterApk = Join-Path $outputDirectory "app-release.apk"
$namedApk = Join-Path $outputDirectory "DocIA_V$versionName.apk"

Push-Location $projectRoot
try {
    flutter build apk --release "--dart-define-from-file=$ConfigFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter no pudo construir el APK."
    }
    Copy-Item -LiteralPath $flutterApk -Destination $namedApk -Force
    Write-Host "APK generado: $namedApk"
}
finally {
    Pop-Location
}
