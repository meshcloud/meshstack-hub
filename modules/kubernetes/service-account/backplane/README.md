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
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0, < 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role_binding_v1.deployer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_v1.deployer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_secret_v1.deployer_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.deployer](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bind_cluster_wide"></a> [bind\_cluster\_wide](#input\_bind\_cluster\_wide) | Let the deployer create ClusterRoleBindings, which bind a role in every namespace. | `bool` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster and context in the deployer kubeconfig. | `string` | n/a | yes |
| <a name="input_cluster_roles"></a> [cluster\_roles](#input\_cluster\_roles) | ClusterRoles the deployer may bind ordered service accounts to. | `list(string)` | n/a | yes |
| <a name="input_cluster_server"></a> [cluster\_server](#input\_cluster\_server) | API server URL of the cluster the `kubernetes` provider points at, e.g. `https://api.example.com:6443`. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace of the deployer service account and its token secret. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the deployer service account, its token secret, ClusterRole and ClusterRoleBinding. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig (YAML) of the deployer, which the definition creates service accounts with. |
| <a name="output_kubeconfig_version"></a> [kubeconfig\_version](#output\_kubeconfig\_version) | Changes with the deployer token, so the definition picks up a new kubeconfig. |
<!-- END_TF_DOCS -->
