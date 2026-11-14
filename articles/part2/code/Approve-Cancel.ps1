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
  Completes the governed Flink cancel end to end: operator dry-run -> approver (bob) approves ->
  operator re-calls with the approval token and dry-run receipt -> the job actually stops.
.DESCRIPTION
  Shows separation of duties in action. The operator (eve) cannot cancel alone; an independent
  approver (bob) must sign off; then and only then does Aegis forward the cancel to Flink.
#>
param([int]$Port = 18080)
$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot

Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.UseProxy = $false
$http = New-Object System.Net.Http.HttpClient($handler)
$http.Timeout = [TimeSpan]::FromSeconds(60)

$tokens = Get-Content -Raw (Join-Path $Here 'run\keys\tokens.json') | ConvertFrom-Json
$state = Get-Content -Raw (Join-Path $Here 'run\state.json') | ConvertFrom-Json
$jobId = [string]$state.facts.'flink.jobId'
if (-not $jobId) { throw 'no flink.jobId in run/state.json' }

function Mcp([string]$Token, [string]$Tool, [hashtable]$Arguments, [hashtable]$ExtraMeta) {
    $meta = @{ 'io.modelcontextprotocol/protocolVersion' = '2026-07-28' }
    if ($ExtraMeta) { foreach ($k in @($ExtraMeta.Keys)) { $meta[$k] = $ExtraMeta[$k] } }
    $body = @{ jsonrpc = '2.0'; id = (Get-Random); method = 'tools/call'
        params = @{ name = $Tool; arguments = $Arguments; _meta = $meta } } | ConvertTo-Json -Depth 20 -Compress
    $req = New-Object System.Net.Http.HttpRequestMessage('POST', "http://127.0.0.1:$Port/mcp")
    $req.Headers.TryAddWithoutValidation('Authorization', "Bearer $Token") | Out-Null
    $req.Headers.TryAddWithoutValidation('Accept', 'application/json, text/event-stream') | Out-Null
    $req.Headers.TryAddWithoutValidation('MCP-Protocol-Version', '2026-07-28') | Out-Null
    $req.Headers.TryAddWithoutValidation('Mcp-Method', 'tools/call') | Out-Null
    $req.Headers.TryAddWithoutValidation('Mcp-Name', $Tool) | Out-Null
    $req.Content = New-Object System.Net.Http.StringContent($body, [System.Text.Encoding]::UTF8, 'application/json')
    $rsp = $http.SendAsync($req).GetAwaiter().GetResult()
    return ($rsp.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json)
}

function Approve([string]$ApproverToken, [string]$RequestId) {
    $req = New-Object System.Net.Http.HttpRequestMessage('POST', "http://127.0.0.1:$Port/aegis/v1/approvals/$RequestId/approve")
    $req.Headers.TryAddWithoutValidation('Authorization', "Bearer $ApproverToken") | Out-Null
    $req.Content = New-Object System.Net.Http.StringContent('{}', [System.Text.Encoding]::UTF8, 'application/json')
    $rsp = $http.SendAsync($req).GetAwaiter().GetResult()
    return [pscustomobject]@{ Status = [int]$rsp.StatusCode; Body = $rsp.Content.ReadAsStringAsync().GetAwaiter().GetResult() }
}

Write-Host "=== governed Flink cancel, end to end (jobId=$jobId) ==="

Write-Host "`n1) operator dry-run (preview + opens an approval request)"
$dry = Mcp $tokens.operator 'flink_cancel_job' @{ jobId = $jobId } @{ 'io.github.vaquarkhan.aegis/dryRun' = $true }
$dec = $dry.result._meta.'io.github.vaquarkhan.aegis/decision'
$receipt = [string]$dec.dryRunReceipt
$reqId = [string]$dec.approvalRequestId
Write-Host "   dryRunReceipt: $($receipt.Substring(0,[Math]::Min(40,$receipt.Length)))..."
Write-Host "   approvalRequestId: $reqId"

Write-Host "`n2) a non-approver (operator eve) tries to approve: must be refused"
$self = Approve $tokens.operator $reqId
Write-Host "   operator approve HTTP $($self.Status): $($self.Body)"

Write-Host "`n3) approver (bob) approves $reqId"
$ap = Approve $tokens.approver $reqId
Write-Host "   HTTP $($ap.Status): status=$(try { ($ap.Body | ConvertFrom-Json).status } catch { '?' }) decidedBy=$(try { ($ap.Body | ConvertFrom-Json).decidedBy } catch { '?' })"

Write-Host "`n4) requester (eve) collects the single-use approval token: GET /approvals/{id}"
$req = New-Object System.Net.Http.HttpRequestMessage('GET', "http://127.0.0.1:$Port/aegis/v1/approvals/$reqId")
$req.Headers.TryAddWithoutValidation('Authorization', "Bearer $($tokens.operator)") | Out-Null
$grsp = $http.SendAsync($req).GetAwaiter().GetResult()
$gbody = $grsp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
$apToken = [string]($gbody | ConvertFrom-Json).token
Write-Host "   token: $($apToken.Substring(0,[Math]::Min(36,$apToken.Length)))..."

Write-Host "`n5) operator re-calls cancel WITH approval token + dry-run receipt"
$meta = @{ 'io.github.vaquarkhan.aegis/dryRunReceipt' = $receipt;
           'io.github.vaquarkhan.aegis/approvalToken' = $apToken }
$final = Mcp $tokens.operator 'flink_cancel_job' @{ jobId = $jobId } $meta
$fdec = $final.result._meta.'io.github.vaquarkhan.aegis/decision'
Write-Host "   outcome: $($fdec.outcome)  $($final.result.content[0].text)"

Write-Host "`n6) single-use: replay the same approval -> must be refused"
$replay = Mcp $tokens.operator 'flink_cancel_job' @{ jobId = $jobId } $meta
$rdec = $replay.result._meta.'io.github.vaquarkhan.aegis/decision'
Write-Host "   outcome: $($rdec.outcome)  code: $($rdec.code)"

Write-Host "`n7) confirm on Flink: list jobs (state after the governed cancel)"
Start-Sleep -Seconds 2
$jobs = Mcp $tokens.operator 'flink_list_jobs' @{} $null
Write-Host "   $($jobs.result.content[0].text)"
