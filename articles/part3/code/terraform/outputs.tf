output "instance_id" {
  value = module.compute.instance_id
}

output "security_group_id" {
  value = module.network.security_group_id
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_app_client_id" {
  value = module.cognito.app_client_id
}

output "cognito_issuer" {
  value = module.cognito.issuer
}

output "cognito_jwks_uri" {
  value = module.cognito.jwks_uri
}

output "aegis_identity_block" {
  value = module.cognito.aegis_identity_block
}
