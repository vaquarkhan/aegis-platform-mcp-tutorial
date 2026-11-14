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
  Walks the streaming-lakehouse scenario through one Aegis gateway: Kafka (raw orders stream) ->
  Flink (streaming ingest) -> Iceberg medallion (bronze/silver/gold/restricted) -> Spark (refinement),
  then an analyst reading gold, the scope and policy denials, and one governed Flink cancel.
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

function Invoke-Step([string]$Title, [string]$Persona, [string]$Tool, [hashtable]$Arguments, [string]$Expect) {
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
- Arguments: ``$argsJson``$(if ($Expect) { "`n- Expected: $Expect" })

``````json
$($out.Trim())
``````

"@
}

$md = @"
# Streaming lakehouse walkthrough, governed by one Aegis MCP gateway

Generated $(Get-Date -Format o).

Pipeline: **Kafka** (raw orders stream) -> **Flink** (streaming ingest) -> **Iceberg** medallion
(bronze -> silver -> gold, plus a restricted layer) -> **Spark** (refinement). Every ``tools/call``
below is classified, scoped, approved when needed, audited, and only then forwarded to the engine.

Engine facts from Start-All:

``````
$(($facts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "`n")
``````

## A. One surface across four engines

"@

$md += Invoke-Step 'A1. Reader lists MCP tools (Kafka + Flink + Iceberg + Spark, one gateway)' 'reader' $null $null ''

$md += @"
## B. The pipeline, read by the platform engineer (operator)

"@
$md += Invoke-Step 'B1. Kafka topics: the raw orders stream (source)' 'operator' 'kafka_list_topics' @{} 'ALLOWED'
$md += Invoke-Step 'B2. Kafka Connect: the orders-file-source feeding the stream' 'operator' 'connect_list_connectors' @{} 'ALLOWED'
$md += Invoke-Step 'B3. Flink cluster: the streaming ingest engine' 'operator' 'flink_get_cluster_info' @{} 'ALLOWED'
$md += Invoke-Step 'B4. Flink jobs: the running demo job' 'operator' 'flink_list_jobs' @{} 'ALLOWED'
$md += Invoke-Step 'B5. Iceberg namespaces: the medallion layers' 'operator' 'iceberg_list_namespaces' @{} 'ALLOWED (bronze, silver, gold, restricted)'
$md += Invoke-Step 'B6. Iceberg bronze: raw landing tables' 'operator' 'iceberg_list_tables' @{ namespace = 'bronze' } 'ALLOWED'
$md += Invoke-Step 'B7. Iceberg gold: curated business marts' 'operator' 'iceberg_list_tables' @{ namespace = 'gold' } 'ALLOWED'
$md += Invoke-Step 'B8. Spark applications: the medallion refinement job' 'operator' 'spark_list_applications' @{ limit = 10 } 'ALLOWED'

$md += @"
## C. Least privilege: the analyst (reader) sees only gold

"@
$md += Invoke-Step 'C1. Analyst reads gold tables (in scope)' 'reader' 'iceberg_list_tables' @{ namespace = 'gold' } 'ALLOWED'
$md += Invoke-Step 'C2. Analyst loads a gold mart schema' 'reader' 'iceberg_load_table' @{ namespace = 'gold'; table = 'daily_revenue' } 'ALLOWED'
$md += Invoke-Step 'C3. Analyst tries bronze raw (out of scope)' 'reader' 'iceberg_list_tables' @{ namespace = 'bronze' } 'DENIED: SCOPE_DENIED'
$md += Invoke-Step 'C4. Analyst tries restricted finance/PII (out of scope)' 'reader' 'iceberg_list_tables' @{ namespace = 'restricted' } 'DENIED: SCOPE_DENIED'

$md += @"
## D. Hard denials: no identity and protected data

"@
$md += Invoke-Step 'D1. Outsider with no groups reads Flink' 'outsider' 'flink_get_cluster_info' @{} 'DENIED: POLICY_DENIED'
$md += Invoke-Step 'D2. Operator tries to drop the restricted finance mart' 'operator' 'iceberg_drop_table' @{ namespace = 'restricted'; table = 'finance_pnl' } 'DENIED: POLICY_DENIED (never-drop-restricted)'

$md += @"
## E. Governed destructive action: cancel the streaming ingest job

A Flink cancel stops the running demo job, so it is DESTRUCTIVE: it needs a dry-run receipt and an
independent approval before Aegis forwards it.

"@
$jobId = $facts['flink.jobId']
if ($jobId) {
    $md += Invoke-Step 'E1. Operator cancels the Flink job without approval' 'operator' 'flink_cancel_job' @{ jobId = $jobId } 'DENIED: APPROVAL_REQUIRED (or dry-run required)'

    Write-Host ""
    Write-Host '-- E2. Operator: dry-run flink_cancel_job (preview receipt, nothing cancelled)'
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
### E2. Operator: dry-run flink_cancel_job (preview receipt)

- Expected: a dry-run receipt and a pending approval id; the job is still RUNNING

``````json
$dry
``````

"@
}

$outPath = Join-Path $Here 'run\WALKTHROUGH.md'
[System.IO.File]::WriteAllText($outPath, $md, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ""
Write-Host "Wrote $outPath"
Write-Host "To finish the governed cancel: approve the pending request as bob via"
Write-Host "  POST http://127.0.0.1:18080/aegis/v1/approvals/{id}/approve  (bob's bearer token)"
Write-Host "then re-call flink_cancel_job with the approval token + dry-run receipt in _meta (see README.md, "Destructive-action proof")."
