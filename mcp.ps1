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
  One MCP tools/call (or tools/list) against the running platform gateway.
.EXAMPLE
  .\mcp.ps1 -Persona reader -Method tools/list
.EXAMPLE
  .\mcp.ps1 -Persona operator -Tool flink_list_jobs
.EXAMPLE
  .\mcp.ps1 -Persona operator -Tool iceberg_list_tables -Arguments @{ namespace = 'sales' }
#>
param(
    [ValidateSet('reader', 'operator', 'approver', 'outsider')][string]$Persona = 'reader',
    [string]$Method = 'tools/call',
    [string]$Tool,
    [hashtable]$Arguments,
    [hashtable]$Meta,
    [int]$Port = 18080
)
$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$tokensFile = Join-Path $Here 'run\keys\tokens.json'
if (-not (Test-Path $tokensFile)) { throw "start the stack first: .\Start-All.ps1 (missing $tokensFile)" }
$t = Get-Content -Raw $tokensFile | ConvertFrom-Json
$token = switch ($Persona) {
    'reader' { $t.reader }
    'operator' { $t.operator }
    'approver' { $t.approver }
    'outsider' { $t.outsider }
}

$id = Get-Random -Minimum 1 -Maximum 999999
$metaObj = @{
    'io.modelcontextprotocol/protocolVersion' = '2026-07-28'
    'io.modelcontextprotocol/clientCapabilities' = @{}
}
# $Meta (param) and $meta (local) would be the SAME variable: PowerShell names are case-insensitive.
# Use a distinct name, and iterate a static copy of the keys so a merge never mutates mid-enumeration.
if ($Meta) { foreach ($k in @($Meta.Keys)) { $metaObj[$k] = $Meta[$k] } }
$params = @{ '_meta' = $metaObj }
if ($Method -eq 'tools/call') {
    if (-not $Tool) { throw '-Tool is required for tools/call' }
    $params['name'] = $Tool
    if ($null -eq $Arguments) { $Arguments = @{} }
    $params['arguments'] = $Arguments
}
$body = (@{ jsonrpc = '2.0'; id = $id; method = $Method; params = $params } | ConvertTo-Json -Depth 20 -Compress)
$tmp = Join-Path $env:TEMP ("aegis-e2e-mcp-" + [guid]::NewGuid().ToString('n') + '.json')
Set-Content -Path $tmp -Value $body -Encoding ascii
$curlArgs = @(
    '-sS', '-m', '60', '-X', 'POST', "http://127.0.0.1:$Port/mcp",
    '-H', "Authorization: Bearer $token",
    '-H', 'Accept: application/json, text/event-stream',
    '-H', 'MCP-Protocol-Version: 2026-07-28',
    '-H', "Mcp-Method: $Method",
    '-H', 'Content-Type: application/json',
    '--data-binary', "@$tmp"
)
if ($Tool) { $curlArgs = @('-H', "Mcp-Name: $Tool") + $curlArgs }
try {
    $raw = & curl.exe @curlArgs
} finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
}
Write-Output $raw
