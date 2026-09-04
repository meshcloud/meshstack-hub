# Azure Landing Zone — Bootstrap Identity

Provisions the privileged identity meshStack runs the **Azure Landing Zone** reference architecture
as. It is sourced from [`../meshstack_integration.tf`](../meshstack_integration.tf) and applied once
by the platform engineer (locally with `az login`, or via an IaC runtime) together with the building
block definition registration.

## What it provisions

- A **User-Assigned Managed Identity** (+ its resource group) in `subscription_id`.
- **Federated identity credentials** binding the identity to the reference architecture's building
  block definition (WIF subjects), so the ordered run authenticates as this identity with no secret.
- **Owner** at `scope` (Azure RBAC) — enough to create management groups beneath it, custom role
  definitions and assignments, resource groups, UAMIs, and the hub vnet/firewall.
- **Microsoft Graph `Application.ReadWrite.All`** (Entra app role) — so the run can create the
  meshStack platform service principals (replicator/metering/[mca]).

## Required permissions to apply this

The identity applying it needs to be **Owner** on `scope` (to grant Owner) and able to **grant
Microsoft Graph app roles** (e.g. Global Administrator or Privileged Role Administrator). This is a
one-time, deliberately privileged platform-bootstrap step.
