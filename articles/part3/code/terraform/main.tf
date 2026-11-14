# Part 3 infrastructure, composed from four modules:
#   modules/network   default VPC lookup, security group with no inbound rules
#   modules/iam       instance role: SSM core + scoped S3 read (bundle) and write (evidence)
#   modules/compute   Windows Server 2022 t3.xlarge, IMDSv2, 80 GB gp3, SSM only
#   modules/cognito   user pool, app client, three groups, four users
#
#   terraform init
#   terraform apply -var="bucket_name=YOUR-BUCKET" -var-file="passwords.auto.tfvars"
#   terraform output -raw instance_id > ..\cli\instance-id.txt
#   terraform output aegis_identity_block
#   terraform destroy
#
# It does not create the S3 bucket, install Java, or build Aegis. remote/install.ps1 does that over SSM.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
  default_tags {
    tags = { project = "aegis-part3" }
  }
}

module "network" {
  source = "./modules/network"
}

module "iam" {
  source      = "./modules/iam"
  bucket_name = var.bucket_name
  s3_prefix   = var.s3_prefix
}

module "compute" {
  source                = "./modules/compute"
  instance_type         = var.instance_type
  subnet_id             = module.network.subnet_id
  security_group_id     = module.network.security_group_id
  instance_profile_name = module.iam.instance_profile_name
}

module "cognito" {
  source         = "./modules/cognito"
  region         = var.region
  user_passwords = var.user_passwords
}
