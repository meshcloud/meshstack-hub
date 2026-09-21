---
name: STACKIT SKE Cluster Issuer
supportedPlatforms:
  - stackit
# No cloud-side setup: authenticates only with the kubeconfig passed in as an input, so there is no
# backplane to deploy.
requiresBackplane: false
description: Installs a Let's Encrypt ClusterIssuer (cert-manager) on an SKE cluster so ingress hosts get automatic TLS certificates.
---

# STACKIT SKE Cluster Issuer Building Block

This building block installs a Let's Encrypt **ClusterIssuer** (cert-manager) on an existing **STACKIT
Kubernetes Engine (SKE)** cluster, so ingress hosts receive automatic TLS certificates.

It is a small, deliberately separate bootstrap block: a `ClusterIssuer` is a cert-manager custom
resource, and Terraform's `kubernetes_manifest` validates that resource's schema against the cluster at
**plan time**. That only works once the cert-manager CRDs already exist — which is why this block runs
in its own apply, *after* the platform-services block has installed cert-manager, rather than next to
it in the same run.

## 🎯 When to use it

Ordered by the **STACKIT Kubernetes Platform** reference architecture after platform-services. It
configures its `kubernetes` provider from a kubeconfig input, so it runs in a separate apply from the
cluster and cert-manager installation.

## 📦 Resources created

- **ClusterIssuer `letsencrypt-prod`** – an ACME issuer using the Let's Encrypt production directory,
  solving HTTP-01 challenges through the ingress class (default `haproxy`).

## 📊 Shared responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Provide the cluster kubeconfig and issuer email | ✅ | ❌ |
| Install and maintain the ClusterIssuer | ✅ | ❌ |
| Request Certificates / annotate Ingresses for TLS | ❌ | ✅ |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_manifest.clusterissuer_letsencrypt_prod](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_issuer_email"></a> [cluster\_issuer\_email](#input\_cluster\_issuer\_email) | Contact email registered with Let's Encrypt for the ACME ClusterIssuer. | `string` | `"ske@meshcloud.io"` | no |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | Ingress class the ACME HTTP-01 solver routes challenges through. | `string` | `"haproxy"` | no |
| <a name="input_kubeconfig"></a> [kubeconfig](#input\_kubeconfig) | Raw kubeconfig (YAML) of the SKE cluster to install the ClusterIssuer on. cert-manager must already be installed on it (its CRDs are looked up at plan time). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_issuer_name"></a> [cluster\_issuer\_name](#output\_cluster\_issuer\_name) | Name of the ACME ClusterIssuer. Application teams put this in the `cert-manager.io/cluster-issuer` annotation on their Ingress to get a certificate. |
<!-- END_TF_DOCS -->
