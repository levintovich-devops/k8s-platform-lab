locals {
  bastion_config = read_terragrunt_config("config.hcl").locals
}

terraform {
  source = "${get_terragrunt_dir()}/terraform"
}

remote_state {
  backend = "s3"
  config = {
    bucket       = "k8s-platform-lab-tfstate-eu-north-1"
    key          = "bastion/terraform.tfstate"
    region       = local.bastion_config.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

inputs = local.bastion_config
