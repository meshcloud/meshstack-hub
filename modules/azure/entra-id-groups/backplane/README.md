# Azure Entra ID Groups — Backplane

This backplane creates the automation identity used to provision Entra security groups for meshStack project roles.

## What it provisions

- **Resource Group** — hosts the UAMI in the configured Azure region.
- **User-Assigned Managed Identity (UAMI)** — the automation principal that runs the building block. No client secrets.
- **Workload Identity Federation credentials** — bind the UAMI to the meshStack replicator's OIDC issuer and subject, enabling secret-free authentication.
- **Microsoft Graph app roles** on the UAMI:
  - `Group.ReadWrite.All` — create and manage Entra security groups.
  - `AdministrativeUnit.ReadWrite.All` — add groups to Administrative Units (used when `administrative_unit_id` is supplied at building block runtime).

## Required permissions to deploy

The platform engineer running this backplane needs:

| Permission | Scope | Why |
|---|---|---|
| `Managed Identity Contributor` | Target subscription | Create and update the UAMI |
| `Owner` or `User Access Administrator` | `var.scope` | Create role assignments on the UAMI |
| `Privileged Role Administrator` (Entra) | Tenant | Grant admin-consented Microsoft Graph app roles |

## Operational notes

- The UAMI principal ID maps to a service principal in Entra. The `Group.ReadWrite.All` and `AdministrativeUnit.ReadWrite.All` app role assignments require **admin consent** — ensure a Global Administrator or Privileged Role Administrator approves the assignments in the Entra portal after the first `apply`.
- No secrets are created; the UAMI authenticates via OIDC token exchange.
- The backplane resource group is named after `var.name` and must be unique within the subscription.
