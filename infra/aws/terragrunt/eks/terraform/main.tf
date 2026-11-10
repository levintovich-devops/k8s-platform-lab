data "aws_vpc" "lab" {
  filter {
    name   = "tag:Name"
    values = [var.existing_vpc_name]
  }
}

data "aws_subnet" "private_a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.existing_vpc_name}-private-a"]
  }
}

data "aws_subnet" "private_b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.existing_vpc_name}-private-b"]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = data.aws_vpc.lab.id

  subnet_ids = [
    data.aws_subnet.private_a.id,
    data.aws_subnet.private_b.id,
  ]
  control_plane_subnet_ids = [
    data.aws_subnet.private_a.id,
    data.aws_subnet.private_b.id,
  ]

  endpoint_private_access      = true
  endpoint_public_access       = false

  enable_cluster_creator_admin_permissions = true
  create_kms_key                           = false
  encryption_config                        = null
  create_cloudwatch_log_group              = false
  enabled_log_types                        = []

  eks_managed_node_groups = {
    lab = {
      name           = "${var.cluster_name}-nodes"
      subnet_ids = [
        data.aws_subnet.private_a.id,
        data.aws_subnet.private_b.id,
      ]
      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_group_size.min_size
      max_size     = var.node_group_size.max_size
      desired_size = var.node_group_size.desired_size

      network_interfaces = [
        {
          device_index                = 0
          associate_public_ip_address = false
        }
      ]
    }
  }

  tags = {
    Environment = "lab"
    ManagedBy   = "Terraform"
  }
}
