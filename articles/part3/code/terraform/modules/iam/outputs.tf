output "instance_profile_name" {
  value = aws_iam_instance_profile.instance.name
}

output "role_arn" {
  value = aws_iam_role.instance.arn
}
