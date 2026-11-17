# EKS Managed Node Group

This unit creates the EKS Managed Node Group and worker IAM role separately
from the control plane. It depends on NAT for private-subnet egress, the EKS
control-plane outputs, and `eks-access`. This ordering leaves the control plane
and Bastion troubleshooting access available if managed node creation fails.

The node group uses private subnets from the EKS state and the AWS EKS managed
node-group module v20.37.2's standard launch template, security groups, and
bootstrap.
The node instances receive both the AWS-managed primary cluster security group
and the module-created node security group; avoiding a custom network-interface
override preserves those attachments. AWS bootstraps the standard EKS add-ons;
the control-plane configuration does not separately manage VPC CNI, CoreDNS,
or kube-proxy. The node role explicitly attaches `AmazonEKS_CNI_Policy`
alongside the module's worker-node and container-registry permissions. The
node-group module also receives the cluster's service CIDR, which its generated
bootstrap configuration requires. EKS Managed Node Groups register their node
role for cluster authentication when created.

The unit has its own S3 state at `eks-node-group/terraform.tfstate`. If the
previous EKS state already owns node-group resources, migrate their ownership
to this unit before planning. See the migration requirements in the parent
Terragrunt README. Do not apply either state while ownership is split or
duplicated.
