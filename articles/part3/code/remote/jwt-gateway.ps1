# Runs ON the instance. Restarts the stack for a fresh RUNNING Flink job, writes aegis-aws.yaml with
# Cognito JWT identity, starts that gateway on 18090 next to the static one on 18080, and drives the
# whole governed story with real Cognito ID tokens read from S3.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
foreach ($name in 'AEGIS_PART3_BUCKET','AEGIS_PART3_REGION','AEGIS_PART3_BASE_KEY') {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "missing environment variable $name (send this script through cli/ssm.ps1)" }
}
$Root = 'C:\aegis'
$env:JAVA_HOME = "$Root\tools\jdk17"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
$env:AEGIS_HOME = "$Root\src\aegis-mcp-gateway"
$T = "$Root\src\aegis-platform-mcp-tutorial"
$Log = "$Root\jwt.log"
Set-Content $Log "jwt start $((Get-Date).ToString('o'))"
function Log($m) { Add-Content $Log ([string]$m); Write-Output ([string]$m) }
function Section($t) { Log ''; Log "#### $t" }
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
$http.Timeout = [TimeSpan]::FromSeconds(60)

Set-Location $T
Section 'Fresh stack (Stop-All, Start-All) so the Flink job is RUNNING again'
if (Test-Path .\run\state.json) { & .\Stop-All.ps1 *>&1 | Out-Null }
$sw = [Diagnostics.Stopwatch]::StartNew()
& .\Start-All.ps1 *>&1 | Select-String -Pattern 'ready:|is up|Facts' | ForEach-Object { Log $_ }
Log "Start-All elapsed=$([int]$sw.Elapsed.TotalSeconds)s"
$state = Get-Content -Raw .\run\state.json | ConvertFrom-Json
$jobId = [string]$state.facts.'flink.jobId'
Log "flink.jobId=$jobId"

Section 'Cognito settings and tokens from S3'
$Bucket = $env:AEGIS_PART3_BUCKET
$runtimeKey = "$env:AEGIS_PART3_BASE_KEY/runtime"
Read-S3Object -BucketName $Bucket -Key "$runtimeKey/cognito.json" -File "$Root\cognito.json" -Region $env:AEGIS_PART3_REGION | Out-Null
Read-S3Object -BucketName $Bucket -Key "$runtimeKey/cognito-tokens.json" -File "$Root\cognito-tokens.json" -Region $env:AEGIS_PART3_REGION | Out-Null
$cog = Get-Content -Raw "$Root\cognito.json" | ConvertFrom-Json
$tok = Get-Content -Raw "$Root\cognito-tokens.json" | ConvertFrom-Json
Log "issuer=$($cog.issuer) audience=$($cog.client)"

Section 'aegis-aws.yaml: same file, only host.identity, egress, name and audit path change'
$yaml = Get-Content -Raw .\aegis.yaml
$oldHost = ($yaml -split "`r?`nhost:`r?`n")[1]
$hostIdx = $yaml.IndexOf("`nhost:")
$head = $yaml.Substring(0, $hostIdx + 1)
$newHost = @"
host:
  listen: {host: 127.0.0.1, port: 18090}
  identity:
    type: jwt
    jwt:
      issuer: $($cog.issuer)
      audience: $($cog.client)
      algorithms: [RS256]
      jwksUri: $($cog.issuer)/.well-known/jwks.json
      groupsClaim: cognito:groups
      subjectClaim: cognito:username
  stdio: {actor: ana, groups: [platform-readers]}
"@
$head = $head.Replace('name: aegis-platform', 'name: aegis-platform-aws')
$cognitoHost = ([uri]$cog.issuer).Host
$head = $head.Replace('allowCidrs: [127.0.0.0/8]', "allowCidrs: [127.0.0.0/8]`n  allowHosts: [$cognitoHost]")
$head = $head.Replace('file: ./run/audit/aegis-platform.jsonl', 'file: ./run/audit/aegis-platform-jwt.jsonl')
[IO.File]::WriteAllText("$T\aegis-aws.yaml", ($head + $newHost), (New-Object Text.UTF8Encoding($false)))
Log ((Get-Content "$T\aegis-aws.yaml" | Select-String -Pattern 'name:|allowHosts|audit|^host:|type: jwt|issuer|audience|jwksUri|groupsClaim|subjectClaim|listen' | Select-Object -First 14) -join "`n")

Section 'Start the JWT gateway on 18090'
$env:AEGIS_SIGNING_KEY = 'end-to-end-tutorial-signing-key-0123456789abcdef'
$env:ICEBERG_CATALOG_TOKEN = 'end-to-end-tutorial-catalog-credential'
$gw = Start-Process -FilePath java -ArgumentList @('-jar', "$env:AEGIS_HOME\examples\aegis-gateway-kafka\target\aegis-gateway-kafka-2.0.0-SNAPSHOT-all.jar", '--config', 'aegis-aws.yaml') -WorkingDirectory $T -PassThru -WindowStyle Hidden -RedirectStandardOutput "$Root\gw-jwt.out.log" -RedirectStandardError "$Root\gw-jwt.err.log"
$deadline = (Get-Date).AddSeconds(90)
do { Start-Sleep 2; $h = try { (Invoke-WebRequest -Uri http://127.0.0.1:18090/healthz -UseBasicParsing -TimeoutSec 5).Content } catch { $null } } while (-not $h -and (Get-Date) -lt $deadline -and -not $gw.HasExited)
Log "healthz 18090: $h (pid $($gw.Id), exited=$($gw.HasExited))"
if (-not $h) { Log (Get-Content "$Root\gw-jwt.err.log" -Tail 20 | Out-String); throw 'jwt gateway did not start' }
Log ((Get-Content "$Root\gw-jwt.out.log","$Root\gw-jwt.err.log" | Select-String -Pattern 'jwt|JWKS|identity|listening|WARN' | Select-Object -First 6) -join "`n")

function Mcp([string]$Token, [string]$Tool, [hashtable]$Arguments, [hashtable]$ExtraMeta, [string]$Method = 'tools/call') {
    $meta = @{ 'io.modelcontextprotocol/protocolVersion' = '2026-07-28' }
    if ($ExtraMeta) { foreach ($k in @($ExtraMeta.Keys)) { $meta[$k] = $ExtraMeta[$k] } }
    $params = @{ _meta = $meta }
    if ($Method -eq 'tools/call') { $params.name = $Tool; $params.arguments = $Arguments }
    $body = @{ jsonrpc = '2.0'; id = (Get-Random); method = $Method; params = $params } | ConvertTo-Json -Depth 20 -Compress
    $req = New-Object System.Net.Http.HttpRequestMessage('POST', 'http://127.0.0.1:18090/mcp')
    $req.Headers.TryAddWithoutValidation('Authorization', "Bearer $Token") | Out-Null
    $req.Headers.TryAddWithoutValidation('Accept', 'application/json, text/event-stream') | Out-Null
    $req.Headers.TryAddWithoutValidation('MCP-Protocol-Version', '2026-07-28') | Out-Null
    $req.Headers.TryAddWithoutValidation('Mcp-Method', $Method) | Out-Null
    if ($Tool) { $req.Headers.TryAddWithoutValidation('Mcp-Name', $Tool) | Out-Null }
    $req.Content = New-Object System.Net.Http.StringContent($body, [Text.Encoding]::UTF8, 'application/json')
    $rsp = $http.SendAsync($req).GetAwaiter().GetResult()
    $txt = $rsp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $json = $null
    try { $json = $txt | ConvertFrom-Json } catch { $json = $null }
    return [pscustomobject]@{ Status = [int]$rsp.StatusCode; Body = $txt; Json = $json }
}
function Decision($r) {
    if ($r.Json -and $r.Json.result) {
        $d = $r.Json.result._meta.'io.github.vaquarkhan.aegis/decision'
        $txt = ''
        if ($r.Json.result.content) { $txt = [string]$r.Json.result.content[0].text }
        if ($txt.Length -gt 300) { $txt = $txt.Substring(0, 300) + '...' }
        return "HTTP $($r.Status) outcome=$($d.outcome) $txt".Trim()
    }
    return "HTTP $($r.Status) $($r.Body)"
}
function Approve([string]$Token, [string]$RequestId) {
    $req = New-Object System.Net.Http.HttpRequestMessage('POST', "http://127.0.0.1:18090/aegis/v1/approvals/$RequestId/approve")
    $req.Headers.TryAddWithoutValidation('Authorization', "Bearer $Token") | Out-Null
    $req.Content = New-Object System.Net.Http.StringContent('{}', [Text.Encoding]::UTF8, 'application/json')
    $rsp = $http.SendAsync($req).GetAwaiter().GetResult()
    [pscustomobject]@{ Status = [int]$rsp.StatusCode; Body = $rsp.Content.ReadAsStringAsync().GetAwaiter().GetResult() }
}

function Assert-Decision($Response,[string]$Expected) {
    $actual = [string]$Response.Json.result._meta.'io.github.vaquarkhan.aegis/decision'.outcome
    if ($Response.Status -ne 200 -or $actual -ne $Expected) { throw "expected HTTP 200 $Expected, got $(Decision $Response)" }
    Log (Decision $Response)
}
try {
    Section 'J1 unknown bearer (a random string) on the JWT gateway'
    $r = Mcp 'not-a-jwt-at-all-0123456789' 'iceberg_list_namespaces' @{} $null
    if ($r.Status -ne 401) { throw "unknown bearer expected 401, got $($r.Status)" }; Log "HTTP 401 $($r.Body)"

    Section 'J2 ana tools/list'
    $r = Mcp $tok.ana '' @{} $null 'tools/list'
    if ($r.Status -ne 200 -or $r.Json.result.tools.Count -ne 14) { throw "ana expected 14 tools" }; Log 'HTTP 200 tool count=14'
    Section 'J3 ana lists gold'; Assert-Decision (Mcp $tok.ana 'iceberg_list_tables' @{namespace='gold'} $null) 'ALLOWED'
    Section 'J4 ana lists bronze'; Assert-Decision (Mcp $tok.ana 'iceberg_list_tables' @{namespace='bronze'} $null) 'DENIED:SCOPE_DENIED:step2'
    Section 'J5 outsider reads Flink'; Assert-Decision (Mcp $tok.outsider 'flink_get_cluster_info' @{} $null) 'DENIED:POLICY_DENIED:step3'
    Section 'J6 eve tools/list'
    $r = Mcp $tok.eve '' @{} $null 'tools/list'
    if ($r.Status -ne 200 -or $r.Json.result.tools.Count -ne 18) { throw "eve expected 18 tools" }; Log 'HTTP 200 tool count=18'
    Section 'J7 eve reads Flink'; Assert-Decision (Mcp $tok.eve 'flink_get_cluster_info' @{} $null) 'ALLOWED'
    Section 'J8 eve drops restricted.finance_pnl'; Assert-Decision (Mcp $tok.eve 'iceberg_drop_table' @{namespace='restricted';table='finance_pnl'} $null) 'DENIED:POLICY_DENIED:step3'
    Section 'J9 eve cancels without approval'; Assert-Decision (Mcp $tok.eve 'flink_cancel_job' @{jobId=$jobId} $null) 'DENIED:APPROVAL_REQUIRED:step4'

    Section 'J10 eve dry-run'
    $dry = Mcp $tok.eve 'flink_cancel_job' @{jobId=$jobId} @{'io.github.vaquarkhan.aegis/dryRun'=$true}
    $dec = $dry.Json.result._meta.'io.github.vaquarkhan.aegis/decision'
    $receipt = [string]$dec.dryRunReceipt; $reqId = [string]$dec.approvalRequestId
    if ($dry.Status -ne 200 -or $dec.outcome -ne 'ALLOWED' -or -not $receipt -or -not $reqId) { throw 'dry-run did not return receipt and approval id' }
    Log "ALLOWED approvalRequestId=$reqId receipt issued"

    Section 'J11 eve tries to approve'; $a = Approve $tok.eve $reqId; if ($a.Status -ne 403) { throw "eve approval expected 403" }; Log "HTTP 403 $($a.Body)"
    Section 'J12 ana tries to approve'; $a = Approve $tok.ana $reqId; if ($a.Status -ne 403) { throw "ana approval expected 403" }; Log "HTTP 403 $($a.Body)"
    Section 'J13 bob approves'; $a = Approve $tok.bob $reqId; if ($a.Status -ne 200 -or $a.Body -notmatch '"decidedBy":"bob"') { throw "bob approval failed" }; Log "HTTP 200 decidedBy=bob"

    Section 'J14 eve collects approval token'
    $req = New-Object System.Net.Http.HttpRequestMessage('GET', "http://127.0.0.1:18090/aegis/v1/approvals/$reqId")
    $req.Headers.TryAddWithoutValidation('Authorization', "Bearer $($tok.eve)") | Out-Null
    $g = $http.SendAsync($req).GetAwaiter().GetResult(); $gb = $g.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $apToken = [string]($gb | ConvertFrom-Json).token
    if ([int]$g.StatusCode -ne 200 -or -not $apToken) { throw 'eve did not receive approval token' }; Log 'HTTP 200 approval token issued'

    $meta = @{'io.github.vaquarkhan.aegis/dryRunReceipt'=$receipt;'io.github.vaquarkhan.aegis/approvalToken'=$apToken}
    Section 'J15 eve cancels'; Assert-Decision (Mcp $tok.eve 'flink_cancel_job' @{jobId=$jobId} $meta) 'ALLOWED'
    Section 'J16 replay'; Assert-Decision (Mcp $tok.eve 'flink_cancel_job' @{jobId=$jobId} $meta) 'DENIED:APPROVAL_REQUIRED:step4'
    Start-Sleep 2
    $jobs = (Invoke-WebRequest http://127.0.0.1:18081/jobs/overview -UseBasicParsing).Content | ConvertFrom-Json
    if ($jobs.jobs[0].state -ne 'CANCELED' -or $jobs.jobs[0].tasks.total -ne 1) { throw 'Flink did not end CANCELED with one task' }
    Log 'Flink CANCELED total=1'

    $journal = '.\run\audit\aegis-platform-jwt.jsonl'
    $verify = (& java -jar "$env:AEGIS_HOME\examples\aegis-gateway-kafka\target\aegis-gateway-kafka-2.0.0-SNAPSHOT-all.jar" --verify-audit $journal 2>&1 | Where-Object { $_ -notmatch 'JAVA_TOOL_OPTIONS' }) -join ' '
    if ($LASTEXITCODE -ne 0 -or $verify -notmatch '^OK records=') { throw "JWT audit failed: $verify" }
    Log $verify
    Log 'JWT_OK'
} finally {
    if ($gw -and -not $gw.HasExited) { Stop-Process -Id $gw.Id -Force -ErrorAction SilentlyContinue }
    Remove-Item "$Root\cognito-tokens.json","$Root\cognito.json" -Force -ErrorAction SilentlyContinue
}
