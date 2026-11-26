param(
    [int]$Port = 8089,
    [switch]$Rebuild
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

if ($Rebuild -or -not (Test-Path "build\web\index.html")) {
    Write-Host "Building Flutter Web..." -ForegroundColor Cyan
    if (Test-Path "env\dev.json") {
        flutter build web --dart-define-from-file=env/dev.json
    } else {
        flutter build web
    }
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Write-Host "Serving build\web at http://localhost:$Port ..." -ForegroundColor Green
python -m http.server $Port --directory build/web
