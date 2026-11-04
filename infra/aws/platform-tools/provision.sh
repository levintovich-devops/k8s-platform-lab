#!/usr/bin/env bash
set -euo pipefail

terraform_version="1.13.5"
aws_cli_version="2.36.0"

terraform_is_pinned() {
  command -v terraform >/dev/null &&
    [[ "$(terraform version | sed -n '1p')" == "Terraform v${terraform_version}" ]]
}

aws_cli_is_pinned() {
  command -v aws >/dev/null &&
    [[ "$(aws --version)" == "aws-cli/${aws_cli_version} "* ]]
}

if ! terraform_is_pinned || ! aws_cli_is_pinned; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl gnupg unzip
fi

if ! terraform_is_pinned; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg |
    gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

  printf '%s\n' \
    'deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com jammy main' \
    > /etc/apt/sources.list.d/hashicorp.list

  apt-get update
  apt-get install -y "terraform=${terraform_version}-1"
fi

if ! aws_cli_is_pinned; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${aws_cli_version}.zip" \
    -o "$tmp_dir/awscliv2.zip"
  unzip -q "$tmp_dir/awscliv2.zip" -d "$tmp_dir"

  if [[ -x /usr/local/aws-cli/v2/current/bin/aws ]]; then
    "$tmp_dir/aws/install" --update
  else
    "$tmp_dir/aws/install"
  fi
  hash -r
fi

terraform version
aws --version
terraform_is_pinned
aws_cli_is_pinned
