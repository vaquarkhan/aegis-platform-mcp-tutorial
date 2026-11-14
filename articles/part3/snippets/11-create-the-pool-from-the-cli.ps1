aws cognito-idp admin-initiate-auth --user-pool-id $pool --client-id $client --auth-flow ADMIN_USER_PASSWORD_AUTH `
  --auth-parameters "USERNAME=ana,PASSWORD=..." --query AuthenticationResult.IdToken --output text
