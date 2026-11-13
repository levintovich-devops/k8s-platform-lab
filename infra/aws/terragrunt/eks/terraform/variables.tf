
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

variable "node_instance_type" {
  description = "EC2 instance type used by the EKS managed node group."
  type        = string
  default     = "t3.small"
}

variable "node_group_size" {
  description = "Minimum, maximum, and desired number of EKS worker nodes."

  type = object({
    min_size     = number
    max_size     = number
    desired_size = number
  })

  validation {
    condition = (
      var.node_group_size.min_size >= 0 &&
      var.node_group_size.max_size >= var.node_group_size.min_size &&
      var.node_group_size.desired_size >= var.node_group_size.min_size &&
      var.node_group_size.desired_size <= var.node_group_size.max_size
    )

    error_message = "Node group sizes must satisfy 0 <= min_size <= desired_size <= max_size."
  }
}
