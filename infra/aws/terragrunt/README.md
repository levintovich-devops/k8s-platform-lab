# Temporary AWS infrastructure

This Terragrunt root contains only temporary components:

- `bastion`: SSM-managed EC2 instance and its IAM/security-group resources.
- `nat`: NAT Gateway, Elastic IP, and private-subnet default route.
- `eks`: private EKS control plane.
- `eks-access`: Bastion IAM, Kubernetes, and network access to the EKS API.
- `eks-node-group`: EKS Managed Node Group and its node IAM role.

The permanent VPC remains owned by Terraform in `../terraform`. It publishes
the VPC, subnet, Internet Gateway, and route-table identifiers as Terraform
outputs. The temporary components read those outputs from the permanent VPC
state; none creates or manages the VPC, subnets, Internet Gateway, or base
route tables themselves.

AWS region and S3 backend settings are centralized in
`infra/aws/terraform/backend-config.json`. The base Terraform provider and this
Terragrunt root read the same file.

## Dependency and state layout

`eks` depends on `nat`. `eks-access` depends on `bastion` and `eks`.
`eks-node-group` depends on `nat`, `eks`, and `eks-access`. Apply therefore
creates NAT and the independent Bastion before establishing access and then
creating worker nodes. Destroy reverses this order: workers first, access next,
and then the control plane, Bastion, and NAT. Bastion remains independently
deployable and has no dependency on EKS or its node group.

Each component has a separate S3 state:

| Component | State key |
| --- | --- |
| Permanent Terraform VPC | `infra/terraform.tfstate` |
| Bastion | `bastion/terraform.tfstate` |
| NAT | `networking/nat/terraform.tfstate` |
| EKS | `eks/terraform.tfstate` |
| EKS access | `eks-access/terraform.tfstate` |
| EKS node group | `eks-node-group/terraform.tfstate` |

The VPC's output values must be published to its existing state before
planning any temporary component. See the one-time setup below.

The all-components commands below run only the five directories in this
Terragrunt root. The permanent Terraform directory is not a Terragrunt unit and
is therefore excluded from every `run --all` command, especially destroy.

## Lifecycle

Run from this directory after configuring AWS credentials and verifying the
existing VPC. Review all plans before applying:

```bash
terragrunt run --all plan
terragrunt run --all apply
terragrunt run --all destroy
```

### Existing EKS state migration

The original EKS state may own the Managed Node Group as resources nested under
`module.eks.module.eks_managed_node_group["lab"]`. Before using the new
`eks-node-group` unit, inspect the existing EKS state and migrate every resource
owned by that module, including the node group, launch template, node IAM role
and policies, and any security-group resources, to the corresponding
`module.eks_managed_node_group` addresses in the new state. Preserve each
resource's state and identifiers; do not allow the old state to destroy the
resources or the new state to create duplicates. If the EKS state does not own
those resources, no node-group resource migration is needed.

The existing remote EKS state could not be inspected because read access to
its S3 state object was denied. The exact resource inventory and migration
mapping therefore remain to be confirmed. Back up both remote states and
serialize any required migration before applying. An all-unit plan does not
change state, but may show the old node group planned for removal from EKS and
creation in the new unit until ownership is moved. Do not apply that plan
before resolving the ownership difference. The permanent VPC and its state
are not part of this migration.

The new node-group unit reads the EKS state outputs, and `eks-access` reads the
EKS and Bastion outputs. Those upstream states must therefore contain their
outputs before planning dependent units.

The apply and destroy commands operate on Bastion, NAT, EKS, EKS access, and
the EKS node group only. To operate Bastion by itself, run Terragrunt from
`bastion/`.

The private EKS API is not reachable from the public internet. Confirm that
your administration path and required private-subnet egress are working before
creating the EKS node group.

## One-time VPC backend and outputs setup

The shared backend configuration preserves the existing permanent VPC backend
bucket and key. From `infra/aws/terraform`, initialize it with the shared
configuration:

```bash
terraform init -reconfigure -backend-config=backend-config.json
terraform plan
# Run only if the plan contains no resource actions.
terraform apply
terraform output
```

Confirm the plan proposes no managed-resource changes. The new outputs are
state metadata and do not create or replace VPC resources. Only after reviewing
the plan and confirming it has no resource actions, apply to record the outputs
in the existing VPC state and verify them.

Do not continue if the plan proposes any VPC resource changes. The temporary
components require read access to the permanent VPC state key as well as
read/write access to their own state keys.

## One-time Bastion state migration

The old Terraform backend is
`s3://k8s-platform-lab-tfstate-eu-north-1/infra/terraform.tfstate`. The local
checkout does not contain its live remote state, so inspect it before the
first plan. Do not apply a base Terraform plan that proposes Bastion destroys.

From `infra/aws/terraform`, using credentials that can read and lock the S3
state:

```bash
terraform state list
terraform state pull > /secure/outside-repository/infra-before-bastion-migration.tfstate
```

If `terraform state list` contains none of the Bastion managed resources, first
verify that no matching Bastion resources still exist in AWS; an empty state is
not proof that the infrastructure is absent. If resources exist but are not in
the old state, import them into the Bastion Terragrunt state before any plan or
apply. If Bastion addresses are present, keep the old state as the authoritative
backup, then:

1. Inspect each resource's import identifier using `terraform state show
   '<address>'`. Do not run plans or applies in either state during migration.
2. From `infra/aws/terragrunt/bastion`, initialize and import every Bastion
   object shown in the base state, in dependency order. Use the resource
   addresses in the old state; the managed-resource addresses are retained in
   the new module:

   ```bash
   terragrunt run -- init
   terragrunt run -- import aws_iam_role.bastion aws-lab-bastion-role
   terragrunt run -- import aws_iam_role_policy_attachment.bastion_ssm 'aws-lab-bastion-role/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore'
   terragrunt run -- import aws_iam_instance_profile.bastion aws-lab-bastion-profile
   terragrunt run -- import aws_security_group.bastion <security-group-id>
   terragrunt run -- import aws_vpc_security_group_egress_rule.bastion_https <security-group-rule-id>
   terragrunt run -- import aws_instance.bastion <instance-id>
   ```

   Skip any address not present in the old state. Use the exact IDs and role
   names returned by `terraform state show`; the sample role/profile names
   reflect the current configuration.
3. Verify that every imported object appears in
   `terragrunt run -- state list` and `terragrunt run -- state show`. Then, from
   `infra/aws/terraform`, remove only the Bastion objects that were successfully
   imported from the old state. If the state is partial, omit addresses that
   were not present or were not imported:

   ```bash
   terraform state rm \
     'aws_instance.bastion' \
     'aws_security_group.bastion' \
     'aws_vpc_security_group_egress_rule.bastion_https' \
     'aws_iam_role.bastion' \
     'aws_iam_role_policy_attachment.bastion_ssm' \
     'aws_iam_instance_profile.bastion'
   ```
4. Run and review a plan in the base Terraform directory and in
   `terragrunt/bastion`. The base plan must leave all VPC resources unchanged;
   the Bastion plan must not propose replacing imported resources.

State import and state removal change Terraform ownership records only; they
must not be replaced by destroy/apply. If an import fails, stop and resolve it
before removing the corresponding address from the old state.

No commands in this guide automatically apply or destroy AWS resources.
