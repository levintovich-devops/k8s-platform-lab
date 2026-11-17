data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.vpc_state_bucket
    key    = var.vpc_state_key
    region = var.aws_region
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name       = var.cluster_name
  cluster_version    = var.kubernetes_version
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id

  subnet_ids = [
    data.terraform_remote_state.vpc.outputs.private_subnet_a_id,
    data.terraform_remote_state.vpc.outputs.private_subnet_b_id,
  ]
  control_plane_subnet_ids = [
    data.terraform_remote_state.vpc.outputs.private_subnet_a_id,
    data.terraform_remote_state.vpc.outputs.private_subnet_b_id,
  ]

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  enable_cluster_creator_admin_permissions = true
  authentication_mode                    = "API_AND_CONFIG_MAP"
  bootstrap_self_managed_addons           = true

  create_kms_key             = false
  cluster_encryption_config  = {}
  create_cloudwatch_log_group = false
  cluster_enabled_log_types  = []

  tags = {
    Environment = "lab"
    ManagedBy   = "Terraform"
  }
}
