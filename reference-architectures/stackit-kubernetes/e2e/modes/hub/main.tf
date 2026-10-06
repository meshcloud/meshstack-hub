variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    fixtures = object({
      stackit = object({
        organization_id = string
        project_id      = string
        # The platform and landing zone a test creating a brand-new tenant orders against. They
        # stand in for the STACKIT Landing Zone this architecture is built on.
        platform_uuid               = string
        landing_zone_name           = string
        secrets_manager_instance_id = string
      })
    })
  })
  nullable = false
}

provider "stackit" {
  # Credentials come from the environment, WIF in CI.
  experiments = ["iam"]
}


# The two definitions of the STACKIT Landing Zone this architecture orders. Their backplanes live
# in the fixtures project.
module "service_account" {
  source = "../../../../../modules/stackit/service-account"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Service Account"

  stackit_organization_id      = var.test_context.fixtures.stackit.organization_id
  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-sabp"
  stackit_assignable_roles     = ["editor", "iam.member-admin"]

  stackit_federation_backplane_email = module.service_account_federation.backplane_service_account_email
}

module "service_account_federation" {
  source = "../../../../../modules/stackit/service-account-federation"

  # Also deletes this definition before its parent's, which meshStack's `fk_tbb_Parent` constraint
  # requires.
  service_account_definition_ref = module.service_account.building_block_definition.ref

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Service Account Federation"

  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-safb"
}

module "stackit_kubernetes" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  # Keeps the platform destroyable, so the test can tear it down.
  playground_mode = true
}

output "version_ref" {
  value = { uuid = module.stackit_kubernetes.building_block_definition.version_ref.uuid }
}

output "landingzone" {
  value = {
    platform_ref = { uuid = var.test_context.fixtures.stackit.platform_uuid, kind = "meshPlatform" }
    landingzone_refs = {
      default = { name = var.test_context.fixtures.stackit.landing_zone_name, kind = "meshLandingZone" }
    }
    service_account_bbd_version_ref            = { uuid = module.service_account.building_block_definition.version_ref.uuid }
    service_account_federation_bbd_version_ref = { uuid = module.service_account_federation.building_block_definition.version_ref.uuid }
  }
}

resource "stackit_secretsmanager_user" "fixture_reader" {
  project_id    = var.test_context.fixtures.stackit.project_id
  instance_id   = var.test_context.fixtures.stackit.secrets_manager_instance_id
  description   = "${var.test_context.run_id} stackit-kubernetes reader"
  write_enabled = false
}

output "fixture_secrets_reader" {
  value = {
    username = stackit_secretsmanager_user.fixture_reader.username
    password = stackit_secretsmanager_user.fixture_reader.password
  }
  sensitive = true
}
