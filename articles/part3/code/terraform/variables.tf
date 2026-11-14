variable "region" {
  description = "AWS region. The Cognito issuer and JWKS URLs embed it."
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS CLI profile. null uses the default credential chain."
  type        = string
  default     = null
}

variable "bucket_name" {
  description = "Existing S3 bucket for the source bundle and the evidence. Not created here."
  type        = string
}

variable "s3_prefix" {
  description = "Prefix the instance may read (bundle) and write (evidence/)."
  type        = string
  default     = "part3"
}

variable "instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "user_passwords" {
  description = "Permanent passwords for ana, eve, bob, outsider (16+ chars, upper, lower, digit)."
  type        = map(string)
  sensitive   = true
  validation {
    condition     = alltrue([for u in ["ana", "eve", "bob", "outsider"] : contains(keys(var.user_passwords), u)])
    error_message = "user_passwords must have keys ana, eve, bob, outsider."
  }
}
