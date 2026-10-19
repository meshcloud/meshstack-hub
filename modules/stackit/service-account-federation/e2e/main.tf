# Hub mode only: the case builds all three definitions from source, including the probe, which
# exists for this test alone.
variable "test_context" {
  type = object({
    workspace   = string
    run_id      = string
    hub_git_ref = string

    fixtures = object({
      stackit = object({
        organization_id = string
        project_id      = string
        mesh_tenant_id  = string
      })
    })
  })
  nullable = false
}

provider "stackit" {
  # Credentials come from the environment: a key file locally, WIF in CI.
  experiments = ["iam"]
}

locals {
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
  tenant = {
    kind = "meshTenant"
    uuid = var.test_context.fixtures.stackit.mesh_tenant_id
  }
}

module "service_account" {
  source = "../../service-account"

  meshstack                    = local.meshstack
  hub                          = local.hub
  bbd_display_name             = "${var.test_context.run_id} STACKIT Service Account"
  stackit_organization_id      = var.test_context.fixtures.stackit.organization_id
  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-sabp"
}

module "federation" {
  source = "../"

  # A federation block is a child of a service account block, so its definition goes first on teardown.
  depends_on = [module.service_account]

  meshstack                    = local.meshstack
  hub                          = local.hub
  bbd_display_name             = "${var.test_context.run_id} STACKIT Service Account Federation"
  stackit_organization_id      = var.test_context.fixtures.stackit.organization_id
  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-fbp"
}

# The definition whose runs act as the federated account. Its run reads the tenant's project, which
# succeeds only when the trust entry matches the token its runner presents.
resource "meshstack_building_block_definition" "probe" {
  metadata = {
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name        = "${var.test_context.run_id} STACKIT Federation Probe"
    description         = "Reads the tenant's STACKIT project as the federated service account."
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "STACKIT" }]
  }

  version_spec = {
    draft         = true
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version = "1.12.5"
        repository_url    = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path   = "modules/stackit/service-account-federation/e2e/probe"
        ref_name          = var.test_context.hub_git_ref
        async             = false
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }
      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_environment  = true
      }
      STACKIT_USE_OIDC = {
        display_name    = "STACKIT Use OIDC"
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("1")
      }
      STACKIT_FEDERATED_TOKEN_FILE = {
        display_name    = "STACKIT Federated Token File"
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }
    }

    outputs = {
      project_name = {
        display_name    = "Project Name"
        type            = "STRING"
        assignment_type = "NONE"
      }
    }
  }
}

resource "meshstack_building_block" "service_account" {
  depends_on          = [module.service_account]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.service_account.building_block_definition.version_ref
    display_name                          = "${var.test_context.run_id}-service-account"
    target_ref                            = local.tenant

    inputs = {
      service_account_name = { value = jsonencode("${var.test_context.run_id}-sa") }
      roles                = { value = jsonencode(jsonencode(["reader"])) }
    }
  }
}

locals {
  service_account_email = jsondecode(meshstack_building_block.service_account.status.outputs["service_account_email"].value)
}

resource "meshstack_building_block" "federation" {
  depends_on          = [module.federation]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.federation.building_block_definition.version_ref
    display_name                          = "${var.test_context.run_id}-federation"
    target_ref                            = local.tenant
    parent_building_block_refs            = [meshstack_building_block.service_account.ref]

    inputs = {
      service_account_email                = { value = jsonencode(local.service_account_email) }
      federated_building_block_definitions = { value = jsonencode(jsonencode([meshstack_building_block_definition.probe.metadata.uuid])) }
    }
  }
}

resource "meshstack_building_block" "probe" {
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = meshstack_building_block_definition.probe.version_latest
    display_name                          = "${var.test_context.run_id}-federation-probe"
    target_ref                            = local.tenant
    parent_building_block_refs            = [meshstack_building_block.federation.ref]

    inputs = {
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
    }
  }
}
