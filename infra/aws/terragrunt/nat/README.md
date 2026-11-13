# NAT Gateway egress

This Terragrunt component adds one NAT Gateway and Elastic IP to the existing
`aws-lab` public subnet, then adds an IPv4 default route to the existing shared
private route table. It does not create or manage a VPC, subnet, Internet
Gateway, route table, or subnet association.

## Ownership and state

- Terraform reads the existing VPC ID, VPC name, subnet IDs, Internet Gateway
  ID, and route-table IDs from the permanent VPC Terraform state's outputs.
- It reads the current public/private route-table routes by the subnet
  associations using the IDs from those outputs. The base configuration
  associates both private subnets with one shared private route table, and
  associates the public subnet with a route table that routes `0.0.0.0/0` to
  the Internet Gateway.
- This component owns only its Elastic IP, NAT Gateway, and
  `0.0.0.0/0` route in that shared private route table. Preconditions reject a
  private subnet route-table mismatch, a public subnet without its existing
  Internet Gateway route, or a pre-existing private IPv4 default route.
- Its independent S3 state is
  `s3://k8s-platform-lab-tfstate-eu-north-1/networking/nat/terraform.tfstate`.
  The existing bucket must already exist, and the Terraform identity must be
  allowed to read/write this key and its lock file.
- AWS region and state bucket settings come from
  `infra/aws/terraform/backend-config.json`; the VPC name and infrastructure
  identifiers come from the VPC state outputs.
- Publish the VPC outputs to the existing state before planning NAT. Follow
  the one-time setup in `../README.md`.

## Safe egress switching

Do not operate NAT and a future VPC Endpoints egress component at the same
time. Their Terraform states have separate locks and cannot enforce mutual
exclusion; serialize changes operationally and review each plan.

To switch from NAT to VPC Endpoints after that component is implemented:

1. Stop other networking changes. If an EKS node group is active, remove it
   safely first or ensure the alternate egress is ready before interrupting
   its required connectivity.
2. From this directory, review the NAT component's destroy plan and confirm it
   contains only this component's `aws_route`, NAT Gateway, and Elastic IP.
3. Run `terragrunt destroy` here and verify the NAT default route, NAT Gateway,
   and Elastic IP are gone. This component's destroy must leave the existing
   route table and all base VPC resources intact.
4. Only after NAT is removed, apply the VPC Endpoints component from its own
   directory and state, after reviewing its plan.
5. To switch back, destroy the endpoints component and verify its resources
   and route-table associations are gone before applying this NAT component.

For a temporary NAT connectivity test, first confirm that the EKS control
plane and any failed/prior managed node group are not being changed by this
component. Then apply NAT, verify the private route and connectivity, and
create the node group separately from the EKS component only after reviewing
its plan. NAT egress does not by itself guarantee node registration; private
API reachability, DNS, security groups/network ACLs, node IAM/authentication,
and bootstrap must also be correct.

## Validation and lifecycle

Run commands from this directory. They are documented for the operator and
have not been run as part of this change:

```powershell
terraform -chdir=terraform fmt -check -recursive
terragrunt hcl fmt --check
terragrunt init
terragrunt validate
terragrunt plan
```

After reviewing the plan and confirming the preconditions and ownership, apply
only this component:

```powershell
terragrunt apply
```

To remove only NAT-owned resources, review the destroy plan and run:

```powershell
terragrunt destroy
```

The route is removed before its NAT Gateway; the NAT Gateway is removed before
its Elastic IP. The existing private route table, VPC, subnets, Internet
Gateway, Bastion, and EKS cluster are data sources or belong to other Terraform
states and are not destroyed by this component. Do not use this destroy
procedure while NAT is still needed for active workloads.

## Cost and availability

The NAT Gateway and its Elastic IP incur ongoing hourly charges; processed data
and cross-AZ traffic can add charges. One NAT Gateway in the existing public
subnet minimizes fixed NAT cost but is a single-AZ dependency for private
subnets in both Availability Zones and can cause cross-AZ data transfer costs.
This lab component intentionally creates only one NAT Gateway. Remove it when
the test is complete and no workloads depend on it.
