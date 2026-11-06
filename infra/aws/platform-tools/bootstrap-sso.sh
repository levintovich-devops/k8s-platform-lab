
#!/usr/bin/env bash
set -euo pipefail

SSO_SESSION="devops-lab"
PROFILE="devops-admin"
REGION="eu-north-1"
PREFERRED_ROLE="AdministratorAccess"

echo "=== AWS SSO Bootstrap ==="

read -r -p "AWS SSO Start URL: " SSO_URL

if [[ ! "$SSO_URL" =~ ^https://[^[:space:]]+$ ]]; then
  echo "ERROR: Invalid SSO Start URL."
  exit 1
fi

command -v aws >/dev/null || {
  echo "ERROR: AWS CLI is not installed."
  exit 1
}

command -v jq >/dev/null || {
  echo "ERROR: jq is required."
  exit 1
}

# Configure SSO session in ~/.aws/config

mkdir -p "$HOME/.aws"
chmod 700 "$HOME/.aws"

CONFIG="$HOME/.aws/config"
touch "$CONFIG"
chmod 600 "$CONFIG"

# Remove existing section for this SSO session, if present.
# Preserve all other AWS CLI configuration sections.
TEMP_CONFIG="$(mktemp)"
trap 'rm -f "$TEMP_CONFIG"' EXIT

awk -v section="[sso-session $SSO_SESSION]" '
  /^\[/ {
    skip = ($0 == section)
  }
  !skip { print }
' "$CONFIG" > "$TEMP_CONFIG"

cat "$TEMP_CONFIG" > "$CONFIG"

cat >> "$CONFIG" <<EOF

[sso-session $SSO_SESSION]
sso_start_url = $SSO_URL
sso_region = $REGION
sso_registration_scopes = sso:account:access
EOF

echo
echo "Authenticating with AWS IAM Identity Center..."

aws sso login \
  --sso-session "$SSO_SESSION" \
  --use-device-code \
  --no-browser

# Retrieve SSO access token from AWS CLI cache.
# Token is never printed.

CACHE_KEY="$(printf '%s' "$SSO_SESSION" | sha1sum | cut -d' ' -f1)"
CACHE_FILE="$HOME/.aws/sso/cache/${CACHE_KEY}.json"

if [[ ! -f "$CACHE_FILE" ]]; then
  echo "ERROR: AWS SSO token cache not found."
  exit 1
fi

ACCESS_TOKEN="$(jq -r '.accessToken // empty' "$CACHE_FILE")"

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "ERROR: AWS SSO access token not found."
  exit 1
fi

echo
echo "Discovering AWS accounts..."

ACCOUNTS="$(
  aws sso list-accounts \
    --access-token "$ACCESS_TOKEN" \
    --region "$REGION" \
    --output json
)"

mapfile -t ACCOUNT_IDS < <(
  jq -r '.accountList[].accountId' <<< "$ACCOUNTS"
)

if (( ${#ACCOUNT_IDS[@]} == 0 )); then
  echo "ERROR: No AWS accounts available."
  exit 1
fi

if (( ${#ACCOUNT_IDS[@]} == 1 )); then
  ACCOUNT_ID="${ACCOUNT_IDS[0]}"
else
  echo "Available AWS accounts:"

  for i in "${!ACCOUNT_IDS[@]}"; do
    echo "$((i + 1))) ${ACCOUNT_IDS[i]}"
  done

  read -r -p "Select account number: " CHOICE

  if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] ||
     (( CHOICE < 1 || CHOICE > ${#ACCOUNT_IDS[@]} )); then
    echo "ERROR: Invalid selection."
    exit 1
  fi

  ACCOUNT_ID="${ACCOUNT_IDS[CHOICE-1]}"
fi

echo
echo "Discovering AWS roles..."

ROLES="$(
  aws sso list-account-roles \
    --access-token "$ACCESS_TOKEN" \
    --account-id "$ACCOUNT_ID" \
    --region "$REGION" \
    --output json
)"

mapfile -t ROLE_NAMES < <(
  jq -r '.roleList[].roleName' <<< "$ROLES"
)

if (( ${#ROLE_NAMES[@]} == 0 )); then
  echo "ERROR: No AWS roles available."
  exit 1
fi

if [[ " ${ROLE_NAMES[*]} " == *" $PREFERRED_ROLE "* ]]; then
  ROLE="$PREFERRED_ROLE"
elif (( ${#ROLE_NAMES[@]} == 1 )); then
  ROLE="${ROLE_NAMES[0]}"
else
  echo "Available AWS roles:"

  for i in "${!ROLE_NAMES[@]}"; do
    echo "$((i + 1))) ${ROLE_NAMES[i]}"
  done

  read -r -p "Select role number: " CHOICE

  if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] ||
     (( CHOICE < 1 || CHOICE > ${#ROLE_NAMES[@]} )); then
    echo "ERROR: Invalid selection."
    exit 1
  fi

  ROLE="${ROLE_NAMES[CHOICE-1]}"
fi

echo
echo "Configuring AWS CLI profile..."

aws configure set sso_session "$SSO_SESSION" \
  --profile "$PROFILE"

aws configure set sso_account_id "$ACCOUNT_ID" \
  --profile "$PROFILE"

aws configure set sso_role_name "$ROLE" \
  --profile "$PROFILE"

aws configure set region "$REGION" \
  --profile "$PROFILE"

aws configure set output json \
  --profile "$PROFILE"

# Configure default profile using the same SSO identity.
aws configure set sso_session "$SSO_SESSION" --profile default
aws configure set sso_account_id "$ACCOUNT_ID" --profile default
aws configure set sso_role_name "$ROLE" --profile default
aws configure set region "$REGION" --profile default
aws configure set output json --profile default

echo
echo "Verifying AWS access..."

aws sts get-caller-identity --profile "$PROFILE"

echo
echo "=== AWS SSO Bootstrap Completed Successfully ==="
echo "Profile: $PROFILE"
echo "Region:  $REGION"
echo "Role:    $ROLE"
echo
echo "For future logins, run:"
echo "aws sso login --profile $PROFILE --use-device-code --no-browser"
