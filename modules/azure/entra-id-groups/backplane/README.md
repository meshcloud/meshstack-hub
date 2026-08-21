# Azure Entra ID Groups — Backplane

This backplane creates the automation identity used to provision Entra security groups for meshStack project roles.

## What it provisions

- **User-Assigned Managed Identity (UAMI)** — the automation principal that runs the building block. No client secrets.
- **Resource Group** — hosts the UAMI in the configured Azure region.
- **Workload Identity Federation credentials** — bind the UAMI to the meshStack replicator's OIDC issuer and subject, enabling secret-free authentication.
- **Microsoft Graph app roles** on the UAMI:
  - `User.Read.All` — look up users by UPN or primary mail address to resolve object IDs for group membership.
  - `Group.ReadWrite.All` — create and manage Entra security groups.
  - `AdministrativeUnit.ReadWrite.All` — add groups to Administrative Units (used when `administrative_unit_id` is supplied at building block runtime).

## Required permissions to deploy

The platform engineer running this backplane needs:

| Permission | Scope | Why |
|---|---|---|
| `Contributor` (or `Managed Identity Contributor` plus resource group creation rights) | Target subscription | Create the resource group, the UAMI, and its federated identity credentials |
| `AppRoleAssignment.ReadWrite.All` + `Application.Read.All` (Microsoft Graph app roles), **or** the `Privileged Role Administrator` Entra role | Tenant | Grant the UAMI the admin-consented Microsoft Graph app roles listed above |

## Operational notes

- The UAMI principal ID maps to a service principal in Entra. Creating the `User.Read.All`,
  `Group.ReadWrite.All`, and `AdministrativeUnit.ReadWrite.All` app role assignments **is** the
  admin consent — there is no separate portal approval step, but the identity running the apply must
  be privileged enough to grant them. Note that `Application Administrator` and
  `Cloud Application Administrator` are **not** sufficient: Entra explicitly excludes Microsoft Graph
  application permissions from what those roles may consent to. Use `Privileged Role Administrator`
  or `Global Administrator`, or an automation principal holding `AppRoleAssignment.ReadWrite.All`.
- No secrets are created; the UAMI authenticates via OIDC token exchange.
- The backplane resource group is named after `var.name` and must be unique within the subscription.
