
variable "aws_region" {
  description = "AWS region containing the existing VPC and EKS cluster."
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

variable "cluster_name" {
  description = "Name for the EKS cluster."
  type        = string
  default     = "aws-lab-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.35"
}
