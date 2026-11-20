variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    fixtures = object({
      stackit = object({
        project_id = string
      })
    })
  })
  nullable = false
}

variable "database_only" {
  type     = bool
  nullable = false
}

variable "existing_instance_id" {
  type = string
}

provider "stackit" {
  # Credentials come from the environment, WIF in CI.
  experiments = ["iam"]
}

locals {
  federation = module.postgres.building_block_definition.version_ref.workload_identity_federation
}

# Stands in for the account a platform provides with the stackit/service-account building block.
resource "stackit_service_account" "this" {
  project_id = var.test_context.fixtures.stackit.project_id
  name       = "${var.test_context.run_id}-pg${var.database_only ? "d" : ""}"
}

resource "stackit_authorization_project_role_assignment" "postgres_flex_admin" {
  resource_id = var.test_context.fixtures.stackit.project_id
  role        = "postgres-flex.admin"
  subject     = stackit_service_account.this.email
}

# Only this test knows the uuid of its definition, so it federates the service account with it.
resource "stackit_service_account_federated_identity_provider" "this" {
  depends_on = [stackit_authorization_project_role_assignment.postgres_flex_admin]

  project_id            = var.test_context.fixtures.stackit.project_id
  service_account_email = stackit_service_account.this.email
  name                  = "${var.test_context.run_id}-postgres"
  issuer                = local.federation.issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = local.federation.azure.audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = local.federation.subject
    }
  ]
}

module "postgres" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT PostgreSQL${var.database_only ? " Database" : ""}"

  database_only                 = var.database_only
  stackit_existing_instance_id  = var.existing_instance_id
  stackit_project_id            = var.test_context.fixtures.stackit.project_id
  stackit_service_account_email = stackit_service_account.this.email
  stackit_acl                   = ["192.0.2.0/24"]
}

output "version_ref" {
  value = module.postgres.building_block_definition.version_ref
}
