---
description: STACKIT backplane identity conventions for meshstack-hub modules under modules/stackit/. Covers service account + key pattern, required variables/outputs, provider configuration, meshstack_integration.tf wiring, and the STACKIT backplane checklist.
---

# STACKIT Backplane Identity Conventions

STACKIT backplanes **must** use a **service account with a long-lived key** as the automation
principal for building block execution. The key JSON is provisioned in the backplane and injected
as a sensitive static input into the building block definition.

## Rationale

- **Self-contained credentials**: The service account and its key are provisioned once in the
  backplane Terraform module. The key JSON is a single credential that bundles the service account
  email, key ID, and private key — no extra wiring needed.
- **Least-privilege**: Each building block gets its own service account with exactly the roles it
  needs (project-scoped or organization-scoped).
- **No provider configuration in backplane**: The backplane module does not include a `provider.tf`.
  Authentication for the backplane itself is configured by the caller (e.g. the platform team running
  `tofu apply` or the integration runtime).
- **Sensitive by default**: The `service_account_key_json` output is marked `sensitive = true`.
  meshStack's STATIC input wiring uses the `sensitive.argument.secret_value` field to ensure the
  key is stored and transmitted as a secret.

<!-- scorecard-checks: stackit_uses_service_account_key -->
## Implementation Pattern

```hcl
# backplane/main.tf — service account + key + role assignments

resource "stackit_service_account" "backplane" {
  project_id = var.project_id
  name       = "mesh-<service-name>"
}

resource "stackit_service_account_key" "backplane" {
  project_id            = var.project_id
  service_account_email = stackit_service_account.backplane.email
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

<!-- scorecard-checks: stackit_service_account_key_output -->
## Backplane Outputs (STACKIT)

Every STACKIT backplane must output the service account key JSON:

```hcl
output "service_account_key_json" {
  value       = stackit_service_account_key.backplane.json
  description = "Service account key JSON for authenticating the STACKIT provider in the buildingblock."
  sensitive   = true
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
```

Backplanes that manage organization-level resources also require:

```hcl
variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID where the service account will be granted permissions."
}
```

<!-- scorecard-checks: stackit_provider_uses_key -->
## Buildingblock Provider Configuration

The buildingblock `provider.tf` must use `service_account_key` for authentication.
Do **not** use `service_account_email` alone — it does not authenticate.

```hcl
# buildingblock/provider.tf
provider "stackit" {
  service_account_key = var.service_account_key_json
  # Add any extra provider flags required by the resources (e.g. enable_beta_resources, experiments):
  # enable_beta_resources = true
  # experiments           = ["some-feature"]
}
```

## Buildingblock Variable

```hcl
variable "service_account_key_json" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Service account key JSON for authenticating the STACKIT provider."
}
```

The key JSON bundles the service account email — do **not** add a separate `service_account_email`
variable when `service_account_key_json` is present.

## `meshstack_integration.tf` Wiring (STACKIT)

Pass the key from the backplane as a **STATIC sensitive** input:

```hcl
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/<service>/backplane?ref=${var.hub.git_ref}"

  project_id      = var.stackit_project_id
  # organization_id = var.stackit_organization_id   # if org-scoped roles are needed
}

# Inside meshstack_backplane_definition version_spec.inputs:
service_account_key_json = {
  display_name    = "Service Account Key JSON"
  description     = "Service account key JSON for authenticating the STACKIT provider."
  type            = "STRING"
  assignment_type = "STATIC"
  sensitive = {
    argument = {
      secret_value = module.backplane.service_account_key_json
    }
  }
}
```

## What to Avoid

- ❌ `service_account_email` alone in the provider — missing authentication credential
- ❌ Long-lived `STACKIT_SERVICE_ACCOUNT_TOKEN` injected via env var — not reproducible across runs
- ❌ Hardcoded key values in integration files
- ❌ Non-sensitive output for `service_account_key_json` — always mark it `sensitive = true`

## Checklist for STACKIT Backplanes

- [ ] `stackit_service_account` resource present
- [ ] `stackit_service_account_key` resource present (same project as the service account)
- [ ] Required role assignments present (`stackit_authorization_project_role_assignment` or `stackit_authorization_organization_role_assignment`)
- [ ] `service_account_key_json` output marked `sensitive = true`
- [ ] Buildingblock `provider.tf` uses `service_account_key = var.service_account_key_json`
- [ ] Buildingblock `variables.tf` has `service_account_key_json` (sensitive, nullable = false)
- [ ] No separate `service_account_email` variable in buildingblock when key is present
- [ ] `meshstack_integration.tf` wires key via `sensitive.argument.secret_value`
