---
name: Kubernetes Ingress with TLS
supportedPlatforms:
  - kubernetes
description: Installs cert-manager, the HAProxy ingress controller and a Let's Encrypt ClusterIssuer so every service in the cluster can get a public HTTPS URL with a valid certificate.
# All credentials — cluster and DNS provider — arrive as inputs, so there is nothing to set up
# on the cloud side.
requiresBackplane: false
---

# Kubernetes Ingress with TLS

This module delivers one capability: **services in the cluster get a public HTTPS URL with a valid certificate.** It installs the three pieces that capability needs, in one Terraform run:

1. **cert-manager** — requests and renews certificates from Let's Encrypt.
2. **HAProxy ingress controller** — terminates TLS and routes traffic to Services, behind a cloud load balancer.
3. **A Let's Encrypt ClusterIssuer** — the issuer application teams reference from their Ingress objects.

This documentation is intended as a reference for cloud foundation or platform engineers using this module.

## Why the ClusterIssuer runs through a local Helm chart

A `kubernetes_manifest` resource looks the CRD schema up at plan time. cert-manager installs the `ClusterIssuer` CRD, so the schema does not exist yet during the first plan. Foundations worked around this by putting the ClusterIssuer in a second Terragrunt unit that runs after cert-manager.

This module renders the ClusterIssuer through a Helm chart that lives in the module directory itself (`chart = path.module`). Helm applies the manifests at apply time and never asks Terraform for a schema, so cert-manager and the ClusterIssuer fit into a single unit. That is why the module directory carries a `Chart.yaml`, a `templates/` directory and a `.helmignore` that keeps every Terraform artifact out of the packaged chart.

## Two ways to get certificates

**HTTP-01, per hostname (default).** Leave `dns01` unset. cert-manager solves the ACME challenge over the ingress itself, so every hostname an application team asks for gets its own certificate. The hostname has to resolve to the load balancer before issuance can finish.

**DNS-01, one wildcard for the whole zone.** Set `dns01` with a `zone_name` and exactly one provider. The module then creates a single `Certificate` for `*.<zone_name>` in `haproxy_namespace` and points HAProxy's `controller.defaultTLSSecret.secret` at the resulting secret. HAProxy serves that certificate for every host that brings none of its own, so a new application needs no certificate request at all. The certificate lives in the long-lived HAProxy namespace, so tearing an application namespace down never takes it with it. The HTTP-01 solver stays in place next to the DNS-01 one for hostnames outside the zone.

### DNS-01 providers

| Provider | Extra chart | Status |
|---|---|---|
| `stackit` | `stackit-cert-manager-webhook` | Implemented and exercised. |
| `route53` | none — cert-manager solves Route53 natively | Implemented, **not exercised**. |

STACKIT DNS has no built-in cert-manager solver, so the module installs the [stackit-cert-manager-webhook](https://github.com/stackitcloud/stackit-cert-manager-webhook) chart into `cert_manager_namespace` and stores the service account key in the secret the webhook mounts. The ClusterIssuer then calls it with `solverName: stackit` and `groupName: acme.stackit.de`.

The `route53` branch is a documented shape rather than a tested path. AKS foundations still issue per-hostname HTTP-01 certificates today, so nobody has run this branch against a live hosted zone. Treat it as a starting point and verify it before you rely on it.

## What this module replaces

Five foundation units carried copies of the same `certmanager.tf`, `haproxy.tf` and `cluster_issuer.tf`. The copies had drifted:

| | SKE | AKS |
|---|---|---|
| cert-manager version | `v1.20.0` | `v1.19.4` |
| `--certificate-request-minimum-backoff-duration=1m` | present | missing |
| Service annotations | none | Azure health probe path |
| ACME contact | `ske@meshcloud.io` | `platform@likvid-bank.com`, `devops-platform@meshcloud.io` |

The module defaults match the SKE copy, which is the most current one. AKS callers set `haproxy_service_annotations` and get the newer cert-manager and the retry-backoff tuning along the way.

## Notes for platform engineers

- **Providers.** Only `kubernetes` and `helm`. No cloud provider ever enters this module, so it works on SKE, AKS and anything else that speaks the Kubernetes API. Cloud-specific behaviour arrives as strings, mainly through `haproxy_service_annotations`.
- **Sourced, not ordered.** There is no `meshstack_integration.tf` and no `backplane/`. Foundations source `buildingblock/` from a Terragrunt unit, and reference architectures source it from their own building block.
- **Permissions.** The token in `var.token` needs cluster-admin rights, because cert-manager installs CRDs and cluster-scoped RBAC.
- **DNS records.** Point your DNS A record at the `haproxy_lb_ip` output. Nothing can be issued or served before that record resolves.
- **First apply.** HAProxy comes up before the wildcard certificate is issued. Until the secret exists, HAProxy serves its own self-signed certificate for unmatched hosts and picks the real one up as soon as cert-manager writes it.

## Usage

```hcl
module "ingress" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/ingress/buildingblock?ref=main"

  cluster_endpoint       = var.cluster_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  token                  = var.token

  acme_email = "ske@meshcloud.io"

  dns01 = {
    zone_name = "likvid.stackit.run"
    stackit = {
      project_id          = var.stackit_project_id
      service_account_key = var.stackit_service_account_key
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.haproxy](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.issuer](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.stackit_cert_manager_webhook](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_namespace_v1.haproxy_ingress](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.route53_dns01](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.stackit_dns01](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_v1.haproxy_controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/service_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acme_email"></a> [acme\_email](#input\_acme\_email) | Contact address Let's Encrypt uses for expiry warnings and account recovery. | `string` | n/a | yes |
| <a name="input_acme_private_key_secret_name"></a> [acme\_private\_key\_secret\_name](#input\_acme\_private\_key\_secret\_name) | Name of the secret in which cert-manager stores the ACME account private key. | `string` | `"letsencrypt-prod-account-key"` | no |
| <a name="input_acme_server"></a> [acme\_server](#input\_acme\_server) | ACME directory URL. Point this at https://acme-staging-v02.api.letsencrypt.org/directory while you test, because the production endpoint has strict rate limits. | `string` | `"https://acme-v02.api.letsencrypt.org/directory"` | no |
| <a name="input_cert_manager_crds_keep"></a> [cert\_manager\_crds\_keep](#input\_cert\_manager\_crds\_keep) | Keep the cert-manager CRDs when the Helm release is destroyed. Keeping them preserves existing Certificate and ClusterIssuer objects across a reinstall. | `bool` | `false` | no |
| <a name="input_cert_manager_extra_args"></a> [cert\_manager\_extra\_args](#input\_cert\_manager\_extra\_args) | Extra command line arguments for the cert-manager controller. | `list(string)` | <pre>[<br/>  "--certificate-request-minimum-backoff-duration=1m"<br/>]</pre> | no |
| <a name="input_cert_manager_namespace"></a> [cert\_manager\_namespace](#input\_cert\_manager\_namespace) | Namespace for cert-manager and, when DNS-01 runs through STACKIT, for the STACKIT cert-manager webhook. The webhook chart expects both in the same namespace. | `string` | `"cert-manager"` | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of the cert-manager Helm chart. See https://github.com/cert-manager/cert-manager/releases. | `string` | `"v1.20.0"` | no |
| <a name="input_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#input\_cluster\_ca\_certificate) | Cluster CA certificate, base64 encoded. | `string` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | IP address or hostname of the cluster control plane, without the https:// scheme. | `string` | n/a | yes |
| <a name="input_cluster_issuer_name"></a> [cluster\_issuer\_name](#input\_cluster\_issuer\_name) | Name of the ClusterIssuer. Application teams reference it from the cert-manager.io/cluster-issuer annotation on their Ingress. | `string` | `"letsencrypt-prod"` | no |
| <a name="input_dns01"></a> [dns01](#input\_dns01) | Enables a wildcard certificate for zone\_name via DNS-01. Set exactly one provider. Null keeps HTTP-01 per-hostname issuance. | <pre>object({<br/>    zone_name = string<br/>    stackit   = optional(object({ project_id = string, service_account_key = string }))<br/>    route53   = optional(object({ hosted_zone_id = string, access_key_id = string, secret_access_key = string, region = optional(string, "eu-central-1") }))<br/>  })</pre> | `null` | no |
| <a name="input_haproxy_namespace"></a> [haproxy\_namespace](#input\_haproxy\_namespace) | Namespace for the HAProxy ingress controller. The wildcard certificate is created here as well, so its secret survives the teardown of any application namespace. | `string` | `"haproxy-ingress"` | no |
| <a name="input_haproxy_release_name"></a> [haproxy\_release\_name](#input\_haproxy\_release\_name) | Helm release name of the HAProxy ingress controller. The chart names the controller Service '<release>-kubernetes-ingress'. | `string` | `"haproxy"` | no |
| <a name="input_haproxy_replica_count"></a> [haproxy\_replica\_count](#input\_haproxy\_replica\_count) | Number of HAProxy ingress controller replicas. | `number` | `2` | no |
| <a name="input_haproxy_service_annotations"></a> [haproxy\_service\_annotations](#input\_haproxy\_service\_annotations) | Annotations on the HAProxy controller Service. The cloud provider reads them to configure the<br/>load balancer. Two values matter in practice:<br/>- AKS needs `service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path = "/healthz"`.<br/>- STACKIT uses `lb.stackit.cloud/internal-lb` to keep the load balancer off the public internet. | `map(string)` | `{}` | no |
| <a name="input_haproxy_service_type"></a> [haproxy\_service\_type](#input\_haproxy\_service\_type) | Service type of the HAProxy ingress controller. | `string` | `"LoadBalancer"` | no |
| <a name="input_haproxy_timeout"></a> [haproxy\_timeout](#input\_haproxy\_timeout) | Seconds to wait for the HAProxy Helm release to become ready. The default of 20 minutes covers the time a cloud provider takes to provision the load balancer. | `number` | `1200` | no |
| <a name="input_haproxy_version"></a> [haproxy\_version](#input\_haproxy\_version) | Version of the haproxytech/kubernetes-ingress Helm chart. See https://github.com/haproxytech/helm-charts/blob/main/kubernetes-ingress/Chart.yaml. | `string` | `"1.49.0"` | no |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | Name of the IngressClass the controller serves. The HTTP-01 solver of the ClusterIssuer uses the same name. | `string` | `"haproxy"` | no |
| <a name="input_stackit_webhook_version"></a> [stackit\_webhook\_version](#input\_stackit\_webhook\_version) | Version of the stackit-cert-manager-webhook Helm chart. Only used when dns01.stackit is set. See https://github.com/stackitcloud/stackit-cert-manager-webhook. | `string` | `"0.4.10"` | no |
| <a name="input_token"></a> [token](#input\_token) | Token of the service account this module runs as. It needs cluster-admin rights, because cert-manager installs CRDs and cluster-scoped RBAC. | `string` | n/a | yes |
| <a name="input_wildcard_certificate_name"></a> [wildcard\_certificate\_name](#input\_wildcard\_certificate\_name) | Name of the wildcard Certificate and of the secret it writes, both in haproxy\_namespace. Only used when dns01 is set. | `string` | `"wildcard-tls"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_issuer_name"></a> [cluster\_issuer\_name](#output\_cluster\_issuer\_name) | Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress. |
| <a name="output_haproxy_lb_ip"></a> [haproxy\_lb\_ip](#output\_haproxy\_lb\_ip) | External IP of the HAProxy LoadBalancer service. Point your DNS A record here before TLS provisioning can complete. |
| <a name="output_haproxy_namespace"></a> [haproxy\_namespace](#output\_haproxy\_namespace) | Namespace of the HAProxy ingress controller and of the wildcard certificate secret. |
| <a name="output_ingress_class_name"></a> [ingress\_class\_name](#output\_ingress\_class\_name) | Name of the IngressClass an application puts on its Ingress to be served by this controller. |
| <a name="output_wildcard_certificate_secret_name"></a> [wildcard\_certificate\_secret\_name](#output\_wildcard\_certificate\_secret\_name) | Name of the secret in haproxy\_namespace holding the wildcard certificate. Null when dns01 is not set. |
<!-- END_TF_DOCS -->
