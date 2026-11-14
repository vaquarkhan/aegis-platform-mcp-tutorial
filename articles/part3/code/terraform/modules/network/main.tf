# Network: default VPC lookup and a security group with no inbound rules.
# The instance is reached only through Systems Manager, which is an outbound connection from the agent.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_security_group" "no_inbound" {
  name        = var.security_group_name
  description = "Aegis Part 3: SSM only, no inbound"
  vpc_id      = data.aws_vpc.default.id

  # No ingress block on purpose.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
