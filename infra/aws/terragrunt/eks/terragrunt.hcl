locals {
  aws_region = get_env("AWS_REGION", "eu-north-1")

  existing_vpc_name = get_env("EKS_EXISTING_VPC_NAME", "aws-lab")
  cluster_name      = get_env("EKS_CLUSTER_NAME", "aws-lab-eks")
  kubernetes_version = get_env("EKS_KUBERNETES_VERSION", "1.35")

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
    bucket       = "k8s-platform-lab-tfstate-eu-north-1"
    key          = "eks/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}

inputs = {
  aws_region                               = local.aws_region
  existing_vpc_name                        = local.existing_vpc_name
  cluster_name                             = local.cluster_name
  kubernetes_version                       = local.kubernetes_version
  node_instance_type                       = local.node_instance_type
  node_group_size = {
    min_size     = local.node_min_size
    max_size     = local.node_max_size
    desired_size = local.node_desired_size
  }
}
