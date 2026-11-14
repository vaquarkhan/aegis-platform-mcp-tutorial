# Copyright 2026 Viquar Khan and the Aegis MCP Gateway contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

<#
.SYNOPSIS
  Starts real Flink, Iceberg, Spark and Kafka, then one Aegis MCP gateway that governs all four.
.DESCRIPTION
  Reuses the engine launchers from examples/break-glass-mcp-servers (same real engines the
  FrontDoors tests use). Leaves processes running; stop with .\Stop-All.ps1.
#>
$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
if (-not $env:AEGIS_HOME) {
    throw "set AEGIS_HOME to your aegis-mcp-gateway checkout (this tutorial is a standalone repo)."
}
$Repo = (Resolve-Path $env:AEGIS_HOME).Path
$BgLib = Join-Path $Repo 'examples\break-glass-mcp-servers\lib\BreakGlassMcp.psm1'
if (-not (Test-Path $BgLib)) { throw "missing $BgLib (is AEGIS_HOME correct? $Repo)" }
Import-Module $BgLib -Force -DisableNameChecking

$Run = Join-Path $Here 'run'
New-Item -ItemType Directory -Force -Path $Run, (Join-Path $Run 'audit'), (Join-Path $Run 'keys'), (Join-Path $Run 'logs') | Out-Null

Assert-BgPrerequisites @('flink', 'iceberg', 'spark', 'kafka')

$statePath = Join-Path $Run 'state.json'
if (Test-Path $statePath) {
    throw "already started (found $statePath). Run .\Stop-All.ps1 first."
}

# Tokens and signing key for this session (demo only).
function New-E2eToken { -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) }) }
$tokens = @{
    reader   = New-E2eToken
    operator = New-E2eToken
    approver = New-E2eToken
    outsider = New-E2eToken
}
$tokens | ConvertTo-Json | Set-Content (Join-Path $Run 'keys\tokens.json') -Encoding ascii

$allFacts = @{}
$engineProcs = @()
$order = @('flink', 'iceberg', 'spark', 'kafka')
foreach ($name in $order) {
    Write-Host ""
    Write-Host "=== starting real $name ==="
    $e = Get-BgEngine $name
    $work = Join-Path $Run "engine-$name"
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $started = Start-BgEngine $e $work
    foreach ($p in @($started.Processes)) {
        if ($null -ne $p -and -not $p.HasExited) {
            $engineProcs += [pscustomobject]@{ Name = $name; Pid = $p.Id }
        }
    }
    foreach ($k in $started.Facts.Keys) { $allFacts["$name.$k"] = [string]$started.Facts[$k] }
    Write-Host "  $name ready: $(($started.Facts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ')"
}

# One Aegis MCP for the platform (Kafka jar includes kafka-admin).
$gwJar = Join-Path $Repo 'examples\aegis-gateway-kafka\target\aegis-gateway-kafka-2.0.0-SNAPSHOT-all.jar'
$config = Join-Path $Here 'aegis.yaml'
$port = 18080
if (-not (Test-PortFree $port)) { throw "port $port is in use; stop whatever holds it" }

$envMap = @{
    AEGIS_SIGNING_KEY      = 'end-to-end-tutorial-signing-key-0123456789abcdef'
    AEGIS_E2E_READER       = $tokens.reader
    AEGIS_E2E_OPERATOR     = $tokens.operator
    AEGIS_E2E_APPROVER     = $tokens.approver
    AEGIS_E2E_OUTSIDER     = $tokens.outsider
    ICEBERG_CATALOG_TOKEN  = 'end-to-end-tutorial-catalog-credential'
}
$logs = Join-Path $Run 'logs'
$gwProc = Start-BgJava 'aegis-platform' @('-jar', $gwJar, '--config', $config) $logs $envMap
Wait-Until { (Invoke-Http 'GET' "http://127.0.0.1:$port/healthz" @{} $null).Status -eq 200 } 120 'Aegis platform MCP on 18080' $gwProc

# Shape the Iceberg catalog into the four-layer medallion lakehouse (bronze/silver/gold/restricted)
# that matches the Kafka -> Flink -> Iceberg -> Spark story. Runs straight against the catalog, the
# way a platform team provisions a lake out of band.
& (Join-Path $Here 'Seed-Medallion.ps1')

$state = [ordered]@{
    startedAt = (Get-Date -Format o)
    mcp       = "http://127.0.0.1:$port/mcp"
    gatewayPid = $gwProc.Id
    engines   = $engineProcs
    facts     = $allFacts
}
($state | ConvertTo-Json -Depth 6) | Set-Content $statePath -Encoding utf8

Write-Host ""
Write-Host "================================================================"
Write-Host " Aegis platform MCP is up (Flink + Iceberg + Spark + Kafka)"
Write-Host "================================================================"
Write-Host "  MCP endpoint : http://127.0.0.1:$port/mcp"
Write-Host "  Health       : http://127.0.0.1:$port/healthz"
Write-Host "  Catalog      : http://127.0.0.1:$port/aegis/v1/catalog  (approver token)"
Write-Host "  Tokens       : $Run\keys\tokens.json"
Write-Host "  Facts        : $(($allFacts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' | ')"
Write-Host ""
Write-Host "Next:"
Write-Host "  .\Run-Walkthrough.ps1     # guided MCP calls across all four engines"
Write-Host "  .\mcp.ps1 -Persona reader -Method tools/list"
Write-Host "  .\Stop-All.ps1            # when finished"
Write-Host ""
