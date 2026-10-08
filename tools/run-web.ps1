param([ValidateSet(53923)][int]$Port = 53923)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$portProbe = [System.Net.Sockets.TcpClient]::new()
try {
    $connect = $portProbe.ConnectAsync('127.0.0.1', $Port)
    try { $null = $connect.Wait(500) } catch { }
    if ($portProbe.Connected) {
        Write-Host "App port $Port is already in use. Reuse the existing Flutter terminal: press r to hot reload or R to hot restart. To relaunch, quit that session with q first."
        return
    }
} finally {
    $portProbe.Dispose()
}
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
$chatProcess = $null
try {
    & (Join-Path $PSScriptRoot 'sync-map-config.ps1')
    $chatPort = 8787
    $chatPortLine = Get-Content -LiteralPath $configPath |
        Where-Object { $_ -match '^\s*CHAT_PORT\s*=\s*\d+\s*$' } |
        Select-Object -First 1
    if ($chatPortLine) { $chatPort = [int](($chatPortLine -split '=', 2)[1].Trim()) }
    if ($chatPort -ne 8787) {
        throw 'Set CHAT_PORT=8787 in .env to use the standard backend port.'
    }
    $health = $null
    try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:$chatPort/health" -TimeoutSec 2
    } catch { }
    if ($health -and $health.service -ne 'ligHAU-chat') {
        throw 'The chat port belongs to a different service.'
    }
    if (-not $health) {
        $chatProcess = Start-Process -FilePath 'node' -ArgumentList @('--env-file=.env', 'server/chat-server.mjs') `
            -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    }
    $flutterArgs = @('run', '-d', 'chrome', '--web-port', $Port)
    & flutter @flutterArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter exited with code $LASTEXITCODE."
    }
} finally {
    if ($chatProcess -and -not $chatProcess.HasExited) {
        Stop-Process -Id $chatProcess.Id
    }
    Pop-Location
}
