# Kubernetes GitHub Actions Connector — Backplane

Sets up the resources used by the connector building block on one Kubernetes cluster.

## What it provisions

- A namespace (`meshstack-github-connector` by default) holding a service account and its
  long-lived token secret.
- A cluster role that lets the service account manage service accounts, secrets and role bindings.
- A cluster role binding for this service account/role.
- A `ValidatingAdmissionPolicy` and binding that reject every create, update or delete by the
  service account outside namespaces labeled `io.meshcloud/meshstack.managed-entity=true`, which
  is the label meshStack puts on the namespaces it manages.

## Security model

RBAC cannot select namespaces by label, so the cluster role applies everywhere. Two measures confine
it:

- **Writes** are limited to managed namespaces by the admission policy. The run cannot create service
  accounts, secrets or role bindings in `kube-system` or other namespaces that are not managed by meshStack.
- **Reads** cannot be limited by admission. The cluster role therefore grants only `get` permissions.
  The run can read a secret whose name it knows, but cannot enumerate the secrets of the cluster.

The `kubernetes_api` output carries the API server URL, the CA bundle and the token. The
integration module passes it to the building block definition as a sensitive static input.

## Requirements

- Kubernetes 1.30 or later, for `ValidatingAdmissionPolicy`.
- The calling configuration configures the `kubernetes` provider for the cluster with a
  `cluster-admin` identity. The backplane declares no provider of its own. The policy binding is a
  `kubernetes_manifest`, so the cluster must be reachable at plan time.
- The API server is reachable from the meshStack building block runner and from the GitHub Actions
  runners that deploy.

## GitHub App

The building block authenticates to GitHub as a GitHub App. GitHub has no API for creating Apps,
so the backplane cannot provision it. We recommend creating a dedicated app for this building block
so you can minimize the required permissions.

Create it under the organization's **Settings → Developer settings → GitHub Apps → New GitHub App**:

| Setting | Value |
|---|---|
| Webhook | inactive |
| Repository permissions → Administration | Read and write — create the environment |
| Repository permissions → Environments | Read and write — the environment's secret and variable |
| Repository permissions → Actions | Read-only — read the environment |
| Repository permissions → Metadata | Read-only (mandatory) |
| All other permissions | No access |
| Where can this GitHub App be installed? | Only on this account |

Install it in your organization with access to **All repositories**, so that new repositories
created by the `github/repository` building block are covered without a manual step. If you
select **Only select repositories** instead, any allowed repositories must be added manually.

Generate a private key and pass the App ID, the installation ID (the number at the end of the
installation's settings URL) and the key as `github_app_id`, `github_app_installation_id` and
`github_app_private_key` to the integration.

## Operational notes

- The token never expires. Rotate it by tainting `kubernetes_secret_v1.connector_token` and applying
  the integration again, which re-uploads it to the building block definition.
- Set `api_server_ca_certificate` when the API server presents a certificate from another CA than
  the cluster's own, for example a publicly trusted one.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role_binding_v1.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_v1.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_manifest.managed_namespaces_only_binding](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace_v1.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.connector_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [kubernetes_validating_admission_policy_v1.managed_namespaces_only](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/validating_admission_policy_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_server_ca_certificate"></a> [api\_server\_ca\_certificate](#input\_api\_server\_ca\_certificate) | PEM CA bundle that verifies the API server. Defaults to the cluster CA. Set it when the API server presents a certificate signed by another CA. | `string` | `null` | no |
| <a name="input_api_server_url"></a> [api\_server\_url](#input\_api\_server\_url) | URL of the Kubernetes API server that building block runs and GitHub Actions connect to (example: `https://api.k8s.example.com:6443`). | `string` | n/a | yes |
| <a name="input_managed_namespace_label"></a> [managed\_namespace\_label](#input\_managed\_namespace\_label) | Label the meshStack replicator sets to `true` on managed namespaces. The building block may only change objects in namespaces carrying it. | `string` | `"io.meshcloud/meshstack.managed-entity"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace the backplane creates for the building block's service account. | `string` | `"meshstack-github-connector"` | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the connector's service account. Its other resources derive their names from it. | `string` | `"meshstack-github-connector"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kubernetes_api"></a> [kubernetes\_api](#output\_kubernetes\_api) | Kubernetes API connection data. |
<!-- END_TF_DOCS -->
