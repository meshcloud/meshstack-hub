---
name: Kubernetes Ingress
supportedPlatforms:
  - kubernetes
description: Installs cert-manager, the HAProxy ingress controller and a Let's Encrypt ClusterIssuer on any conformant Kubernetes cluster.
# Everything this module needs arrives as inputs — the cluster kubeconfig and an ACME contact
# address — so there is nothing to set up cloud-side beforehand.
requiresBackplane: false
---

# Kubernetes Ingress Building Block

Turns a bare Kubernetes cluster into one that serves HTTPS: **cert-manager**, the **HAProxy ingress
controller** behind a cloud LoadBalancer, a Let's Encrypt **ClusterIssuer**, and — when `dns01` is
set — a **wildcard Certificate** that HAProxy serves as its default TLS certificate.

Nothing here is cloud-specific. It runs on SKE, AKS, EKS or a cluster of your own; only the
LoadBalancer annotations differ, and those are an input. AKS needs
`service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path = "/healthz"`; on STACKIT,
`lb.stackit.cloud/internal-lb` keeps the load balancer off the public internet.

## The kubeconfig is an input of the building block

The block reaches the cluster through `kubeconfig.yaml`, a sensitive FILE input the ordering
composition sets on the building block, so a rotated kubeconfig changes no definition.

## Why it is one module and not four

The wildcard certificate and HAProxy's `defaultTLSSecret` are a single decision: the certificate is
worth issuing only because HAProxy serves it, and HAProxy can only serve it if it is issued into the
controller's own namespace. Splitting them would mean two building blocks that are never useful
apart, wired by a secret name each has to agree on. The ClusterIssuer belongs with cert-manager for
the same reason.

## The ClusterIssuer is rendered by Helm, not by `kubernetes_manifest`

The ClusterIssuer and the wildcard Certificate are cert-manager custom resources, so their CRDs
only exist once cert-manager is installed. `kubernetes_manifest` looks a resource's schema up at
**plan** time, which cannot work in the same run that installs the CRD — that is why foundations
used to run the ClusterIssuer as a separate Terraform unit, and why this hub had a separate
`ske/cluster-issuer` building block. Helm renders and applies manifests without any plan-time
schema lookup, so an inline chart (`chart/`, with its `templates/`) collapses the two runs back into
one.

## Sizing for production

The resource defaults fit a demonstration cluster. A production cluster wants:

| Component | Production value | Why |
|---|---|---|
| HAProxy controller | `1Gi` to `2Gi` memory limit, at least 2 replicas | HAProxy gets two thirds of the memory limit and reloads in a loop below `500Mi` (haproxytech/kubernetes-ingress issue #799) |
| cert-manager controller | `100m` CPU, `512Mi` memory | its informer caches grow with Certificates, Secrets and Ingresses |
| cert-manager webhook | `100m` CPU, `256Mi` memory | every apply of a Certificate or Issuer goes through it |
| cert-manager cainjector | `512Mi` memory or more, with `--namespace` | it watches every Secret in the cluster (cert-manager issue #6217) |
| STACKIT cert-manager webhook | `100m` CPU, `128Mi` memory as the request | the chart's own figures |

## DNS-01 is off in the definition

Setting `dns01` switches the ClusterIssuer to a DNS-01 solver (STACKIT or Route53) and issues the
wildcard certificate. The definition in `meshstack_integration.tf` does not send it, so it stays at
its null default: DNS-01 needs a long-lived credential for the zone inside the cluster, and
`modules/stackit/dns` creates the zone without one, because the architectures using it
authenticate through workload identity federation. Certificates are issued per hostname over
HTTP-01. Wiring DNS-01 in means adding `dns01` as an input of the definition.

## Taking over an installation

With `imports = {}`, the building block takes over the namespaces, the `cert-manager` and HAProxy
Helm releases and the ClusterIssuer of an existing installation. Before the issuer release runs, it
puts Helm's ownership label and annotations on the ClusterIssuer, so the release adopts it. With
`release_on_destroy` set, destroying the building block leaves the namespaces and releases in place.
`release_on_destroy` cannot change once they are managed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cert_manager"></a> [cert\_manager](#module\_cert\_manager) | ./modules/helm-release | n/a |
| <a name="module_cert_manager_namespace"></a> [cert\_manager\_namespace](#module\_cert\_manager\_namespace) | ./modules/namespace | n/a |
| <a name="module_haproxy"></a> [haproxy](#module\_haproxy) | ./modules/helm-release | n/a |
| <a name="module_haproxy_namespace"></a> [haproxy\_namespace](#module\_haproxy\_namespace) | ./modules/namespace | n/a |
| <a name="module_issuer"></a> [issuer](#module\_issuer) | ./modules/helm-release | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.stackit_cert_manager_webhook](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_secret_v1.route53_dns01](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.stackit_dns01](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [terraform_data.kubeconfig](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [kubernetes_service_v1.haproxy_controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/service_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acme_email"></a> [acme\_email](#input\_acme\_email) | Contact address Let's Encrypt uses for expiry warnings and account recovery. | `string` | n/a | yes |
| <a name="input_acme_private_key_secret_name"></a> [acme\_private\_key\_secret\_name](#input\_acme\_private\_key\_secret\_name) | Name of the secret in which cert-manager stores the ACME account private key. | `string` | `"letsencrypt-prod-account-key"` | no |
| <a name="input_acme_server"></a> [acme\_server](#input\_acme\_server) | ACME directory URL; use the Let's Encrypt staging directory while testing. | `string` | n/a | yes |
| <a name="input_cert_manager_cainjector_resources"></a> [cert\_manager\_cainjector\_resources](#input\_cert\_manager\_cainjector\_resources) | Resource requests and limits of the cert-manager cainjector. The default fits a demonstration cluster; the README lists production values. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_crds_keep"></a> [cert\_manager\_crds\_keep](#input\_cert\_manager\_crds\_keep) | Keep the cert-manager CRDs, and with them every Certificate and ClusterIssuer, when the release is destroyed. | `bool` | `false` | no |
| <a name="input_cert_manager_extra_args"></a> [cert\_manager\_extra\_args](#input\_cert\_manager\_extra\_args) | Extra command line arguments for the cert-manager controller. | `list(string)` | <pre>[<br/>  "--certificate-request-minimum-backoff-duration=1m"<br/>]</pre> | no |
| <a name="input_cert_manager_namespace"></a> [cert\_manager\_namespace](#input\_cert\_manager\_namespace) | Namespace of cert-manager and of the STACKIT cert-manager webhook. | `string` | `"cert-manager"` | no |
| <a name="input_cert_manager_resources"></a> [cert\_manager\_resources](#input\_cert\_manager\_resources) | Resource requests and limits of the cert-manager controller. The default fits a demonstration cluster; the README lists production values. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_startupapicheck_resources"></a> [cert\_manager\_startupapicheck\_resources](#input\_cert\_manager\_startupapicheck\_resources) | Resource requests and limits of the cert-manager startupapicheck Job. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "32Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of the cert-manager Helm chart. | `string` | n/a | yes |
| <a name="input_cert_manager_webhook_resources"></a> [cert\_manager\_webhook\_resources](#input\_cert\_manager\_webhook\_resources) | Resource requests and limits of the cert-manager admission webhook. The default fits a demonstration cluster; the README lists production values. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "32Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_issuer_name"></a> [cluster\_issuer\_name](#input\_cluster\_issuer\_name) | Name of the ClusterIssuer that application teams set in the `cert-manager.io/cluster-issuer` annotation. | `string` | n/a | yes |
| <a name="input_dns01"></a> [dns01](#input\_dns01) | DNS-01 solver with exactly one provider, for a wildcard certificate on `certificate_domain` (default `zone_name`, must lie within it). Null issues certificates per hostname over HTTP-01. | <pre>object({<br/>    zone_name          = string<br/>    certificate_domain = optional(string)<br/>    stackit            = optional(object({ project_id = string, service_account_key = string }))<br/>    route53            = optional(object({ hosted_zone_id = string, access_key_id = string, secret_access_key = string, region = optional(string, "eu-central-1") }))<br/>  })</pre> | `null` | no |
| <a name="input_haproxy_crdjob_resources"></a> [haproxy\_crdjob\_resources](#input\_haproxy\_crdjob\_resources) | Resource requests and limits of the Job that installs the HAProxy CRDs. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "50m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_haproxy_namespace"></a> [haproxy\_namespace](#input\_haproxy\_namespace) | Namespace of the HAProxy ingress controller and the wildcard certificate. | `string` | `"haproxy-ingress"` | no |
| <a name="input_haproxy_release_name"></a> [haproxy\_release\_name](#input\_haproxy\_release\_name) | Helm release name of the HAProxy ingress controller. | `string` | `"haproxy"` | no |
| <a name="input_haproxy_replica_count"></a> [haproxy\_replica\_count](#input\_haproxy\_replica\_count) | Number of HAProxy ingress controller replicas; production wants at least 2. | `number` | n/a | yes |
| <a name="input_haproxy_resources"></a> [haproxy\_resources](#input\_haproxy\_resources) | Resource requests and limits of the HAProxy ingress controller. The default fits a demonstration cluster; the README lists production values. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "500m",<br/>    "memory": "768Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "100m",<br/>    "memory": "256Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_haproxy_service_annotations"></a> [haproxy\_service\_annotations](#input\_haproxy\_service\_annotations) | Annotations on the HAProxy controller Service that configure the cloud load balancer; the README lists the common ones. | `map(string)` | n/a | yes |
| <a name="input_haproxy_service_type"></a> [haproxy\_service\_type](#input\_haproxy\_service\_type) | Service type of the HAProxy ingress controller. | `string` | `"LoadBalancer"` | no |
| <a name="input_haproxy_timeout"></a> [haproxy\_timeout](#input\_haproxy\_timeout) | Seconds to wait for the HAProxy release, including its cloud load balancer, to become ready. | `number` | `1200` | no |
| <a name="input_haproxy_version"></a> [haproxy\_version](#input\_haproxy\_version) | Version of the haproxytech/kubernetes-ingress Helm chart. | `string` | n/a | yes |
| <a name="input_imports"></a> [imports](#input\_imports) | Set to `{}` to take over the namespaces, Helm releases and ClusterIssuer of an existing installation. | `object({})` | `null` | no |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | Name of the IngressClass the controller serves and the HTTP-01 solver uses. | `string` | n/a | yes |
| <a name="input_release_on_destroy"></a> [release\_on\_destroy](#input\_release\_on\_destroy) | Leave the namespaces and Helm releases in place on destroy. Cannot change once they are managed. | `bool` | `false` | no |
| <a name="input_stackit_webhook_resources"></a> [stackit\_webhook\_resources](#input\_stackit\_webhook\_resources) | Resource requests and limits of the STACKIT cert-manager webhook, used with `dns01.stackit`. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_stackit_webhook_version"></a> [stackit\_webhook\_version](#input\_stackit\_webhook\_version) | Version of the stackit-cert-manager-webhook chart in https://stackitcloud.github.io/stackit-cert-manager-webhook; used with `dns01.stackit`. | `string` | `"0.4.9"` | no |
| <a name="input_wildcard_certificate_name"></a> [wildcard\_certificate\_name](#input\_wildcard\_certificate\_name) | Name of the wildcard Certificate and its secret in `haproxy_namespace`; used with `dns01`. | `string` | `"wildcard-tls"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_issuer_name"></a> [cluster\_issuer\_name](#output\_cluster\_issuer\_name) | Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress. |
| <a name="output_haproxy_lb_ip"></a> [haproxy\_lb\_ip](#output\_haproxy\_lb\_ip) | External IP of the HAProxy LoadBalancer service. Point application DNS A records here before TLS provisioning can complete. |
| <a name="output_haproxy_namespace"></a> [haproxy\_namespace](#output\_haproxy\_namespace) | Namespace of the HAProxy ingress controller and of the wildcard certificate secret. |
| <a name="output_ingress_class_name"></a> [ingress\_class\_name](#output\_ingress\_class\_name) | Name of the IngressClass an application puts on its Ingress to be served by this controller. |
| <a name="output_wildcard_certificate_domain"></a> [wildcard\_certificate\_domain](#output\_wildcard\_certificate\_domain) | Domain the wildcard certificate `*.<domain>` covers; null without `dns01`. |
| <a name="output_wildcard_certificate_secret_name"></a> [wildcard\_certificate\_secret\_name](#output\_wildcard\_certificate\_secret\_name) | Secret in `haproxy_namespace` holding the wildcard certificate; null without `dns01`. |
<!-- END_TF_DOCS -->
