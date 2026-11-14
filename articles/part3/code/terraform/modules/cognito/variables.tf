variable "pool_name" {
  type    = string
  default = "aegis-part3"
}

variable "region" {
  description = "Needed to build the issuer and JWKS URLs."
  type        = string
}

variable "users" {
  description = "user => group. null means no group (the outsider persona)."
  type        = map(string)
  default = {
    ana      = "platform-readers"
    eve      = "platform-operators"
    bob      = "platform-approvers"
    outsider = null
  }
}

variable "user_passwords" {
  description = "Permanent passwords, one per user. Only used to mint test tokens."
  type        = map(string)
  sensitive   = true
}
