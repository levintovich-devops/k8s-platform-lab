data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.eks_state_key
    region = var.aws_region
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "21.29.0"

  name                               = "${var.cluster_name}-nodes"
  cluster_name                       = data.terraform_remote_state.eks.outputs.cluster_name
  kubernetes_version                 = data.terraform_remote_state.eks.outputs.cluster_version
  cluster_endpoint                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_auth_base64                = data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data
  cluster_service_cidr               = data.aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr
  cluster_primary_security_group_id = data.terraform_remote_state.eks.outputs.cluster_security_group_id

  subnet_ids = data.terraform_remote_state.eks.outputs.node_subnet_ids

  instance_types = [var.node_instance_type]
  capacity_type  = "ON_DEMAND"

  min_size     = var.node_group_size.min_size
  max_size     = var.node_group_size.max_size
  desired_size = var.node_group_size.desired_size

  iam_role_attach_cni_policy = true

  tags = {
    Environment = "lab"
    ManagedBy   = "Terraform"
  }
}
