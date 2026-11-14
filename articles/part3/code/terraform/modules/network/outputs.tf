output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "subnet_id" {
  description = "First default-for-AZ subnet in the default VPC."
  value       = data.aws_subnets.default.ids[0]
}

output "security_group_id" {
  value = aws_security_group.no_inbound.id
}
