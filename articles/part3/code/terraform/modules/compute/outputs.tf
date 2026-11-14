output "instance_id" {
  description = "Write to cli/instance-id.txt; ssm.ps1 reads it."
  value       = aws_instance.aegis.id
}

output "private_ip" {
  value = aws_instance.aegis.private_ip
}
