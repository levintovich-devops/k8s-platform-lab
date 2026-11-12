# AWS Infrastructure Lab

This directory contains the AWS infrastructure tooling for the `k8s-platform-lab` project.

## 1. Architecture

The AWS tooling runs inside a dedicated Ubuntu virtual machine managed by Vagrant and VirtualBox.

Directory structure:

```text
infra/aws/
├── README.md
├── platform-tools/
│   ├── Vagrantfile
│   ├── provision.sh
│   └── bootstrap-sso.sh
├── terraform/             # Permanent VPC infrastructure
└── terragrunt/            # Temporary Bastion, NAT, and EKS components
```

The VM mounts the project repository at:

```text
/workspace/k8s-platform-lab
```

AWS authentication uses **AWS IAM Identity Center (SSO)** instead of permanent IAM access keys.

## 2. Prerequisites

On the Windows host:

- VirtualBox
- Vagrant
- Access to AWS IAM Identity Center

The VM provisioning script installs the required command-line tools, including:

- AWS CLI v2
- Terraform
- `jq`

It also configures the `Asia/Jerusalem` timezone and enables NTP synchronization.

## 3. Create the Tools VM

Open PowerShell and navigate to:

```powershell
cd D:\MyBusieness\Projects\GitHub\k8s-platform-lab\infra\aws\platform-tools
```

Create and provision the VM:

```powershell
vagrant up
```

Connect to Ubuntu:

```powershell
vagrant ssh
```

## 4. Initial AWS SSO Configuration

Run the bootstrap script inside the VM:

```bash
bash /workspace/k8s-platform-lab/infra/aws/platform-tools/bootstrap-sso.sh
```

The script performs the following operations:

1. Requests the AWS IAM Identity Center Start URL.
2. Configures the `devops-lab` SSO session in `~/.aws/config`.
3. Starts browser-based device-code authentication.
4. Retrieves available AWS accounts automatically.
5. Retrieves available permission-set roles.
6. Creates or updates the `devops-admin` profile.
7. Configures the `default` profile with the same account, role and region.
8. Verifies AWS access using STS.

The configured AWS region is `eu-north-1`.

The AWS Account ID does not need to be entered manually.

If multiple accounts or roles are available, the script may request a selection.

### Complete authentication

The script displays an AWS authentication URL and device code.

Open the URL in a Windows browser, enter the code and approve the authentication request.

The script then continues automatically.

## 5. Verify AWS Access

Verify the current AWS identity:

```bash
aws sts get-caller-identity
```

The response should contain `UserId`, `Account` and `Arn`.

Verify EC2 API access:

```bash
aws ec2 describe-security-groups
```

Both commands should work without specifying `--profile` or `--region`.

To explicitly use the named profile:

```bash
aws sts get-caller-identity --profile devops-admin
```

## 6. Subsequent AWS Logins

When the SSO configuration already exists, authenticate with:

```bash
aws sso login --profile devops-admin --use-device-code --no-browser
```

The `default` and `devops-admin` profiles reference the same SSO session.

After authentication, normal AWS CLI commands can be executed without specifying a profile.

If the VM has been destroyed and recreated, run the bootstrap script again because the previous VM's local AWS configuration and token cache are not preserved.

## 7. AWS Configuration

AWS CLI configuration is stored locally in:

```text
~/.aws/config
```

Expected configuration structure:

```ini
[profile devops-admin]
sso_session = devops-lab
sso_account_id = <automatically discovered account ID>
sso_role_name = AdministratorAccess
region = eu-north-1
output = json

[default]
sso_session = devops-lab
sso_account_id = <automatically discovered account ID>
sso_role_name = AdministratorAccess
region = eu-north-1
output = json

[sso-session devops-lab]
sso_start_url = <your IAM Identity Center Start URL>
sso_region = eu-north-1
sso_registration_scopes = sso:account:access
```

`AdministratorAccess` is the preferred role when available. The actual role depends on the user's AWS IAM Identity Center assignments.

The AWS configuration and SSO token cache must remain outside Git.

## 8. AWS Infrastructure Lifecycle

The Terraform configuration in `terraform/` exclusively owns the permanent
VPC, subnets, route tables, and Internet Gateway. Do not include it in
temporary-infrastructure destroy operations.

Terragrunt in `terragrunt/` manages temporary Bastion, NAT, and EKS resources
in separate states. From that directory, review and operate the complete
temporary lifecycle with:

```bash
terragrunt run --all plan
terragrunt run --all apply
terragrunt run --all destroy
```

EKS depends on NAT for apply/destroy ordering; Bastion remains independent.
Before the first plan, follow the state-inspection and one-time Bastion
migration instructions in [`terragrunt/README.md`](./terragrunt/README.md).

## 9. Troubleshooting

### NoRegion

Example:

```text
You must specify a region.
```

Check the default profile:

```bash
aws configure list --profile default
```

If the region or SSO configuration is missing, the default profile has not been configured correctly.

### SSO session does not exist

Check the available profiles:

```bash
aws configure list-profiles
```

The AWS configuration must contain a section named:

```ini
[sso-session devops-lab]
```

A profile named `sso-session.devops-lab` is not a replacement for this section.

### Expired SSO session

Authenticate again:

```bash
aws sso login --profile devops-admin --use-device-code --no-browser
```

### SignatureDoesNotMatch / Signature expired

AWS request signing depends on accurate system time.

Check the VM clock:

```bash
timedatectl status
```

If the system clock is incorrect, restart time synchronization:

```bash
sudo systemctl restart systemd-timesyncd
```

Check the clock again before retrying AWS commands.

**Known limitation:** Time synchronization after the Windows host sleeps or the VirtualBox VM is suspended has not yet been fully validated. Enabling NTP during provisioning does not guarantee that the guest clock will always recover correctly.

### Missing jq

The bootstrap script requires `jq`, which is installed automatically by `provision.sh`.

### Windows CRLF line endings

Bash scripts must use Unix LF line endings.

The repository's `.gitattributes` enforces LF for `*.sh` files.

## 10. Rebuild and Validation

To test the environment from a clean state, run these commands from the `platform-tools` directory in Windows PowerShell:

```powershell
vagrant destroy -f
vagrant up
vagrant ssh
```

Inside the new Ubuntu VM, run:

```bash
bash /workspace/k8s-platform-lab/infra/aws/platform-tools/bootstrap-sso.sh
```

After successful authentication, verify:

```bash
aws sts get-caller-identity
aws ec2 describe-security-groups
timedatectl status
```

The expected outcome is a reproducible environment with automatic tool installation, functional AWS SSO authentication and AWS CLI access without explicit profile or region arguments.

## 11. Security

- Use AWS IAM Identity Center for authentication.
- Do not commit AWS access tokens, credentials or local AWS configuration files.
- Do not hardcode AWS Account IDs or private SSO Start URLs in repository scripts.
- Keep SSO authentication interactive.
- Use the minimum required AWS permissions for production workloads.