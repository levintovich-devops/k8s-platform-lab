variable "aws_region" {
  description = "AWS region containing the existing VPC."
  type        = string
}

variable "vpc_state_bucket" {
  description = "S3 bucket containing the permanent VPC Terraform state."
  type        = string
}

variable "vpc_state_key" {
  description = "S3 key containing the permanent VPC Terraform state."
  type        = string
}
