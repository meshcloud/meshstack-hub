---
description: Azure backplane identity conventions for meshstack-hub modules under modules/azure/. Covers UAMI (User-Assigned Managed Identity) with WIF patterns, required variables/outputs, meshstack_integration.tf wiring, and what to avoid (no SPNs, no client secrets).
---

# Azure Backplane Identity Conventions

Azure backplanes **must** use **User-Assigned Managed Identities (UAMIs)** as the automation
principal for building block execution. Do **not** create Service Principals (SPNs) via
`azuread_application` + `azuread_service_principal`.

## Rationale

- **Self-service**: Platform engineers can deploy UAMIs without invoking a central Entra admin team.
  Creating a UAMI requires only `Managed Identity Contributor` on the subscription — no Entra ID
  `Application.ReadWrite.All` or `Application Administrator` role needed.
- **WIF-native**: UAMIs support federated identity credentials (`azurerm_federated_identity_credential`)
  for meshStack's workload identity federation out of the box.
- **Management Group scope**: UAMIs can hold Azure RBAC role assignments at any scope including
  Management Groups. They can also be assigned Entra directory roles (e.g. Directory Readers).
- **CI/CD testability**: E2E smoke tests run under a GHA UAMI with GitHub WIF in a static
  subscription. Using UAMIs in backplanes means the same identity model is used end-to-end,
  and `tofu test` can deploy and destroy `meshstack_integration.tf` without Entra app registration
  privileges.
- **No secrets rotation**: Unlike SPNs with client secrets, UAMIs with WIF produce no secrets to
  manage or rotate.

<!-- scorecard-checks: azure_uses_uami, azure_federated_identity_credential -->
## Implementation Pattern

```hcl
# backplane/main.tf — UAMI-based automation principal

resource "azurerm_resource_group" "backplane" {
  name     = var.name
  location = var.location
}

resource "azurerm_user_assigned_identity" "backplane" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.backplane.name
}

resource "azurerm_federated_identity_credential" "backplane" {
  for_each = { for index, identity in var.workload_identity_federations : tostring(index) => identity }

  name                      = "subject-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.backplane.id
  audience                  = [each.value.audience]
  issuer                    = each.value.issuer
  subject                   = each.value.subject
}

resource "azurerm_role_definition" "backplane" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} building block"
  scope       = var.scope
  permissions { actions = [ /* ... */ ] }
}

resource "azurerm_role_assignment" "backplane" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.backplane.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}
```

<!-- scorecard-checks: azure_wif_nonnullable -->
## Backplane Variables (Azure)

Every Azure backplane must accept these variables:

```hcl
variable "name" {
  type        = string
  nullable    = false
  description = "Name for the building block identity and role definition."
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope for role assignment (management group or subscription ID)."
}

variable "location" {
  type        = string
  description = "Azure region for the UAMI resource."
}

variable "workload_identity_federations" {
  type = list(object({
    issuer   = string
    audience = string
    subject  = string
  }))
  nullable    = false
  description = <<-EOT
  meshStack identities the automation identity trusts, one per building block runner. For more
  subjects of one issuer, pass one entry per subject.
  EOT
}
```

<!-- scorecard-checks: azure_identity_output -->
## Backplane Outputs (Azure)

```hcl
output "identity" {
  value = {
    client_id    = azurerm_user_assigned_identity.backplane.client_id
    principal_id = azurerm_user_assigned_identity.backplane.principal_id
    tenant_id    = azurerm_user_assigned_identity.backplane.tenant_id
  }
}
```

<!-- scorecard-checks: azure_no_azuread_application, azure_no_spn, azure_no_app_password, azure_no_create_spn_toggle -->
## What to Avoid

- ❌ `azuread_application` / `azuread_service_principal` — do not create SPNs
- ❌ `azuread_application_password` — no client secrets
- ❌ `existing_principal_ids` / `create_service_principal_name` toggle pattern — unnecessary complexity
- ❌ Conditional WIF-vs-secret logic — always use WIF with UAMIs

<!-- scorecard-checks: azure_integration_rg_location -->
## `meshstack_integration.tf` Wiring (Azure)

In the integration file, pass the UAMI client ID as the `ARM_CLIENT_ID` environment variable:

```hcl
module "runner_identity" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud               = "azure"
  runner_ref          = var.meshstack.runner_ref
  trusted_runner_refs = var.meshstack.trusted_runner_refs
  versions            = meshstack_building_block_definition.this.versions
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/<service>/backplane?ref=${var.hub.git_ref}"

  name     = var.backplane_name
  scope    = var.azure_scope
  location = var.azure_location

  workload_identity_federations = module.runner_identity.identities
}
```

The input `ARM_OIDC_TOKEN_FILE_PATH` reads `module.runner_identity.token_path`, see
[meshstack-integration.md § Runner identity](meshstack-integration.md#runner-identity). Each
runner has its own Azure audience, so the credentials take it from the identity.

The credentials are keyed by the index of the identity, so the current runner keeps `subject-0`.
When the definition moves to another runner, `subject-0` changes to the new runner in place, and
the old runner listed in `trusted_runner_refs` gets a new credential. Entra can take a few minutes
before it accepts a new credential, so runs on the old runner can fail during that time.

The `meshstack_integration.tf` must include `azure_location` variable (flat, provider-prefixed) for all resource placement.
The resource group is derived from and managed by the backplane using `var.name`.

## Checklist for Azure Backplanes

- [ ] Uses `azurerm_user_assigned_identity` (not `azuread_application`)
- [ ] Uses `azurerm_federated_identity_credential` (not `azuread_application_federated_identity_credential`)
- [ ] No `azuread_application_password` resources
- [ ] No `create_service_principal_name` / `existing_principal_ids` toggle
- [ ] `workload_identity_federations` variable is non-nullable (always required)
- [ ] Outputs `identity.client_id`, `identity.principal_id`, `identity.tenant_id`
- [ ] `meshstack_integration.tf` includes `azure_location` variable (no separate `azure_resource_group_name` — the backplane manages its own resource group named after `var.name`)
