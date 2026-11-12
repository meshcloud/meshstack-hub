# Kubernetes Service Account Backplane

Sets up the deployer identity the Kubernetes Service Account building block creates service accounts
with, so the definition never holds an admin kubeconfig.

## What it provisions

- **Deployer service account** (`meshstack-service-account-bb` in `kube-system` by default) with a
  long-lived token secret.
- **ClusterRole and ClusterRoleBinding** that let it manage service accounts, their token secrets and
  role bindings, and `bind` only the ClusterRoles in `cluster_roles`. It gets no `list` or `watch`, so
  it cannot enumerate the secrets of other namespaces, and ClusterRoleBindings only with
  `bind_cluster_wide`.
- **Deployer kubeconfig** as output, which `meshstack_integration.tf` hands to the definition.

## Running it

The caller configures the `kubernetes` provider with an identity that may create service accounts,
secrets, ClusterRoles and ClusterRoleBindings, typically a short-lived cluster admin login such as an
ephemeral kubeconfig of the cloud provider. That login is only used during the apply and is never
passed to meshStack or stored in the Terraform state. Run it from `meshstack_integration.tf`.

Applying again after deleting the token secret rotates the deployer token and sends the new
kubeconfig to meshStack.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
