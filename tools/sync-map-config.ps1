$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    throw 'Create .env and set MAPTILER_KEY first.'
}
$mapSettings = @{ MAPTILER_KEY = ''; MAPTILER_STYLE_ID = 'streets-v4' }
foreach ($line in Get-Content -LiteralPath $envPath) {
    if ($line -match '^\s*(MAPTILER_KEY|MAPTILER_STYLE_ID)\s*=(.*)$') {
        $mapSettings[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
    }
}
if ([string]::IsNullOrWhiteSpace($mapSettings.MAPTILER_KEY)) {
    throw 'Set MAPTILER_KEY in .env first.'
}
$assetDirectory = Join-Path $projectRoot 'assets/config'
[void](New-Item -ItemType Directory -Path $assetDirectory -Force)
$assetPath = Join-Path $assetDirectory 'map.local.json'
$json = ConvertTo-Json -InputObject $mapSettings
[System.IO.File]::WriteAllText($assetPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output 'Local browser map configuration updated.'
