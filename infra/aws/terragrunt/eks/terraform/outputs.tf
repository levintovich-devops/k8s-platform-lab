output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster."
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for kubeconfig."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster."
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_security_group_id" {
  description = "Primary security group ID created for the EKS cluster."
  value       = module.eks.cluster_primary_security_group_id
}

output "vpc_id" {
  description = "ID of the reused VPC."
  value       = data.terraform_remote_state.vpc.outputs.vpc_id
}

output "control_plane_subnet_ids" {
  description = "IDs of the reused private subnets hosting EKS control-plane interfaces."
  value = [
    data.terraform_remote_state.vpc.outputs.private_subnet_a_id,
    data.terraform_remote_state.vpc.outputs.private_subnet_b_id,
  ]
}

output "node_subnet_ids" {
  description = "IDs of the existing private subnets where managed worker nodes run."
  value = [
    data.terraform_remote_state.vpc.outputs.private_subnet_a_id,
    data.terraform_remote_state.vpc.outputs.private_subnet_b_id,
  ]
}

output "update_kubeconfig_command" {
  description = "AWS CLI command to add this cluster to the local kubeconfig."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
