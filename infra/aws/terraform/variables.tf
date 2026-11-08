variable "aws_region" {
  description = "AWS region where the lab is deployed."
  type        = string
  default     = "eu-north-1"
}

variable "vpc_name" {
  description = "Name tag for the lab VPC."
  type        = string
  default     = "aws-lab"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the lab VPC."
  type        = string
  default     = "10.20.0.0/16"
}


variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for the first private subnet."
  type        = string
  default     = "10.20.11.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for the second private subnet."
  type        = string
  default     = "10.20.12.0/24"
}

variable "availability_zone_a" {
  description = "Availability Zone for the public and first private subnet."
  type        = string
  default     = "eu-north-1a"
}

variable "availability_zone_b" {
  description = "Availability Zone for the second private subnet."
  type        = string
  default     = "eu-north-1b"
}

variable "public_route_cidr" {
  description = "Destination CIDR for the public default route."
  type        = string
  default     = "0.0.0.0/0"
}


variable "ubuntu_ami_owner" {
  description = "AWS account ID of the official Ubuntu AMI publisher."
  type        = string
  default     = "099720109477"
}

variable "ubuntu_ami_name_pattern" {
  description = "Name pattern for Ubuntu Server AMI."
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "ubuntu_ami_virtualization_type" {
  description = "Virtualization type for the Ubuntu AMI."
  type        = string
  default     = "hvm"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the Bastion host."
  type        = string
  default     = "t3.micro"
}
