variable "aws_region" {
  description = "AWS region containing the Bastion and EKS cluster."
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket containing the Bastion and EKS Terraform states."
  type        = string
}

variable "bastion_state_key" {
  description = "S3 key containing the Bastion Terraform state."
  type        = string
}

variable "eks_state_key" {
  description = "S3 key containing the EKS Terraform state."
  type        = string
}
