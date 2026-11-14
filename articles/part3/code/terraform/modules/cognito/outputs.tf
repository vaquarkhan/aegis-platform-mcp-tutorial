output "user_pool_id" {
  value = aws_cognito_user_pool.aegis.id
}

output "app_client_id" {
  description = "The JWT audience the gateway checks (aud claim of the ID token)."
  value       = aws_cognito_user_pool_client.gateway.id
}

output "issuer" {
  value = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.aegis.id}"
}

output "jwks_uri" {
  value = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.aegis.id}/.well-known/jwks.json"
}

output "aegis_identity_block" {
  description = "Paste under host: in aegis-aws.yaml"
  value       = <<-EOT
    identity:
      type: jwt
      jwt:
        issuer: https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.aegis.id}
        audience: ${aws_cognito_user_pool_client.gateway.id}
        algorithms: [RS256]
        jwksUri: https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.aegis.id}/.well-known/jwks.json
        groupsClaim: cognito:groups
        subjectClaim: cognito:username
  EOT
}
