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
  version = "21.29.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id

  subnet_ids = [
    data.terraform_remote_state.vpc.outputs.private_subnet_a_id,
    data.terraform_remote_state.vpc.outputs.private_subnet_b_id,
  ]
  control_plane_subnet_ids = [
    data.terraform_remote_state.vpc.outputs.private_subnet_a_id,
    data.terraform_remote_state.vpc.outputs.private_subnet_b_id,
  ]

  endpoint_private_access      = true
  endpoint_public_access       = false

  enable_cluster_creator_admin_permissions = true
  authentication_mode = "API_AND_CONFIG_MAP"

  addons = {
    vpc-cni = {
      before_compute = true
    }
  }

  create_kms_key                           = false
  encryption_config                        = null
  create_cloudwatch_log_group              = false
  enabled_log_types                        = []

  tags = {
    Environment = "lab"
    ManagedBy   = "Terraform"
  }
}
