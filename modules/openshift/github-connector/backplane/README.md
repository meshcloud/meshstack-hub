# OpenShift GitHub Actions Connector — Backplane

Sets up the identity the connector building block runs with on one OpenShift cluster.

## What it provisions

- A namespace (`meshstack-github-connector` by default) holding a service account and its
  long-lived token secret.
- A cluster role that lets the service account manage service accounts, secrets and role bindings,
  and `bind` exactly the `edit` and `system:image-builder` cluster roles — nothing else. The run
  cannot read workloads or grant itself more.
- A cluster role binding for it.

The `kubernetes_api` output carries the API server URL, the CA bundle and the token. The
integration passes it to the building block definition as a sensitive static input.

## Requirements

- The calling configuration configures the `kubernetes` provider for the cluster with a
  `cluster-admin` identity (for example the token of `oc login`). The backplane declares no
  provider of its own.
- The internal image registry is exposed through its default route
  (`oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'`),
  so GitHub Actions can push images to it.

## Operational notes

- The token never expires. Rotate it by tainting `kubernetes_secret.connector_token` and applying
  the integration again, which re-uploads it to the building block definition.
- Set `api_server_ca_certificate` when the API server presents a certificate from another CA than
  the cluster's own, for example a publicly trusted one.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.35.1, < 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_namespace.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.connector_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.connector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_api_server_ca_certificate"></a> [api\_server\_ca\_certificate](#input\_api\_server\_ca\_certificate) | PEM CA bundle that verifies the API server. Defaults to the cluster CA the service account token carries; set it when the API server presents a certificate signed by another CA. | `string` | `null` | no |
| <a name="input_api_server_url"></a> [api\_server\_url](#input\_api\_server\_url) | URL of the OpenShift API server that building block runs and GitHub Actions connect to (example: `https://api.ocp.example.com:6443`). | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace the backplane creates for the building block's service account. | `string` | `"meshstack-github-connector"` | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Name of the service account, cluster role and cluster role binding the building block runs with. | `string` | `"meshstack-github-connector"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kubernetes_api"></a> [kubernetes\_api](#output\_kubernetes\_api) | API server URL, CA bundle and service account token the building block connects with. |
<!-- END_TF_DOCS -->
