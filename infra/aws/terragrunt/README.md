# Temporary AWS infrastructure

This Terragrunt root contains only temporary components:

- `bastion`: SSM-managed EC2 instance and its IAM/security-group resources.
- `nat`: NAT Gateway, Elastic IP, and private-subnet default route.
- `eks`: private EKS cluster and managed node group.

The permanent VPC remains owned by Terraform in `../terraform`. All three
components discover and use its VPC/subnets by `Name` tags; none creates or
manages the VPC, subnets, Internet Gateway, or route tables themselves.

## Dependency and state layout

`eks` depends on `nat`, so apply creates networking before EKS and destroy
removes EKS before NAT. `bastion` has no dependency on either component and can
be managed independently. It uses the existing public subnet.

Each component has a separate S3 state:

| Component | State key |
| --- | --- |
| Permanent Terraform VPC | `infra/terraform.tfstate` |
| Bastion | `bastion/terraform.tfstate` |
| NAT | `networking/nat/terraform.tfstate` |
| EKS | `eks/terraform.tfstate` |

The all-components commands below run only the three directories in this
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

The apply and destroy commands operate on Bastion, NAT, and EKS only. EKS is
ordered after NAT for apply and before NAT for destroy; Bastion remains
independently manageable. To operate Bastion by itself, run Terragrunt from
`bastion/`.

The private EKS API is not reachable from the public internet. Confirm that
your administration path and required private-subnet egress are working before
creating the EKS node group.

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
