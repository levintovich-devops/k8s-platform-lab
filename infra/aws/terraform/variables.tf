variable "aws_region" {
  description = "AWS region where the lab is deployed."
  type        = string
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