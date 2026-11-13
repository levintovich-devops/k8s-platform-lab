locals {
  shared_backend_config = jsondecode(
    file("${get_repo_root()}/infra/aws/terraform/backend-config.json")
  )
  temporary_state_encryption = true
}
