---
name: Custom Platform Metering
supportedPlatforms:
  - kubernetes
description: Sets up the metering of clouds meshStack does not meter natively, such as STACKIT and T Cloud Public, by creating the Platform Metering definition and the definitions it orders.
---

This building block sets up custom metering for a meshStack in one run. It sources these hub
integrations and creates their definitions in the ordering workspace:

- [`kubernetes/service-account`](../../../modules/kubernetes/service-account), with a deployer
  identity on the cluster of the admin kubeconfig.
- [`stackit/metering`](../../../modules/stackit/metering) when STACKIT is switched on, with its
  STACKIT identities.
- [`otc/metering`](../../../modules/otc/metering) when T Cloud Public is switched on.
- [`kubernetes/platform-metering`](../../../modules/kubernetes/platform-metering), the definition
  workspaces order, which offers every cloud that is switched on.

The admin kubeconfig arrives as the file `kubeconfig.yaml`. The run reads the cluster name and API
server URL from it, and the `kubernetes` provider uses it only to create the deployer identity. The
STACKIT service account key configures the `stackit` provider; with STACKIT off the provider gets
placeholders, because OpenTofu configures it even when nothing uses it.
