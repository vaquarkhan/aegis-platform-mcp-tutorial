# Upload one clean source bundle and create the exact EC2 role/profile for this run.
param(
    [Parameter(Mandatory)][string]$Bucket,
    [string]$Profile = 'default',
    [string]$Region = 'us-east-1',
    [string]$Prefix = 'part3',
    [string]$Bundle = (Join-Path $PSScriptRoot 'aegis-part3-src.zip'),
    [string]$RuntimeDirectory = (Join-Path $env:LOCALAPPDATA 'AegisPart3')
)
. (Join-Path $PSScriptRoot 'common.ps1')
$RuntimeDirectory = Initialize-Part3Runtime $RuntimeDirectory
if (-not (Test-Path $Bundle)) { throw "missing $Bundle; run bundle.py first" }

$identity = (Invoke-Aws @('sts','get-caller-identity','--profile',$Profile,'--region',$Region,'--output','json')) -join "`n" | ConvertFrom-Json
$runId = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss') + '-' + [guid]::NewGuid().ToString('n').Substring(0, 8)
$roleName = "aegis-part3-$runId"
$baseKey = "$Prefix/runs/$runId"
$bundleKey = "$baseKey/aegis-part3-src.zip"
$sha = (Get-FileHash $Bundle -Algorithm SHA256).Hash.ToLower()

Invoke-Aws @('s3api','head-bucket','--bucket',$Bucket,'--expected-bucket-owner',$identity.Account,'--profile',$Profile,'--region',$Region) | Out-Null
Invoke-Aws @('s3','cp',$Bundle,"s3://$Bucket/$bundleKey",'--sse','AES256','--metadata',"sha256=$sha",'--profile',$Profile,'--region',$Region,'--only-show-errors') | Out-Null
$head = (Invoke-Aws @('s3api','head-object','--bucket',$Bucket,'--key',$bundleKey,'--expected-bucket-owner',$identity.Account,'--profile',$Profile,'--region',$Region,'--output','json')) -join "`n" | ConvertFrom-Json
if ($head.Metadata.sha256 -ne $sha -or $head.ServerSideEncryption -ne 'AES256') { throw 'uploaded bundle metadata or encryption did not match' }

$trustFile = Join-Path $RuntimeDirectory 'trust.json'
$trust = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
[IO.File]::WriteAllText($trustFile, $trust)
Invoke-Aws @('iam','create-role','--role-name',$roleName,'--assume-role-policy-document',"file://$trustFile",'--tags',"Key=project,Value=aegis-part3","Key=run-id,Value=$runId",'--profile',$Profile,'--region',$Region) | Out-Null
Invoke-Aws @('iam','attach-role-policy','--role-name',$roleName,'--policy-arn','arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore','--profile',$Profile,'--region',$Region) | Out-Null

$policyFile = Join-Path $RuntimeDirectory 'instance-s3-policy.json'
$policy = @"
{"Version":"2012-10-17","Statement":[
 {"Sid":"ReadBundle","Effect":"Allow","Action":"s3:GetObject","Resource":"arn:aws:s3:::$Bucket/$bundleKey"},
 {"Sid":"ReadRuntime","Effect":"Allow","Action":"s3:GetObject","Resource":"arn:aws:s3:::$Bucket/$baseKey/runtime/*"},
 {"Sid":"WriteEvidence","Effect":"Allow","Action":"s3:PutObject","Resource":"arn:aws:s3:::$Bucket/$baseKey/evidence/*"}
]}
"@
[IO.File]::WriteAllText($policyFile, $policy)
Invoke-Aws @('iam','put-role-policy','--role-name',$roleName,'--policy-name','aegis-part3-s3','--policy-document',"file://$policyFile",'--profile',$Profile,'--region',$Region) | Out-Null
Invoke-Aws @('iam','create-instance-profile','--instance-profile-name',$roleName,'--tags',"Key=project,Value=aegis-part3","Key=run-id,Value=$runId",'--profile',$Profile,'--region',$Region) | Out-Null
Invoke-Aws @('iam','add-role-to-instance-profile','--instance-profile-name',$roleName,'--role-name',$roleName,'--profile',$Profile,'--region',$Region) | Out-Null
Start-Sleep -Seconds 15

$state = [ordered]@{
    runId = $runId; account = $identity.Account; profile = $Profile; region = $Region
    bucket = $Bucket; prefix = $Prefix; baseKey = $baseKey; bundleKey = $bundleKey; bundleSha256 = $sha
    roleName = $roleName; instanceProfileName = $roleName
}
Write-Part3State $RuntimeDirectory $state
Write-Output "STEP1_OK runId=$runId bundle=s3://$Bucket/$bundleKey sha256=$sha role=$roleName"
