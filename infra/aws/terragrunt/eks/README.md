
# AWS EKS lab

This Terragrunt deployment creates a private EKS cluster with one
EKS Managed Node Group containing two t3.small EC2 worker nodes.

It reuses the existing VPC and private subnets without modifying
their Terraform configuration or state.

## Architecture

- AWS region: eu-north-1
- VPC: aws-lab (existing)
- Private subnets: aws-lab-private-a, aws-lab-private-b
- EKS cluster: aws-lab-eks
- Kubernetes version: 1.35
- EKS API endpoint: private only
- Managed Node Groups: 1
- Worker Nodes: 2 x t3.small, On-Demand
- Node scaling: min=2, desired=2, max=2
- Public subnet: existing Bastion component and NAT Gateway

Both private subnets are supplied to the EKS control plane and
Managed Node Group.

A single Managed Node Group spanning two Availability Zones does
not strictly guarantee one worker node per AZ.

The EKS control plane is managed by AWS. Its network interfaces
are placed in the selected private subnets.

## Existing infrastructure

Terraform discovers the existing VPC and subnets using AWS
data sources and Name tags.

This deployment does not create or modify:

- VPCs or subnets
- Route tables or Internet Gateways
- NAT Gateway resources (managed by the separate `nat` component)
- Bastion resources (managed by the separate `bastion` component)
- The permanent VPC Terraform state

EKS-specific IAM roles, security groups, cluster resources,
and managed worker nodes are created by the EKS module.

## Private networking prerequisites

The `nat` Terragrunt component installs a default route on the existing shared
private route table. The EKS Terragrunt unit depends on NAT so `run --all apply`
creates the route and gateway before EKS.

Potential requirements include:

- ECR API interface endpoint
- ECR Docker registry interface endpoint
- S3 gateway endpoint
- EC2 API interface endpoint
- STS and other service endpoints when required

The private EKS Kubernetes API endpoint must be reachable
from the worker nodes and the administration host.

Verify DNS, security groups, endpoint policies, and routes.

Do not deploy until the NAT route and required connectivity are confirmed.

## Terraform and Terragrunt

Terraform: 1.13.5
AWS Provider: 6.71.0
Terragrunt: 0.99.4

The existing S3 state bucket is reused.

EKS state:
s3://k8s-platform-lab-tfstate-eu-north-1/eks/terraform.tfstate

Existing infrastructure state:
s3://k8s-platform-lab-tfstate-eu-north-1/infra/terraform.tfstate

These are separate Terraform states.

## Configuration

Deployment settings are supplied through terragrunt.hcl.

Default values:

- AWS_REGION=eu-north-1
- EKS_EXISTING_VPC_NAME=aws-lab
- EKS_CLUSTER_NAME=aws-lab-eks
- EKS_KUBERNETES_VERSION=1.35
- EKS_NODE_INSTANCE_TYPE=t3.small
- EKS_NODE_MIN_SIZE=2
- EKS_NODE_MAX_SIZE=2
- EKS_NODE_DESIRED_SIZE=2

Environment variables may override these defaults.

## Validation

From the EKS Terragrunt directory:

```bash
terraform -chdir=terraform fmt -check -recursive
terragrunt hcl fmt --check
terragrunt init
terragrunt validate
terragrunt plan
```

Review the plan before creating resources.

Initialization may create local files and use the S3 backend
lock mechanism. Plan does not intentionally deploy resources.

## Deployment

From `infra/aws/terragrunt`, after the networking prerequisites and complete
all-components plan are approved:

```bash
terragrunt run --all apply
```

## Kubernetes access

The Kubernetes API endpoint is private-only.

Run the following commands from an administration host with network
connectivity to the private endpoint and appropriate AWS IAM/EKS permissions.
The SSM-managed Bastion is a separate Terragrunt component and is not an EKS
dependency.

```bash
aws eks update-kubeconfig \
  --region eu-north-1 \
  --name aws-lab-eks

kubectl get nodes -o wide
```

Verify that both worker nodes are Ready.

## Destroy

Delete workloads that provision AWS infrastructure before
destroying the EKS cluster.

```bash
terragrunt run --all destroy
```

Review the destroy plan.

Verify that the EKS cluster, Managed Node Group, EC2 worker
instances, and associated EBS volumes have been removed.

The all-components destroy removes EKS before NAT and also removes the Bastion
component. It never includes the permanent VPC. Do not delete the S3 state
bucket or shared Terraform infrastructure.

## Cost management

The EKS control plane incurs an hourly charge even when idle.

Additional costs include:

- Two t3.small EC2 instances
- Two EC2 root EBS volumes
- Data transfer and optional workload resources
- Any separately provisioned networking endpoints

The separate NAT component incurs additional costs for the NAT Gateway,
Elastic IP, and processed data. No load balancer, customer-managed KMS key, or
control-plane CloudWatch log group is provisioned by the EKS component.

Destroy the temporary EKS deployment promptly after testing.
