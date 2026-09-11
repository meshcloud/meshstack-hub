---
name: STACKIT SKE Platform Services
supportedPlatforms:
  - stackit
# No cloud-side setup: authenticates only with the kubeconfig passed in as an input, so there is no
# backplane to deploy.
requiresBackplane: false
description: Installs the in-cluster services that turn an SKE cluster into a meshStack platform — HAProxy ingress, cert-manager, and the meshStack replication/metering service accounts.
---

# STACKIT SKE Platform Services Building Block

This building block installs the in-cluster services that make an existing **STACKIT Kubernetes
Engine (SKE)** cluster usable as a meshStack platform:

- **HAProxy ingress** behind a STACKIT LoadBalancer (exposes its external IP for DNS).
- **cert-manager** plus a Let's Encrypt `ClusterIssuer` for automatic TLS.
- The **meshStack replication and metering service accounts** (via
  `terraform-kubernetes-meshplatform`), whose tokens a composing architecture feeds into its
  `meshstack_platform`.

It configures its `kubernetes`/`helm` providers from a kubeconfig **input**, so it must run in a
separate apply from the one that creates the cluster.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.1.0, < 4.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_meshplatform"></a> [meshplatform](#module\_meshplatform) | git::https://github.com/meshcloud/terraform-kubernetes-meshplatform.git | v0.2.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.haproxy](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_manifest.clusterissuer_letsencrypt_prod](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace_v1.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_namespace_v1.haproxy_ingress](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_service_v1.haproxy_controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/service_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | cert-manager Helm chart version. | `string` | `"v1.20.0"` | no |
| <a name="input_cluster_issuer_email"></a> [cluster\_issuer\_email](#input\_cluster\_issuer\_email) | Contact email registered with Let's Encrypt for the ACME ClusterIssuer. | `string` | `"ske@meshcloud.io"` | no |
| <a name="input_haproxy_replica_count"></a> [haproxy\_replica\_count](#input\_haproxy\_replica\_count) | Number of HAProxy ingress controller replicas. | `number` | `2` | no |
| <a name="input_haproxy_version"></a> [haproxy\_version](#input\_haproxy\_version) | HAProxy Kubernetes Ingress Helm chart version. | `string` | `"1.49.0"` | no |
| <a name="input_kubeconfig"></a> [kubeconfig](#input\_kubeconfig) | Raw kubeconfig (YAML) of the SKE cluster this runs against — the `kubeconfig` output of the STACKIT SKE Cluster building block. The kubernetes and helm providers are configured from it, so it must be a concrete value at plan time (i.e. supplied by a preceding building block, not created in this run). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_haproxy_lb_ip"></a> [haproxy\_lb\_ip](#output\_haproxy\_lb\_ip) | External IP of the HAProxy LoadBalancer service. Point application DNS A records here. |
| <a name="output_metering_token"></a> [metering\_token](#output\_metering\_token) | Service account token meshStack uses to read metering data from the cluster. |
| <a name="output_replicator_token"></a> [replicator\_token](#output\_replicator\_token) | Service account token meshStack uses to replicate namespaces onto the cluster. |
<!-- END_TF_DOCS -->
