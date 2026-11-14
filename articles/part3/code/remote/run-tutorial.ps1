# Runs ON the instance. Replays the Part 1 and Part 2 static-token tutorial and asserts every result.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Root = 'C:\aegis'
$env:JAVA_HOME = "$Root\tools\jdk17"
$env:Path = "$env:JAVA_HOME\bin;$Root\tools\apache-maven-3.9.11\bin;$Root\tools\mingit\cmd;$env:Path"
$env:AEGIS_HOME = "$Root\src\aegis-mcp-gateway"
$Tutorial = "$Root\src\aegis-platform-mcp-tutorial"
$Log = "$Root\tutorial.log"
Set-Content $Log "tutorial start $((Get-Date).ToString('o'))"
function Log($value) { Add-Content $Log ([string]$value); Write-Output ([string]$value) }
function Call([string]$Persona,[string]$Tool,[hashtable]$Arguments) {
    $text = & .\mcp.ps1 -Persona $Persona -Tool $Tool -Arguments $Arguments
    return ($text | ConvertFrom-Json)
}
function Assert-Outcome($response,[string]$Expected) {
    $actual = [string]$response.result._meta.'io.github.vaquarkhan.aegis/decision'.outcome
    if ($actual -ne $Expected) { throw "expected $Expected, got $actual : $($response | ConvertTo-Json -Depth 8 -Compress)" }
    Log "$Expected $($response.result.content[0].text)"
}
Set-Location $Tutorial
if (Test-Path .\run\state.json) { & .\Stop-All.ps1 | Out-Null }
$timer = [Diagnostics.Stopwatch]::StartNew()
& .\Start-All.ps1 | ForEach-Object { Log $_ }
if (-not (Test-Path .\run\state.json)) { throw 'Start-All did not produce run/state.json' }
$health = (Invoke-WebRequest http://127.0.0.1:18080/healthz -UseBasicParsing -TimeoutSec 10).Content
if ($health -notmatch '"status":"ok"') { throw "bad health response: $health" }
Log "Start-All elapsed=$([int]$timer.Elapsed.TotalSeconds)s health=$health"

Assert-Outcome (Call reader iceberg_list_tables @{namespace='gold'}) 'ALLOWED'
Assert-Outcome (Call reader iceberg_list_tables @{namespace='bronze'}) 'DENIED:SCOPE_DENIED:step2'
Assert-Outcome (Call outsider flink_get_cluster_info @{}) 'DENIED:POLICY_DENIED:step3'
$readerTools = ((& .\mcp.ps1 -Persona reader -Method tools/list | ConvertFrom-Json).result.tools).Count
$operatorTools = ((& .\mcp.ps1 -Persona operator -Method tools/list | ConvertFrom-Json).result.tools).Count
if ($readerTools -ne 14 -or $operatorTools -ne 18) { throw "tool counts reader=$readerTools operator=$operatorTools" }
Log "tool counts reader=14 operator=18"
Assert-Outcome (Call operator iceberg_drop_table @{namespace='restricted';table='finance_pnl'}) 'DENIED:POLICY_DENIED:step3'

$jobId = [string](Get-Content -Raw .\run\state.json | ConvertFrom-Json).facts.'flink.jobId'
Assert-Outcome (Call operator flink_cancel_job @{jobId=$jobId}) 'DENIED:APPROVAL_REQUIRED:step4'
$before = (Invoke-WebRequest http://127.0.0.1:18081/jobs/overview -UseBasicParsing).Content | ConvertFrom-Json
if ($before.jobs[0].state -ne 'RUNNING' -or $before.jobs[0].tasks.total -ne 1) { throw "Flink was not RUNNING with one task before approval" }
Log "Flink before approval: RUNNING total=1"

$approvalOutput = (& .\Approve-Cancel.ps1 2>&1) -join "`n"
Log $approvalOutput
foreach ($required in 'operator approve HTTP 403','HTTP 200: status=APPROVED decidedBy=bob','outcome: ALLOWED','DENIED:APPROVAL_REQUIRED:step4','"state":"CANCELED"') {
    if ($approvalOutput -notmatch [regex]::Escape($required)) { throw "Approve-Cancel output missing: $required" }
}
$after = (Invoke-WebRequest http://127.0.0.1:18081/jobs/overview -UseBasicParsing).Content | ConvertFrom-Json
if ($after.jobs[0].state -ne 'CANCELED' -or $after.jobs[0].tasks.total -ne 1) { throw 'Flink did not end CANCELED with one task' }

$jar = "$env:AEGIS_HOME\examples\aegis-gateway-kafka\target\aegis-gateway-kafka-2.0.0-SNAPSHOT-all.jar"
$verify = (& java -jar $jar --verify-audit .\run\audit\aegis-platform.jsonl 2>&1 | Where-Object { $_ -notmatch 'JAVA_TOOL_OPTIONS' }) -join ' '
if ($LASTEXITCODE -ne 0 -or $verify -notmatch '^OK records=') { throw "audit failed: $verify" }
Log $verify
Log 'TUTORIAL_OK'
