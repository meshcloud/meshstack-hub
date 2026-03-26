# Kubernetes Manifest Backplane

Creates a namespace-scoped service account for the manifest building block and
outputs a kubeconfig restricted to that service account. This avoids passing
full cluster-admin credentials into the building block run.

## What it provisions

- **ServiceAccount** (`meshstack-manifest-bb` by default) in the target namespace
- **Long-lived token Secret** bound to the service account
- **RoleBinding** granting the `edit` ClusterRole scoped to the namespace

## Outputs

| Output | Description |
|---|---|
| `kubeconfig` | Scoped kubeconfig (sensitive) — use as the `kubeconfig.yaml` static FILE input on the manifest building block definition |
