# AWS CLI SSO Setup

## Prerequisites

- Ubuntu `platform-tools` VM running through Vagrant
- AWS CLI v2
- `jq`
- Access to AWS IAM Identity Center

## Initial setup

From the `platform-tools` VM, run:

```bash
bash /workspace/k8s-platform-lab/infra/aws/platform-tools/bootstrap-sso.sh
```

The script:

- Prompts for the AWS IAM Identity Center Start URL.
- Configures the `devops-lab` SSO session in `~/.aws/config`.
- Starts AWS SSO device-code authentication.
- Discovers the available AWS accounts and roles.
- Creates the `devops-admin` AWS CLI profile.
- Verifies access using AWS STS.

Open the authentication URL on your Windows browser, enter the device code, and approve access.

The Account ID does not need to be entered manually.

## Subsequent logins

After restarting or recreating the VM, if the SSO configuration already exists, authenticate using:

```bash
aws sso login --profile devops-admin --use-device-code --no-browser
```

If the VM was recreated and its AWS configuration was lost, run `bootstrap-sso.sh` again.

## Verify AWS identity

```bash
aws sts get-caller-identity --profile devops-admin
```

A successful response contains:

- `UserId`
- `Account`
- `Arn`

## Troubleshooting

### SSO session does not exist

Run the bootstrap script to recreate the AWS SSO configuration.

### SignatureDoesNotMatch / Signature expired

Check the VM clock:

```bash
timedatectl status
```

If the clock is incorrect, restart time synchronization:

```bash
sudo systemctl restart systemd-timesyncd
```

Verify the clock again before retrying AWS STS.

### Bash script reports an invalid option

Ensure the script uses Unix (LF) line endings, not Windows (CRLF).

## Security

- Do not commit `~/.aws/config` or SSO token caches.
- Do not store static AWS access keys in the repository.
- Authenticate using AWS IAM Identity Center.
