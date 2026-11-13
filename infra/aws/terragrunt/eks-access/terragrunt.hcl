include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

locals {
  shared_backend_config = include.common.locals.shared_backend_config
}

terraform {
  source = "${get_terragrunt_dir()}/terraform"
}

remote_state {
  backend = "s3"
  config = {
    bucket       = local.shared_backend_config.bucket
    key          = "eks-access/terraform.tfstate"
    region       = local.shared_backend_config.region
    encrypt      = include.common.locals.temporary_state_encryption
    use_lockfile = local.shared_backend_config.use_lockfile
  }
}

dependencies {
  paths = ["../bastion", "../eks"]
}

inputs = {
  aws_region        = local.shared_backend_config.region
  state_bucket      = local.shared_backend_config.bucket
  bastion_state_key = "bastion/terraform.tfstate"
  eks_state_key     = "eks/terraform.tfstate"
}
