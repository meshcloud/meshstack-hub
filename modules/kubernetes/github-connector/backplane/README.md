# Kubernetes GitHub Actions Connector — Backplane

Sets up the identity the connector building block runs with on one Kubernetes cluster.

## What it provisions

- A namespace (`meshstack-github-connector` by default) holding a service account and its
  long-lived token secret.
- A cluster role that lets the service account manage service accounts, secrets and role bindings,
  and `bind` exactly the `edit` cluster role — nothing else. The run cannot read workloads or grant
  itself more.
- A cluster role binding for it.
- A `ValidatingAdmissionPolicy` and its binding that reject every create, update or delete by the
  service account outside namespaces labeled `io.meshcloud/meshstack.managed-entity=true`, the label
  the meshStack replicator puts on tenant namespaces.

## Security model

RBAC cannot select namespaces by label, so the cluster role applies everywhere. Two measures confine
it:

- **Writes** are limited to tenant namespaces by the admission policy. The run cannot create service
  accounts, secrets or role bindings in `kube-system` or any other non-tenant namespace.
- **Reads** cannot be limited by admission. The cluster role therefore grants `get` only, never
  `list` or `watch`: the run can read a secret whose name it knows, but cannot enumerate the
  secrets of the cluster.

Whoever holds the token can still read a secret in any namespace by guessing its name. Treat the
token like the meshStack replicator's: it stays in the building block definition and never reaches
application teams.

The `kubernetes_api` output carries the API server URL, the CA bundle and the token. The
integration passes it to the building block definition as a sensitive static input.

## Requirements

- Kubernetes 1.30 or later, for `ValidatingAdmissionPolicy`.
- The calling configuration configures the `kubernetes` provider for the cluster with a
  `cluster-admin` identity. The backplane declares no provider of its own. The policy binding is a
  `kubernetes_manifest`, so the cluster must be reachable at plan time.
- The API server is reachable from the meshStack building block runner and from the GitHub Actions
  runners that deploy.

## GitHub App

The building block authenticates to GitHub as a GitHub App that the platform team creates for this
connector alone. GitHub has no API for creating Apps, so the backplane cannot provision it. Do not
reuse the App of the `github/repository` building block: every connector run would hold its
Contents and Workflows write on all repositories.

Creating a GitHub environment requires `Administration` write, which also allows deleting the
repository. Install the App only on the repositories it connects when that is a concern.

Create it under the organization's **Settings → Developer settings → GitHub Apps → New GitHub App**:

| Setting | Value |
|---|---|
| Webhook | inactive |
| Repository permissions → Administration | Read and write — create the environment |
| Repository permissions → Environments | Read and write — the environment's secret and variable |
| Repository permissions → Metadata | Read-only (mandatory) |
| All other permissions | No access |
| Where can this GitHub App be installed? | Only on this account |

Install it on the organization with **All repositories**, so that repositories the
`github/repository` building block creates later are covered without a manual step. Choose
**Only select repositories** instead to restrict the connector to an allow list, and add each
repository before connecting it.

Generate a private key and pass the App ID, the installation ID (the number at the end of the
installation's settings URL) and the key as `github_app_id`, `github_app_installation_id` and
`github_app_pem_file` to the integration.

## Operational notes

- The token never expires. Rotate it by tainting `kubernetes_secret_v1.connector_token` and applying
  the integration again, which re-uploads it to the building block definition.
- Set `api_server_ca_certificate` when the API server presents a certificate from another CA than
  the cluster's own, for example a publicly trusted one.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_cluster_role_binding_v1.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_v1.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_manifest.tenant_namespaces_only_binding](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace_v1.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.connector_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [kubernetes_validating_admission_policy_v1.tenant_namespaces_only](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/validating_admission_policy_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_api_server_ca_certificate"></a> [api\_server\_ca\_certificate](#input\_api\_server\_ca\_certificate) | PEM CA bundle that verifies the API server. Defaults to the cluster CA the service account token carries; set it when the API server presents a certificate signed by another CA. | `string` | `null` | no |
| <a name="input_api_server_url"></a> [api\_server\_url](#input\_api\_server\_url) | URL of the Kubernetes API server that building block runs and GitHub Actions connect to (example: `https://api.k8s.example.com:6443`). | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace the backplane creates for the building block's service account. | `string` | `"meshstack-github-connector"` | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account, cluster role and cluster role binding the building block runs with. | `string` | `"meshstack-github-connector"` | no |
| <a name="input_tenant_namespace_label"></a> [tenant\_namespace\_label](#input\_tenant\_namespace\_label) | Label the meshStack replicator sets to `true` on tenant namespaces. The building block may only change objects in namespaces carrying it. | `string` | `"io.meshcloud/meshstack.managed-entity"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_kubernetes_api"></a> [kubernetes\_api](#output\_kubernetes\_api) | API server URL, CA bundle and service account token the building block connects with. |
<!-- END_TF_DOCS -->
