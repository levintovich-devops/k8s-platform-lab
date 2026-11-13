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
    key          = "networking/nat/terraform.tfstate"
    region       = local.shared_backend_config.region
    encrypt      = include.common.locals.temporary_state_encryption
    use_lockfile = local.shared_backend_config.use_lockfile
  }
}

inputs = {
  aws_region       = local.shared_backend_config.region
  vpc_state_bucket = local.shared_backend_config.bucket
  vpc_state_key    = local.shared_backend_config.key
}
