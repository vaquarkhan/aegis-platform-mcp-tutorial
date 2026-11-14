# Create the Cognito identities for this exact run, mint one-hour ID tokens, and hand only
# issuer/client metadata plus short-lived tokens to the instance. Permanent passwords never leave
# the private runtime directory and no token is printed.
param([string]$RuntimeDirectory = (Join-Path $env:LOCALAPPDATA 'AegisPart3'))
. (Join-Path $PSScriptRoot 'common.ps1')
$RuntimeDirectory = Initialize-Part3Runtime $RuntimeDirectory
$state = Read-Part3State $RuntimeDirectory
if ($state.cognitoPoolId) { throw "state already has Cognito pool $($state.cognitoPoolId); tear down this run before creating another" }
$P = @('--profile',$state.profile,'--region',$state.region)
$poolName = "aegis-part3-$($state.runId)"

$pool = (Invoke-Aws (@('cognito-idp','create-user-pool','--pool-name',$poolName,'--policies','PasswordPolicy={MinimumLength=16,RequireUppercase=true,RequireLowercase=true,RequireNumbers=true,RequireSymbols=false}','--admin-create-user-config','AllowAdminCreateUserOnly=true','--user-pool-tags',"project=aegis-part3,run-id=$($state.runId)",'--query','UserPool.Id','--output','text') + $P)).Trim()
Assert-Value 'Cognito pool id' $pool '^[a-z0-9-]+_[A-Za-z0-9]+$'
$client = (Invoke-Aws (@('cognito-idp','create-user-pool-client','--user-pool-id',$pool,'--client-name','aegis-gateway','--no-generate-secret','--explicit-auth-flows','ALLOW_ADMIN_USER_PASSWORD_AUTH','ALLOW_REFRESH_TOKEN_AUTH','--id-token-validity','60','--token-validity-units','IdToken=minutes','--query','UserPoolClient.ClientId','--output','text') + $P)).Trim()
Assert-Value 'Cognito client id' $client '^[a-z0-9]+$'

$users = [ordered]@{ ana='platform-readers'; eve='platform-operators'; bob='platform-approvers'; outsider=$null }
foreach ($group in 'platform-readers','platform-operators','platform-approvers') {
    Invoke-Aws (@('cognito-idp','create-group','--user-pool-id',$pool,'--group-name',$group) + $P) | Out-Null
}
function New-Password { (-join ((1..18) | ForEach-Object { 'abcdefghjkmnpqrstuvwxyz'[(Get-Random -Maximum 23)] })) + 'A1' + (Get-Random -Minimum 10 -Maximum 99) }
$credentials = [ordered]@{}
$tokens = [ordered]@{}
foreach ($user in $users.Keys) {
    $password = New-Password
    Invoke-Aws (@('cognito-idp','admin-create-user','--user-pool-id',$pool,'--username',$user,'--message-action','SUPPRESS') + $P) | Out-Null
    Invoke-Aws (@('cognito-idp','admin-set-user-password','--user-pool-id',$pool,'--username',$user,'--password',$password,'--permanent') + $P) | Out-Null
    if ($users[$user]) { Invoke-Aws (@('cognito-idp','admin-add-user-to-group','--user-pool-id',$pool,'--username',$user,'--group-name',$users[$user]) + $P) | Out-Null }
    $credentials[$user] = $password
    $token = (Invoke-Aws (@('cognito-idp','admin-initiate-auth','--user-pool-id',$pool,'--client-id',$client,'--auth-flow','ADMIN_USER_PASSWORD_AUTH','--auth-parameters',"USERNAME=$user,PASSWORD=$password",'--query','AuthenticationResult.IdToken','--output','text') + $P)).Trim()
    if ($token.Split('.').Count -ne 3) { throw "Cognito did not return an ID token for $user" }
    $tokens[$user] = $token
}

$issuer = "https://cognito-idp.$($state.region).amazonaws.com/$pool"
$public = [ordered]@{ pool=$pool; client=$client; issuer=$issuer }
$privateFile = Join-Path $RuntimeDirectory 'cognito-passwords.json'
$publicFile = Join-Path $RuntimeDirectory 'cognito-public.json'
$tokensFile = Join-Path $RuntimeDirectory 'cognito-tokens.json'
[IO.File]::WriteAllText($privateFile, ($credentials | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($publicFile, ($public | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($tokensFile, ($tokens | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))

$runtimeKey = "$($state.baseKey)/runtime"
Invoke-Aws (@('s3','cp',$publicFile,"s3://$($state.bucket)/$runtimeKey/cognito.json",'--sse','AES256','--profile',$state.profile,'--region',$state.region,'--only-show-errors')) | Out-Null
Invoke-Aws (@('s3','cp',$tokensFile,"s3://$($state.bucket)/$runtimeKey/cognito-tokens.json",'--sse','AES256','--profile',$state.profile,'--region',$state.region,'--only-show-errors')) | Out-Null

$state | Add-Member NoteProperty cognitoPoolId $pool -Force
$state | Add-Member NoteProperty cognitoClientId $client -Force
$state | Add-Member NoteProperty cognitoIssuer $issuer -Force
Write-Part3State $RuntimeDirectory $state
Write-Output "COGNITO_OK pool=$pool client=$client users=4 tokens=short-lived runtime=s3://$($state.bucket)/$runtimeKey/"
