variable "name" {
  type    = string
  default = "aegis-part3"
}

variable "instance_type" {
  description = "What the article ran. Smaller sizes were not tried."
  type        = string
  default     = "t3.xlarge"
}

variable "root_volume_gb" {
  type    = number
  default = 80
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}
