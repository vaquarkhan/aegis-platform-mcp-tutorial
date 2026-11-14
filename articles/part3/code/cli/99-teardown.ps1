# Delete only the exact resource ids recorded for this run. Evidence remains in S3.
param(
    [switch]$Force,
    [string]$RuntimeDirectory = (Join-Path $env:LOCALAPPDATA 'AegisPart3')
)
. (Join-Path $PSScriptRoot 'common.ps1')
$RuntimeDirectory = Initialize-Part3Runtime $RuntimeDirectory
$state = Read-Part3State $RuntimeDirectory
$P = @('--profile',$state.profile,'--region',$state.region)
$plan = @(
    "instance: $($state.instanceId)",
    "security group: $($state.securityGroupId)",
    "Cognito pool: $($state.cognitoPoolId)",
    "IAM role/profile: $($state.roleName)",
    "S3 runtime and bundle: s3://$($state.bucket)/$($state.baseKey)/",
    "S3 evidence retained: s3://$($state.bucket)/$($state.baseKey)/evidence/"
)
$plan | ForEach-Object { Write-Output $_ }
if (-not $Force) { throw 'review the plan, then rerun with -Force' }

if ($state.instanceId) {
    Invoke-Aws (@('ec2','terminate-instances','--instance-ids',$state.instanceId) + $P) | Out-Null
    Invoke-Aws (@('ec2','wait','instance-terminated','--instance-ids',$state.instanceId) + $P) | Out-Null
}
if ($state.securityGroupId) {
    for ($attempt=1; $attempt -le 8; $attempt++) {
        try { Invoke-Aws (@('ec2','delete-security-group','--group-id',$state.securityGroupId) + $P) | Out-Null; break }
        catch { if ($attempt -eq 8) { throw }; Start-Sleep -Seconds 15 }
    }
}
if ($state.cognitoPoolId) { Invoke-Aws (@('cognito-idp','delete-user-pool','--user-pool-id',$state.cognitoPoolId) + $P) | Out-Null }
Invoke-Aws (@('iam','remove-role-from-instance-profile','--instance-profile-name',$state.instanceProfileName,'--role-name',$state.roleName) + $P) | Out-Null
Invoke-Aws (@('iam','delete-instance-profile','--instance-profile-name',$state.instanceProfileName) + $P) | Out-Null
Invoke-Aws (@('iam','detach-role-policy','--role-name',$state.roleName,'--policy-arn','arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore') + $P) | Out-Null
Invoke-Aws (@('iam','delete-role-policy','--role-name',$state.roleName,'--policy-name','aegis-part3-s3') + $P) | Out-Null
Invoke-Aws (@('iam','delete-role','--role-name',$state.roleName) + $P) | Out-Null
Invoke-Aws (@('s3','rm',"s3://$($state.bucket)/$($state.bundleKey)",'--only-show-errors') + $P) | Out-Null
Invoke-Aws (@('s3','rm',"s3://$($state.bucket)/$($state.baseKey)/runtime/",'--recursive','--only-show-errors') + $P) | Out-Null

# Exact absence checks. A successful describe for a terminated instance is expected; its state must be terminated.
$instanceState = (Invoke-Aws (@('ec2','describe-instances','--instance-ids',$state.instanceId,'--query','Reservations[0].Instances[0].State.Name','--output','text') + $P)).Trim()
if ($instanceState -ne 'terminated') { throw "instance is $instanceState, not terminated" }
$remaining = (Invoke-Aws (@('s3api','list-objects-v2','--bucket',$state.bucket,'--prefix',"$($state.baseKey)/runtime/",'--query','length(Contents)','--output','text') + $P)).Trim()
if ($remaining -notin @('0','None')) { throw "$remaining runtime objects remain" }

Get-ChildItem $RuntimeDirectory -File | Where-Object { $_.Name -notlike 'evidence-*' } | Remove-Item -Force
Write-Output "TEARDOWN_OK runId=$($state.runId) evidence retained at s3://$($state.bucket)/$($state.baseKey)/evidence/"
