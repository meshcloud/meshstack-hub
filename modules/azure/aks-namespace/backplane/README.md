# Azure AKS Namespace — Backplane

Creates the identity the **Azure AKS Namespace** building block runs as.

## What it provisions

| Resource | Purpose |
| --- | --- |
| Resource group + user-assigned managed identity | The automation principal. No client secret exists; meshStack's building block runner federates into it. |
| Federated identity credential | Trusts the building block definition's workload identity subject. |
| Custom role (`<name>-deploy`) | Lets the identity read the AKS cluster and fetch the user credentials. |
| `Azure Kubernetes Service RBAC Cluster Admin` | Lets the identity create namespaces, quotas and role bindings. Scoped to the one cluster. |
| `AcrPull` for the kubelet identity (optional) | Set `acr_id` and every namespace's workloads can pull from that registry without an image pull secret. |

## Prerequisites

- The AKS cluster is Entra-integrated and has **Azure RBAC for Kubernetes authorization** enabled
  (`azure_rbac_enabled = true`). `modules/azure/aks` does not set this yet; enable it on the cluster
  before deploying this backplane.
- The cluster's API server is reachable from the building block runner.
