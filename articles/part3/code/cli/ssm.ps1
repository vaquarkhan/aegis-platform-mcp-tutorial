# Run a public remote/*.ps1 script through Systems Manager and fail unless SSM reports Success/0.
# Run from articles/part3/code, for example:
#   .\cli\ssm.ps1 -ScriptPath .\remote\install.ps1 -Label install
param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Label,
    [int]$TimeoutSeconds = 3600,
    [string]$RuntimeDirectory = (Join-Path $env:LOCALAPPDATA 'AegisPart3')
)
. (Join-Path $PSScriptRoot 'common.ps1')
$RuntimeDirectory = Initialize-Part3Runtime $RuntimeDirectory
$state = Read-Part3State $RuntimeDirectory
if (-not $state.instanceId) { throw 'state has no instanceId; run 02-launch.ps1 first' }
if (-not (Test-Path $ScriptPath)) { throw "missing $ScriptPath" }
$script = Get-Content -Raw $ScriptPath

# Supply deployment values as environment variables. Remote scripts contain no account, bucket, region, or run id.
$prefix = @"
`$env:AEGIS_PART3_BUCKET = '$($state.bucket.Replace("'","''"))'
`$env:AEGIS_PART3_REGION = '$($state.region.Replace("'","''"))'
`$env:AEGIS_PART3_BASE_KEY = '$($state.baseKey.Replace("'","''"))'
`$env:AEGIS_PART3_BUNDLE_SHA256 = '$($state.bundleSha256.Replace("'","''"))'
"@
$bytes = [Text.Encoding]::Unicode.GetBytes($prefix + "`r`n" + $script)
$base64 = [Convert]::ToBase64String($bytes)
$chunks = @()
for ($offset = 0; $offset -lt $base64.Length; $offset += 4000) {
    $chunks += $base64.Substring($offset, [Math]::Min(4000, $base64.Length - $offset))
}
$commands = @('$b = ""')
foreach ($chunk in $chunks) { $commands += ('$b += "' + $chunk + '"') }
$commands += '$code = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($b))'
$commands += 'New-Item -ItemType Directory -Force -Path C:\aegis | Out-Null'
$commands += '[IO.File]::WriteAllText("C:\aegis\ssm-script.ps1", $code, [Text.Encoding]::Unicode)'
$commands += 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\aegis\ssm-script.ps1; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }'

$paramsFile = Join-Path $RuntimeDirectory "ssm-$Label.params.json"
[IO.File]::WriteAllText($paramsFile, (@{ commands = $commands; executionTimeout = @("$TimeoutSeconds") } | ConvertTo-Json -Compress -Depth 4))
$P = @('--profile',$state.profile,'--region',$state.region)
$commandId = (Invoke-Aws (@('ssm','send-command','--instance-ids',$state.instanceId,'--document-name','AWS-RunPowerShellScript','--parameters',"file://$paramsFile",'--timeout-seconds','600','--comment',"aegis-part3 $Label",'--query','Command.CommandId','--output','text') + $P)).Trim()
Assert-Value 'SSM command id' $commandId '^[0-9a-f-]{36}$'

$deadline = (Get-Date).AddSeconds($TimeoutSeconds + 120)
do {
    Start-Sleep -Seconds 15
    $invocationText = (Invoke-Aws (@('ssm','get-command-invocation','--command-id',$commandId,'--instance-id',$state.instanceId,'--output','json') + $P)) -join "`n"
    $invocation = $invocationText | ConvertFrom-Json
} while ($invocation.Status -in @('Pending','InProgress','Delayed') -and (Get-Date) -lt $deadline)

$log = Join-Path $RuntimeDirectory "ssm-$Label.log"
@("command=$commandId", "status=$($invocation.Status)", "responseCode=$($invocation.ResponseCode)", '----- STDOUT', $invocation.StandardOutputContent, '----- STDERR', $invocation.StandardErrorContent) |
    Set-Content $log -Encoding utf8
if ($invocation.Status -ne 'Success' -or $invocation.ResponseCode -ne 0) {
    throw "SSM $Label failed: status=$($invocation.Status) responseCode=$($invocation.ResponseCode); see $log"
}
Write-Output "SSM_OK label=$Label command=$commandId log=$log"
