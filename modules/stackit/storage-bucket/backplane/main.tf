resource "stackit_service_account" "building_block" {
  project_id = var.project_id
  name       = var.service_account_name
}

resource "stackit_service_account_federated_identity_provider" "building_block" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  project_id            = var.project_id
  service_account_email = stackit_service_account.building_block.email
  name                  = "meshstack-${each.key}"
  issuer                = var.workload_identity_federation.issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = var.workload_identity_federation.audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = each.value
    }
  ]
}

resource "stackit_service_account_federated_identity_provider" "trusted_runner" {
  for_each = { for identity in var.trusted_runner_identities : identity.runner_uuid => identity }

  depends_on = [stackit_service_account_federated_identity_provider.building_block]

  lifecycle {
    precondition {
      condition     = each.value.subject != null
      error_message = "The building block runner ${each.key} is a trusted runner, but no version of the definition runs on it, so there is nothing to trust. Remove it from meshstack.trusted_runner_refs."
    }
  }

  project_id            = var.project_id
  service_account_email = stackit_service_account.building_block.email
  name                  = "trusted-runner-${each.key}"
  issuer                = each.value.issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = each.value.audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = each.value.subject
    }
  ]
}

resource "stackit_authorization_project_role_assignment" "object_storage" {
  resource_id = var.project_id
  role        = "object-storage.admin"
  subject     = stackit_service_account.building_block.email
}

resource "stackit_authorization_project_role_assignment" "service_account" {
  resource_id = var.project_id
  role        = "object-storage.service-account-admin"
  subject     = stackit_service_account.building_block.email
}

resource "stackit_objectstorage_credentials_group" "admin" {
  project_id = var.project_id
  name       = "mesh-storage-admin"
}

resource "stackit_objectstorage_credential" "admin" {
  project_id           = var.project_id
  credentials_group_id = stackit_objectstorage_credentials_group.admin.credentials_group_id
}
