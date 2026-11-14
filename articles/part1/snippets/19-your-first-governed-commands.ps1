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
