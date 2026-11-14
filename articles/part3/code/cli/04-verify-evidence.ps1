# Download the latest evidence for this exact run and fail unless every hash and audit result matches.
param(
    [Parameter(Mandatory)][string]$GatewayJar,
    [string]$RuntimeDirectory = (Join-Path $env:LOCALAPPDATA 'AegisPart3')
)
. (Join-Path $PSScriptRoot 'common.ps1')
$RuntimeDirectory = Initialize-Part3Runtime $RuntimeDirectory
$state = Read-Part3State $RuntimeDirectory
if (-not (Test-Path $GatewayJar)) { throw "missing gateway jar $GatewayJar" }
$P = @('--profile',$state.profile,'--region',$state.region)
$evidencePrefix = "$($state.baseKey)/evidence/"
$latestKey = (Invoke-Aws (@('s3api','list-objects-v2','--bucket',$state.bucket,'--prefix',$evidencePrefix,'--query','sort_by(Contents,&LastModified)[-1].Key','--output','text') + $P)).Trim()
if ($latestKey -notmatch "^$([regex]::Escape($evidencePrefix))([^/]+)/") { throw "no evidence found under s3://$($state.bucket)/$evidencePrefix" }
$stamp = $Matches[1]
$destination = Join-Path $RuntimeDirectory "evidence-$stamp"
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Invoke-Aws (@('s3','sync',"s3://$($state.bucket)/$evidencePrefix$stamp/",$destination,'--only-show-errors') + $P) | Out-Null

foreach ($file in Get-ChildItem $destination -File) {
    $local = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLower()
    $remote = (Invoke-Aws (@('s3api','head-object','--bucket',$state.bucket,'--key',"$evidencePrefix$stamp/$($file.Name)",'--query','Metadata.sha256','--output','text') + $P)).Trim()
    if ($local -ne $remote) { throw "hash mismatch for $($file.Name): local=$local metadata=$remote" }
    Write-Output "HASH_OK $($file.Name) $local"
}

function Verify([string]$Path, [bool]$ExpectOk) {
    $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $output = & java -jar $GatewayJar --verify-audit $Path 2>&1 | Where-Object { $_ -notmatch 'JAVA_TOOL_OPTIONS' }; $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previous }
    $text = $output -join ' '
    if ($ExpectOk -and ($code -ne 0 -or $text -notmatch '^OK records=')) { throw "audit verification failed: $text" }
    if (-not $ExpectOk -and ($code -eq 0 -or $text -notmatch '^BROKEN records=')) { throw "tampered journal was not rejected: $text" }
    Write-Output $text
}
foreach ($name in 'aegis-platform.jsonl','aegis-platform-jwt.jsonl') {
    $path = Join-Path $destination $name
    if (-not (Test-Path $path)) { throw "missing required evidence $name" }
    Verify $path $true
}

$copy = Join-Path $destination 'tampered-jwt.jsonl'
$lines = Get-Content (Join-Path $destination 'aegis-platform-jwt.jsonl')
$match = $lines | Select-String -Pattern 'SCOPE_DENIED' | Select-Object -First 1
if (-not $match) { throw 'JWT journal has no SCOPE_DENIED record to tamper' }
$index = $match.LineNumber - 1
$lines[$index] = $lines[$index].Replace('SCOPE_DENIED','ALLOWED')
Set-Content $copy $lines -Encoding ascii
Verify $copy $false
Write-Output "VERIFY_OK stamp=$stamp directory=$destination"
