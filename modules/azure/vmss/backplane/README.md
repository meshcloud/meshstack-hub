# Azure Virtual Machine Scale Set — Backplane

Sets up the identity the Azure Virtual Machine Scale Set building block runs with.

## What it provisions

- A resource group named after `var.name`, holding a **user-assigned managed identity**.
- A **federated identity credential** per building block runner subject, and one per trusted
  runner, so runs authenticate through workload identity federation. No client secret exists.
- A custom **deploy role** on `scope`, typically the management group above all landing zones. It
  allows the building block to manage resource groups, network security groups, public IPs, load
  balancers, scale sets and autoscale settings, to cancel a rolling upgrade before it deletes a scale set, and to attach a scale set and a network security
  group to an existing subnet.

## Required permissions to deploy

- `Managed Identity Contributor` on the subscription the identity lives in.
- `User Access Administrator` (or `Owner`) on `scope`, to create the role definition and
  assignment.
