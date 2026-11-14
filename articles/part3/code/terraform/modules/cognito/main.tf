# Cognito: the identity provider whose ID tokens the gateway verifies.
# Group names are the ones aegis.yaml already uses. Cognito places them in the cognito:groups claim.

resource "aws_cognito_user_pool" "aegis" {
  name = var.pool_name

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 16
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }
}

resource "aws_cognito_user_pool_client" "gateway" {
  name            = "aegis-gateway"
  user_pool_id    = aws_cognito_user_pool.aegis.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  id_token_validity = 60
  token_validity_units {
    id_token = "minutes"
  }
}

resource "aws_cognito_user_group" "groups" {
  for_each     = toset(distinct([for g in values(var.users) : g if g != null]))
  name         = each.value
  user_pool_id = aws_cognito_user_pool.aegis.id
}

resource "aws_cognito_user" "users" {
  for_each       = var.users
  user_pool_id   = aws_cognito_user_pool.aegis.id
  username       = each.key
  password       = var.user_passwords[each.key]
  message_action = "SUPPRESS"
  enabled        = true
}

resource "aws_cognito_user_in_group" "membership" {
  for_each     = { for u, g in var.users : u => g if g != null }
  user_pool_id = aws_cognito_user_pool.aegis.id
  group_name   = aws_cognito_user_group.groups[each.value].name
  username     = aws_cognito_user.users[each.key].username
}
