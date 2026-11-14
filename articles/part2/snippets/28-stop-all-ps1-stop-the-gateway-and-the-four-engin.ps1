# Copyright 2026 Viquar Khan and the Aegis MCP Gateway contributors. Licensed under the Apache License, Version 2.0.
<#
.SYNOPSIS
  Stops the Aegis platform gateway and the Flink / Iceberg / Spark / Kafka processes this tutorial started.
#>
$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$Run = Join-Path $Here 'run'
$statePath = Join-Path $Run 'state.json'
if (-not $env:AEGIS_HOME) {
    throw "set AEGIS_HOME to your aegis-mcp-gateway checkout before Stop-All."
}
$Repo = (Resolve-Path $env:AEGIS_HOME).Path

$pids = @()
if (Test-Path $statePath) {
    $state = Get-Content -Raw $statePath | ConvertFrom-Json
    if ($state.gatewayPid) { $pids += [int]$state.gatewayPid }
    foreach ($e in @($state.engines)) { if ($e.Pid) { $pids += [int]$e.Pid } }
}

# Also sweep pids recorded by the break-glass helper under our run tree and the four BG folders
# used when Get-BgEngine ran (best-effort).
$pidFiles = @(
    (Join-Path $Run 'pids.txt')
    (Join-Path $Repo 'examples\break-glass-mcp-servers\flink\run\pids.txt')
    (Join-Path $Repo 'examples\break-glass-mcp-servers\iceberg\run\pids.txt')
    (Join-Path $Repo 'examples\break-glass-mcp-servers\spark\run\pids.txt')
    (Join-Path $Repo 'examples\break-glass-mcp-servers\kafka\run\pids.txt')
)
foreach ($f in $pidFiles) {
    if (Test-Path $f) {
        foreach ($line in Get-Content $f) {
            $parts = $line.Split(' ', 2)
            if ($parts[0] -match '^\d+$') { $pids += [int]$parts[0] }
        }
    }
}

# Only ever stop java processes that belong to this tutorial. The gateway's command line names the
# jar under AEGIS_HOME; the engines are launched through argument files under this repo's run\ tree,
# so their command lines name THIS directory, not AEGIS_HOME. Accept either.
$pids = @($pids | Select-Object -Unique)
foreach ($id in $pids) {
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction SilentlyContinue
    if ($null -eq $p) { continue }
    $cl = [string]$p.CommandLine
    if ($p.Name -eq 'java.exe' -and ($cl -like "*$Repo*" -or $cl -like "*$Here*")) {
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
        Write-Host "stopped pid $id ($($p.Name))"
    }
}

Remove-Item $statePath -ErrorAction SilentlyContinue
foreach ($f in $pidFiles) { if (Test-Path $f) { Clear-Content $f -ErrorAction SilentlyContinue } }
Write-Host "Stop-All finished."
