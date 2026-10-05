param([int]$Port = 8080)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot '.env'
if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'Create .env from .env.example and set MAPTILER_KEY before starting the app.'
}
$keyLine = Get-Content -LiteralPath $configPath |
    Where-Object { $_ -match '^\s*MAPTILER_KEY\s*=' } |
    Select-Object -First 1
if (-not $keyLine -or ($keyLine -split '=', 2)[1].Trim().Length -eq 0) {
    throw 'Set MAPTILER_KEY in .env before starting the app.'
}

Push-Location -LiteralPath $projectRoot
try {
    & flutter run -d web-server --web-port $Port --dart-define-from-file=.env
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter exited with code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}
