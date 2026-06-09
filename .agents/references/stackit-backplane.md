---
description: STACKIT backplane identity conventions for meshstack-hub modules under modules/stackit/. Covers WIF (preferred) and key-based (legacy) patterns, required variables/outputs, provider configuration, meshstack_integration.tf wiring, and the STACKIT backplane checklist.
---

# STACKIT Backplane Identity Conventions

STACKIT backplanes **must** use **Workload Identity Federation (WIF)** as the automation principal
for building block execution. WIF eliminates long-lived service account keys by exchanging a
meshStack-issued short-lived OIDC token for a STACKIT access token at runtime.

## Rationale

- **No static secrets**: No service account key JSON to rotate, revoke, or protect.
- **Least-privilege**: Each building block gets its own service account with exactly the roles it needs.
- **Short-lived credentials**: OIDC tokens are scoped per building block run and expire quickly.
- **No provider configuration in backplane**: The backplane module does not include a `provider.tf`.
  Authentication for the backplane itself is configured by the caller (e.g. the platform team running
  `tofu apply` or the integration runtime).

<!-- scorecard-checks: stackit_uses_wif, stackit_no_sa_key -->
## Implementation Pattern

```hcl
# backplane/main.tf — service account + WIF identity provider + role assignments

resource "stackit_service_account" "backplane" {
  project_id = var.project_id
  name       = "mesh-<service-name>"
}

resource "stackit_service_account_federated_identity_provider" "backplane" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  project_id            = var.project_id
  service_account_email = stackit_service_account.backplane.email
  name                  = "meshstack-${each.key}"
  issuer                = var.workload_identity_federation.issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = "api://AzureADTokenExchange"
    },
    {
      item     = "sub"
      operator = "equals"
      value    = each.value
    }
  ]
}

# Project-scoped role assignment (use this for project-level resources):
resource "stackit_authorization_project_role_assignment" "this" {
  resource_id = var.project_id
  role        = "<required-role>"
  subject     = stackit_service_account.backplane.email
}

# Organization-scoped role assignment (use this for org-level resources):
resource "stackit_authorization_organization_role_assignment" "this" {
  resource_id = var.organization_id
  role        = "<required-role>"
  subject     = stackit_service_account.backplane.email
}
```

<!-- scorecard-checks: stackit_sa_email_output -->
## Backplane Outputs (STACKIT)

Every STACKIT backplane must output the service account email:

```hcl
output "service_account_email" {
  value       = stackit_service_account.backplane.email
  description = "Email of the STACKIT service account used by the buildingblock provider via WIF."
}
```

Additional outputs (e.g. `project_id`, resource IDs) can be added as needed.

## Backplane Variables (STACKIT)

All STACKIT backplanes require at minimum:

```hcl
variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the service account will be created."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL and subject list for the meshStack building block identity provider."
}
```

Backplanes that manage organization-level resources also require:

```hcl
variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID where the service account will be granted permissions."
}
```

<!-- scorecard-checks: stackit_provider_oidc -->
## Buildingblock Provider Configuration

The buildingblock `provider.tf` must use `use_oidc = true` and `service_account_email`.
Do **not** use `service_account_key` — it requires a long-lived secret.

```hcl
# buildingblock/provider.tf
provider "stackit" {
  service_account_email = var.service_account_email
  use_oidc              = true
  # Token is read from STACKIT_FEDERATED_TOKEN_FILE env var injected by meshStack
}
```

## Buildingblock Variable

```hcl
variable "service_account_email" {
  type        = string
  nullable    = false
  description = "Email of the STACKIT service account for WIF-based authentication."
}
```

The service account email is not sensitive. Do **not** use `sensitive = true` here.

## `meshstack_integration.tf` Wiring (STACKIT)

Retrieve the meshStack WIF issuer and subject via the `meshstack_integrations` data source,
then pass them to the backplane. Register the WIF env vars as STATIC environment inputs so
the buildingblock runtime can exchange the token automatically.

```hcl
data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/<service>/backplane?ref=${var.hub.git_ref}"

  project_id = var.stackit_project_id

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

# Inside meshstack_building_block_definition version_spec.inputs:
service_account_email = {
  display_name    = "Service Account Email"
  description     = "Email of the STACKIT service account for WIF-based authentication."
  type            = "STRING"
  assignment_type = "STATIC"
  argument        = jsonencode(module.backplane.service_account_email)
}

STACKIT_USE_OIDC = {
  display_name    = "STACKIT Use OIDC"
  description     = "Enables OIDC-based WIF for the STACKIT provider."
  type            = "STRING"
  assignment_type = "STATIC"
  is_environment  = true
  argument        = jsonencode("1")
}

STACKIT_FEDERATED_TOKEN_FILE = {
  display_name    = "STACKIT Federated Token File"
  description     = "Path to the WIF token file injected by meshStack."
  type            = "STRING"
  assignment_type = "STATIC"
  is_environment  = true
  argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
}
```

## Provider Version

The `stackit_service_account_federated_identity_provider` resource requires provider version
`>= 0.95.0`. Pin to `~> 0.98.0` or later in backplane `versions.tf`.

## What to Avoid

- ❌ `service_account_key` / `stackit_service_account_key` — long-lived secret, no longer needed
- ❌ `service_account_key_json` output — replace with `service_account_email`
- ❌ `STACKIT_SERVICE_ACCOUNT_TOKEN` env var — deprecated
- ❌ Hardcoded `issuer` or `subjects` — always source from `data.meshstack_integrations`
- ❌ Non-sensitive output for credentials — `service_account_email` is not sensitive, but any key would be

## Checklist for STACKIT Backplanes

- [ ] `stackit_service_account` resource present
- [ ] `stackit_service_account_federated_identity_provider` resource present (with `for_each` over subjects)
- [ ] WIF assertions include `aud = "api://AzureADTokenExchange"` and `sub = each.value`
- [ ] Required role assignments present (`stackit_authorization_project_role_assignment` or `stackit_authorization_organization_role_assignment`)
- [ ] `service_account_email` output present (not sensitive, not `service_account_key_json`)
- [ ] `workload_identity_federation` variable present (`object({ issuer, subjects })`, `nullable = false`)
- [ ] Backplane `versions.tf` pins STACKIT provider to `~> 0.98.0` or later
- [ ] Buildingblock `provider.tf` uses `use_oidc = true` + `service_account_email`
- [ ] Buildingblock `variables.tf` has `service_account_email` (non-sensitive, `nullable = false`)
- [ ] No `service_account_key_json` variable or output anywhere
- [ ] `meshstack_integration.tf` uses `data.meshstack_integrations.integrations` for issuer/subject
- [ ] `meshstack_integration.tf` wires `STACKIT_USE_OIDC` and `STACKIT_FEDERATED_TOKEN_FILE` as STATIC env var inputs
