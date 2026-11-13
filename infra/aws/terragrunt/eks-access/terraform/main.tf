data "terraform_remote_state" "bastion" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.bastion_state_key
    region = var.aws_region
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.eks_state_key
    region = var.aws_region
  }
}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "bastion_eks_describe" {
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = [data.terraform_remote_state.eks.outputs.cluster_arn]
  }
}

resource "aws_iam_role_policy" "bastion_eks_describe" {
  name   = "${data.terraform_remote_state.eks.outputs.cluster_name}-describe"
  role   = element(reverse(split("/", data.terraform_remote_state.bastion.outputs.iam_role_arn)), 0)
  policy = data.aws_iam_policy_document.bastion_eks_describe.json
}

resource "aws_eks_access_entry" "bastion" {
  cluster_name  = data.terraform_remote_state.eks.outputs.cluster_name
  principal_arn = data.terraform_remote_state.bastion.outputs.iam_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_cluster_admin" {
  cluster_name  = aws_eks_access_entry.bastion.cluster_name
  principal_arn = aws_eks_access_entry.bastion.principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_eks_api" {
  security_group_id            = data.terraform_remote_state.eks.outputs.cluster_security_group_id
  referenced_security_group_id = data.terraform_remote_state.bastion.outputs.security_group_id
  description                  = "Allow Bastion HTTPS access to the private EKS API"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
