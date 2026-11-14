# Runs ON the instance. Uploads required journals and logs to this run's evidence prefix.
$ErrorActionPreference = 'Stop'
foreach ($name in 'AEGIS_PART3_BUCKET','AEGIS_PART3_REGION','AEGIS_PART3_BASE_KEY') {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "missing environment variable $name (send this script through cli/ssm.ps1)" }
}
$Bucket = $env:AEGIS_PART3_BUCKET
$Region = $env:AEGIS_PART3_REGION
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$keyRoot = "$env:AEGIS_PART3_BASE_KEY/evidence/$stamp"
$Tutorial = 'C:\aegis\src\aegis-platform-mcp-tutorial'
$required = [ordered]@{
    'C:\aegis\install.log' = 'install.log'
    'C:\aegis\tutorial.log' = 'tutorial.log'
    'C:\aegis\jwt.log' = 'jwt.log'
    "$Tutorial\run\audit\aegis-platform.jsonl" = 'aegis-platform.jsonl'
    "$Tutorial\run\audit\aegis-platform-jwt.jsonl" = 'aegis-platform-jwt.jsonl'
    "$Tutorial\run\state.json" = 'state.json'
}
foreach ($path in $required.Keys) { if (-not (Test-Path $path)) { throw "missing required evidence $path" } }
foreach ($path in $required.Keys) {
    # The gateway may hold the journal open. Copy using shared read access before upload.
    $temporary = Join-Path $env:TEMP ("aegis-evidence-" + $required[$path])
    $source = [IO.File]::Open($path,'Open','Read','ReadWrite')
    try { $memory = New-Object IO.MemoryStream; $source.CopyTo($memory); [IO.File]::WriteAllBytes($temporary,$memory.ToArray()) }
    finally { $source.Close() }
    $sha = (Get-FileHash $temporary -Algorithm SHA256).Hash.ToLower()
    Write-S3Object -BucketName $Bucket -Key "$keyRoot/$($required[$path])" -File $temporary -Region $Region -ServerSideEncryption AES256 -Metadata @{sha256=$sha} | Out-Null
    Write-Output "uploaded $($required[$path]) sha256=$sha bytes=$((Get-Item $temporary).Length)"
    Remove-Item $temporary -Force
}
Write-Output "EVIDENCE_OK stamp=$stamp prefix=s3://$Bucket/$keyRoot/"
