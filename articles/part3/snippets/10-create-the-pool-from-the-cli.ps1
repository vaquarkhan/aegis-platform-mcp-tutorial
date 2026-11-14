$pool   = aws cognito-idp create-user-pool --pool-name aegis-part3 --admin-create-user-config AllowAdminCreateUserOnly=true `
            --policies 'PasswordPolicy={MinimumLength=16,RequireUppercase=true,RequireLowercase=true,RequireNumbers=true,RequireSymbols=false}' `
            --user-pool-tags project=aegis-part3 --query UserPool.Id --output text
$client = aws cognito-idp create-user-pool-client --user-pool-id $pool --client-name aegis-gateway --no-generate-secret `
            --explicit-auth-flows ALLOW_ADMIN_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH --query UserPoolClient.ClientId --output text
foreach ($g in 'platform-readers','platform-operators','platform-approvers') { aws cognito-idp create-group --user-pool-id $pool --group-name $g }
# per user: admin-create-user --message-action SUPPRESS, admin-set-user-password --permanent, admin-add-user-to-group
