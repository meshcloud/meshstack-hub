# AKS Backplane

This module provisions the Azure backplane required for the AKS building block.
It is intended for platform engineers deploying the backplane once per meshStack instance.

## Overview

The backplane creates:
- An **Azure Resource Group** to host the UAMI and its managed resources
- A **User-Assigned Managed Identity (UAMI)** used by meshStack as the automation principal for all AKS building block deployments
- **Federated identity credentials** on the UAMI for meshStack Workload Identity Federation (WIF) — no client secrets are needed or created
- Three **custom RBAC role definitions** with least-privilege permission sets:
  - `<name>-deploy` (landing zone scope) — full AKS lifecycle plus VNet and resource group management
  - `<name>-hub` (hub scope) — VNet peering from landing zone into the hub subscription
  - `<name>-hub-to-lz` (landing zone scope) — allows the hub to peer back to landing zone VNets
- **Role assignments** for all three role definitions, bound to the single UAMI

## Required Permissions

The identity deploying this backplane needs:
- `Managed Identity Contributor` on the target subscription (to create the UAMI)
- `Owner` or `User Access Administrator` on `var.scope` and `var.hub_scope` (to create role definitions and assignments)

No Entra ID application registration permissions are required.

## Variables

| Name | Description |
|------|-------------|
| `name` | Name prefix for all resources. Must match `^[-a-z0-9]+$`. |
| `scope` | Landing zone scope (management group or subscription) for role assignment. |
| `hub_scope` | Hub scope (management group or subscription) for hub VNet peering role assignment. |
| `location` | Azure region for the UAMI resource group. |
| `workload_identity_federation` | WIF issuer URL and list of allowed subjects from meshStack. |

## Outputs

| Name | Description |
|------|-------------|
| `identity.client_id` | Client ID of the UAMI — pass as `ARM_CLIENT_ID` to the buildingblock provider. |
| `identity.principal_id` | Object ID of the UAMI. |
| `identity.tenant_id` | Entra tenant ID. |
