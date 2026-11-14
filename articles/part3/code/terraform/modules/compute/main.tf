# Compute: one Windows Server 2022 instance. Four engines plus two gateways want about 16 GB, so t3.xlarge.
# IMDSv2 required. 80 GB gp3 root. Nothing to bootstrap; install.ps1 is sent over SSM after apply.

data "aws_ssm_parameter" "windows_2022" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

resource "aws_instance" "aegis" {
  ami                         = data.aws_ssm_parameter.windows_2022.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true # outbound only; the security group has no inbound rules

  root_block_device {
    volume_size           = var.root_volume_gb
    volume_type           = "gp3"
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = { Name = var.name }
}
