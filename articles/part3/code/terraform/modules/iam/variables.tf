variable "role_name" {
  type    = string
  default = "aegis-part3-ec2"
}

variable "bucket_name" {
  description = "Existing bucket that holds the bundle and receives the evidence."
  type        = string
}

variable "s3_prefix" {
  type    = string
  default = "part3"
}
