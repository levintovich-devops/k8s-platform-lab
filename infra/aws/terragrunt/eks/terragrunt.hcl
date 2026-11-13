include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

locals {
  shared_backend_config = include.common.locals.shared_backend_config
  cluster_name          = get_env("EKS_CLUSTER_NAME", "aws-lab-eks")
  kubernetes_version    = get_env("EKS_KUBERNETES_VERSION", "1.35")

  node_instance_type = get_env("EKS_NODE_INSTANCE_TYPE", "t3.small")
  node_min_size      = tonumber(get_env("EKS_NODE_MIN_SIZE", "2"))
  node_max_size      = tonumber(get_env("EKS_NODE_MAX_SIZE", "2"))
  node_desired_size  = tonumber(get_env("EKS_NODE_DESIRED_SIZE", "2"))
}

terraform {
  source = "${get_terragrunt_dir()}/terraform"
}

remote_state {
  backend = "s3"
  config = {
    bucket       = local.shared_backend_config.bucket
    key          = "eks/terraform.tfstate"
    region       = local.shared_backend_config.region
    encrypt      = include.common.locals.temporary_state_encryption
    use_lockfile = local.shared_backend_config.use_lockfile
  }
}

dependencies {
  paths = ["../nat"]
}

inputs = {
  aws_region         = local.shared_backend_config.region
  vpc_state_bucket   = local.shared_backend_config.bucket
  vpc_state_key      = local.shared_backend_config.key
  cluster_name       = local.cluster_name
  kubernetes_version = local.kubernetes_version
  node_instance_type = local.node_instance_type
  node_group_size = {
    min_size     = local.node_min_size
    max_size     = local.node_max_size
    desired_size = local.node_desired_size
  }
}
