variable "test_context" {
  type = object({
    hub_git_ref          = string
    workspace            = string
    run_id               = string
    forgejo_base_url     = string
    forgejo_organization = string

    stackit_service_account_email = string
    stackit_project_id            = string
    stackit_git_instance_id       = string

    fixtures = object({
      stackit = object({
        project_id                  = string
        secrets_manager_instance_id = string
      })
    })
  })
  nullable = false
}

variable "backplane_secrets" {
  type = object({
    stackit_git_forgejo_api_token = string
  })
  sensitive = true
  nullable  = false

  validation {
    # `nullable = false` rejects only the whole object, so the attributes are checked explicitly.
    condition     = alltrue([for secret in values(var.backplane_secrets) : secret != null])
    error_message = "Every backplane secret must be set; the test runner exports them as TF_VAR_<name>."
  }
}

locals {
  secrets_manager_address     = "https://prod.sm.eu01.stackit.cloud"
  secrets_manager_instance_id = var.test_context.fixtures.stackit.secrets_manager_instance_id

  # Runs share the fixture instance, so each one writes only under its own id.
  vault_paths = {
    forgejo_api_token = "${var.test_context.run_id}/git/forgejo-api-token"
    registry_push     = "${var.test_context.run_id}/registry/push"
  }
}

provider "stackit" {
  # Credentials come from the environment, WIF in CI.
  default_region = "eu01"
}

resource "stackit_secretsmanager_user" "writer" {
  project_id    = var.test_context.fixtures.stackit.project_id
  instance_id   = local.secrets_manager_instance_id
  description   = "${var.test_context.run_id} git-repository writer"
  write_enabled = true
}

resource "stackit_secretsmanager_user" "reader" {
  project_id    = var.test_context.fixtures.stackit.project_id
  instance_id   = local.secrets_manager_instance_id
  description   = "${var.test_context.run_id} git-repository reader"
  write_enabled = false
}

provider "vault" {
  address = local.secrets_manager_address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  auth_login_userpass {
    username = stackit_secretsmanager_user.writer.username
    password = stackit_secretsmanager_user.writer.password
  }
}

resource "vault_kv_secret_v2" "forgejo_api_token" {
  mount                = local.secrets_manager_instance_id
  name                 = local.vault_paths.forgejo_api_token
  data_json_wo         = jsonencode({ forgejo_api_token = var.backplane_secrets.stackit_git_forgejo_api_token })
  data_json_wo_version = 1
}

# Only set as Actions secrets, so no registry has to accept it.
resource "vault_kv_secret_v2" "registry_push" {
  mount                = local.secrets_manager_instance_id
  name                 = local.vault_paths.registry_push
  data_json_wo         = jsonencode({ username = "${var.test_context.run_id}-push", password = "e2e-only" })
  data_json_wo_version = 1
}

module "stackit_git_repository" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Git Repository"

  forgejo_base_url     = var.test_context.forgejo_base_url
  forgejo_organization = var.test_context.forgejo_organization

  vault_reader = {
    address  = local.secrets_manager_address
    mount    = local.secrets_manager_instance_id
    username = stackit_secretsmanager_user.reader.username
    password = stackit_secretsmanager_user.reader.password
  }
  forgejo_api_token_path = vault_kv_secret_v2.forgejo_api_token.name
  registry_push_path     = vault_kv_secret_v2.registry_push.name

  stackit_service_account_email = var.test_context.stackit_service_account_email
  stackit_project_id            = var.test_context.stackit_project_id
  stackit_git_instance_id       = var.test_context.stackit_git_instance_id
}

# Only this test knows the uuid of its definition, so it federates the fixture service account with it.
resource "stackit_service_account_federated_identity_provider" "git_repository" {
  project_id            = var.test_context.fixtures.stackit.project_id
  service_account_email = var.test_context.stackit_service_account_email
  name                  = "${var.test_context.run_id}-git-repository"
  issuer                = module.stackit_git_repository.building_block_definition.version_ref.workload_identity_federation.issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = "api://AzureADTokenExchange"
    },
    {
      item     = "sub"
      operator = "equals"
      value    = module.stackit_git_repository.building_block_definition.version_ref.workload_identity_federation.subject
    }
  ]
}

output "version_ref" {
  value = { uuid = module.stackit_git_repository.building_block_definition.version_ref.uuid }
}
