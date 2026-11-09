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
  Runs the tutorial scenario: reads across Flink, Iceberg, Spark and Kafka, then one governed Flink cancel.
.DESCRIPTION
  Requires .\Start-All.ps1 to have left the stack running. Writes run/WALKTHROUGH.md with each step.
#>
$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$statePath = Join-Path $Here 'run\state.json'
if (-not (Test-Path $statePath)) { throw 'stack is not running: .\Start-All.ps1 first' }
$state = Get-Content -Raw $statePath | ConvertFrom-Json
$facts = @{}
foreach ($p in $state.facts.PSObject.Properties) { $facts[$p.Name] = [string]$p.Value }

function Invoke-Step([string]$Title, [string]$Persona, [string]$Tool, [hashtable]$Arguments) {
    Write-Host ""
    Write-Host "-- $Title"
    $argsJson = if ($Arguments) { ($Arguments | ConvertTo-Json -Compress) } else { '{}' }
    $mcp = Join-Path $Here 'mcp.ps1'
    if ($Tool) {
        $out = & $mcp -Persona $Persona -Tool $Tool -Arguments $Arguments 2>&1 | Out-String
    } else {
        $out = & $mcp -Persona $Persona -Method tools/list 2>&1 | Out-String
    }
    Write-Host $out.Trim()
    return @"
### $Title

- Persona: ``$Persona``
- Tool: ``$(if ($Tool) { $Tool } else { 'tools/list' })``
- Arguments: ``$argsJson``

``````json
$($out.Trim())
``````

"@
}

$md = @"
# End-to-end walkthrough result

Generated $(Get-Date -Format o).

Engine facts from Start-All:

``````
$(($facts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "`n")
``````

"@

$md += Invoke-Step '1. Reader lists MCP tools' 'reader' $null $null
$md += Invoke-Step '2. Reader: Flink cluster overview' 'reader' 'flink_get_cluster_info' @{}
$md += Invoke-Step '3. Reader: Iceberg sales tables (in scope)' 'reader' 'iceberg_list_tables' @{ namespace = 'sales' }
$md += Invoke-Step '4. Reader: Iceberg finance tables (scope denied)' 'reader' 'iceberg_list_tables' @{ namespace = 'finance' }
$md += Invoke-Step '5. Reader: Kafka topics' 'reader' 'kafka_list_topics' @{}
$md += Invoke-Step '6. Reader: Spark applications' 'reader' 'spark_list_applications' @{ limit = 10 }
$md += Invoke-Step '7. Outsider: Flink cluster (no groups)' 'outsider' 'flink_get_cluster_info' @{}
$md += Invoke-Step '8. Operator: Kafka connectors' 'operator' 'connect_list_connectors' @{}

$jobId = $facts['flink.jobId']
if ($jobId) {
    $md += Invoke-Step '9. Operator: Flink cancel without approval (should need approval)' 'operator' 'flink_cancel_job' @{ jobId = $jobId }
    # Dry-run path: call with dryRun meta via direct curl for clarity in the log
    Write-Host ""
    Write-Host '-- 10. Operator: dry-run flink_cancel_job (preview receipt)'
    $tokens = Get-Content -Raw (Join-Path $Here 'run\keys\tokens.json') | ConvertFrom-Json
    $bodyObj = @{
        jsonrpc = '2.0'; id = 99; method = 'tools/call'
        params = @{
            name = 'flink_cancel_job'
            arguments = @{ jobId = $jobId }
            _meta = @{
                'io.modelcontextprotocol/protocolVersion' = '2026-07-28'
                'io.github.vaquarkhan.aegis/dryRun' = $true
            }
        }
    }
    $tmp = Join-Path $env:TEMP 'aegis-e2e-dryrun.json'
    ($bodyObj | ConvertTo-Json -Depth 20 -Compress) | Set-Content $tmp -Encoding ascii
    $dry = & curl.exe -sS -m 60 -X POST 'http://127.0.0.1:18080/mcp' `
        -H "Authorization: Bearer $($tokens.operator)" `
        -H 'Accept: application/json, text/event-stream' `
        -H 'MCP-Protocol-Version: 2026-07-28' `
        -H 'Mcp-Method: tools/call' `
        -H 'Mcp-Name: flink_cancel_job' `
        -H 'Content-Type: application/json' `
        --data-binary "@$tmp"
    Remove-Item $tmp -ErrorAction SilentlyContinue
    Write-Host $dry
    $md += @"
### 10. Operator: dry-run flink_cancel_job

``````json
$dry
``````

"@
}

$outPath = Join-Path $Here 'run\WALKTHROUGH.md'
[System.IO.File]::WriteAllText($outPath, $md, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ""
Write-Host "Wrote $outPath"
Write-Host "Tip: approve pending requests as bob via POST /aegis/v1/approvals/{id}/approve then re-call with the token + receipt (see TUTORIAL.md)."
