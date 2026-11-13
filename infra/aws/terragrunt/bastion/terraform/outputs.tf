output "instance_id" {
  description = "ID of the Bastion EC2 instance."
  value       = aws_instance.bastion.id
}

output "public_ip" {
  description = "Public IPv4 address assigned to the Bastion instance."
  value       = aws_instance.bastion.public_ip
}

output "private_ip" {
  description = "Private IPv4 address assigned to the Bastion instance."
  value       = aws_instance.bastion.private_ip
}

output "subnet_id" {
  description = "ID of the existing public subnet hosting the Bastion."
  value       = data.terraform_remote_state.vpc.outputs.public_subnet_id
}

output "security_group_id" {
  description = "ID of the Bastion security group."
  value       = aws_security_group.bastion.id
}

output "iam_role_arn" {
  description = "ARN of the Bastion IAM role."
  value       = aws_iam_role.bastion.arn
}

output "instance_profile_name" {
  description = "Name of the Bastion EC2 instance profile."
  value       = aws_iam_instance_profile.bastion.name
}

output "ssm_session_command" {
  description = "AWS CLI command to open an SSM session to the Bastion."
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.aws_region}"
}
