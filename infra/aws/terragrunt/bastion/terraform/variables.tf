variable "aws_region" {
  description = "AWS region containing the existing VPC."
  type        = string
}

variable "existing_vpc_name" {
  description = "Name tag of the existing VPC and public subnet."
  type        = string
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the Bastion host."
  type        = string
}

variable "ubuntu_ami_owner" {
  description = "AWS account ID of the official Ubuntu AMI publisher."
  type        = string
}

variable "ubuntu_ami_name_pattern" {
  description = "Name pattern for Ubuntu Server AMI."
  type        = string
}

variable "ubuntu_ami_virtualization_type" {
  description = "Virtualization type for Ubuntu Server AMI."
  type        = string
}
