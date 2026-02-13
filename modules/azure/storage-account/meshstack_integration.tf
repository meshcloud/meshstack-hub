# TODO: this is actual not a correct file but just acts as an example for now

locals {
  name = "azure-storage-account"
  scope = "/subscriptions/00000000-0000-0000-0000-000000000000"
  existing_principal_ids = [
    "00000000-0000-0000-0000-000000000000"
  ]
  service_principal_name = "storage-account-deployer"

  workspace_identifier = "my-workspace"
}

provider "meshstack" {
  # Configure meshStack API credentials here or use environment variables.
  # endpoint  = "https://api.my.meshstack.io"
  # apikey    = "00000000-0000-0000-0000-000000000000"
  # apisecret = "uFOu4OjbE4JiewPxezDuemSP3DUrCYmw"
}

provider "azurerm" {
  features {}
}

# Import the backplane module to get IAM and other required outputs
module "backplane" {
  source = "./backplane"
  name   = local.name
  scope  = local.scope
  existing_principal_ids = local.existing_principal_ids
  create_service_principal_name = local.service_principal_name
  workload_identity_federation = {} # TODO this should come from data_source
}

# Import the building block definition into meshStack
# NOTE: meshstack_buildingblock_definition is a placeholder for demonstration. Replace with the actual resource if available.
resource "meshstack_buildingblock_definition" "storage_account" {
  metadata = {
    name               = "azure-storage-account"
    owned_by_workspace = local.workspace_identifier
  }

  spec = {
    display_name = "Azure Storage Account"
    description  = "Provision Azure Storage Accounts with encryption and access control"

    supported_platforms = ["azure"]

    source = {
      git = {
        url = "https://github.com/meshcloud/meshstack-hub.git"
        ref = "main"
        path = "modules/azure/storage-account/buildingblock"
      }
    }

    implementation_type = "Terraform"
    # Pass IAM outputs as inputs if required by your building block
    role_definition_id  = module.backplane.role_definition_id
    role_assignment_ids = module.backplane.role_assignment_ids
    principal_ids       = module.backplane.role_assignment_principal_ids
    service_principal   = module.backplane.created_service_principal
    application         = module.backplane.created_application
    scope               = module.backplane.scope
  }
}
