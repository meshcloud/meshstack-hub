variable "test_context" {
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.run_id)
    error_message = "test_context must provide workspace and run_id."
  }

  validation {
    condition     = can(var.test_context.fixtures.stackit.mesh_tenant_id)
    error_message = "test_context must provide fixtures.stackit.mesh_tenant_id, the tenant to order the building blocks for."
  }

  validation {
    # Unlike most foundation smoke tests, this one also needs the hub ref in foundation mode: the
    # probe definition runs code from the hub.
    condition     = can(var.test_context.hub_git_ref)
    error_message = "test_context must provide hub_git_ref, the hub commit the probe definition runs."
  }

  validation {
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

locals {
  mode = try(var.test_context.mode, "hub")

  target_ref = {
    kind = "meshTenant"
    uuid = var.test_context.fixtures.stackit.mesh_tenant_id
  }
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
}

resource "meshstack_building_block" "service_account" {
  depends_on = [module.definition]

  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = module.definition.service_account_version_ref

    display_name = "${var.test_context.run_id}-service-account"
    target_ref   = local.target_ref

    inputs = {
      service_account_name = { value = jsonencode("${var.test_context.run_id}-fd") }
      # Enough for the probe to read the project.
      roles = { value = jsonencode(jsonencode(["reader"])) }
    }
  }
}

# Must be owned by the workspace that orders the federation.
resource "meshstack_building_block_definition" "probe" {
  metadata = {
    owned_by_workspace = var.test_context.workspace
    tags               = {}
  }

  spec = {
    display_name        = "${var.test_context.run_id} STACKIT Federation Probe"
    description         = "Reads its STACKIT project as the federated service account."
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "STACKIT" }]
  }

  version_spec = {
    draft         = true
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/service-account-federation/e2e/probe"
        ref_name                       = var.test_context.hub_git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
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
        # The federation trusts the token with the Azure audience.
        argument = jsonencode("/var/run/secrets/workload-identity/azure/token")
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

resource "meshstack_building_block" "this" {
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.definition.version_ref

    display_name               = "${var.test_context.run_id}-federation"
    target_ref                 = local.target_ref
    parent_building_block_refs = [meshstack_building_block.service_account.ref]

    inputs = {
      service_account_email                = { value = meshstack_building_block.service_account.status.outputs["service_account_email"].value }
      federated_building_block_definitions = { value = jsonencode(jsonencode([meshstack_building_block_definition.probe.metadata.uuid])) }
    }
  }
}

resource "meshstack_building_block" "probe" {
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = meshstack_building_block_definition.probe.version_latest

    display_name               = "${var.test_context.run_id}-federation-probe"
    target_ref                 = local.target_ref
    parent_building_block_refs = [meshstack_building_block.this.ref]

    inputs = {
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = meshstack_building_block.service_account.status.outputs["service_account_email"].value }
    }
  }
}
