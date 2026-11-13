variable "aws_region" {
  description = "AWS region containing the EKS cluster."
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket containing the EKS Terraform state."
  type        = string
}

variable "eks_state_key" {
  description = "S3 key containing the EKS Terraform state."
  type        = string
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster."
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type used by the EKS managed node group."
  type        = string
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
