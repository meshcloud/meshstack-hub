---
name: Kubernetes Ingress Controller
supportedPlatforms:
  - kubernetes
description: Installs cert-manager, the HAProxy ingress controller and a Let's Encrypt ClusterIssuer on any conformant Kubernetes cluster.
# Everything this module needs arrives as inputs — the cluster kubeconfig and an ACME contact
# address — so there is nothing to set up cloud-side beforehand.
requiresBackplane: false
---

# Kubernetes Ingress Controller Building Block

Installs **cert-manager**, the **HAProxy ingress controller** behind a cloud LoadBalancer and a
Let's Encrypt **ClusterIssuer** on any Kubernetes cluster. Only the LoadBalancer annotations are
cloud-specific, and they are an input: AKS needs
`service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path = "/healthz"`, and on
STACKIT `lb.stackit.cloud/internal-lb` keeps the load balancer internal.

A platform team adds the block through a landing zone or a composition and passes the cluster's
`kubeconfig.yaml` as a sensitive FILE input. Application teams deploy their `Ingress` with the
`kubernetes/manifest` building block.

## The ClusterIssuer is rendered by Helm

The ClusterIssuer's CRD only exists once cert-manager is installed, and `kubernetes_manifest` needs
the schema at plan time. An inline Helm chart (`chart/`) has no such lookup, so one run installs
both.

## A wildcard certificate over DNS-01

With `dns01`, the ClusterIssuer solves challenges for `domain` with the given cert-manager `dns01`
solver, and the certificate `*.<domain>` becomes HAProxy's default certificate, shared by every
Ingress under the domain. cert-manager then runs without ingress-shim, so a
`cert-manager.io/cluster-issuer` annotation creates no certificate of its own. The solver's
credential and webhook come from elsewhere, for example `stackit/dns`; on AKS or EKS the built-in
`azureDNS` or `route53` solver can use workload identity.

## Sizing for production

The resource defaults fit a demonstration cluster. A production cluster wants:

| Component | Production value | Why |
|---|---|---|
| HAProxy controller | `1Gi` to `2Gi` memory limit, at least 2 replicas | HAProxy gets two thirds of the memory limit and reloads in a loop below `500Mi` (haproxytech/kubernetes-ingress issue #799) |
| cert-manager controller | `100m` CPU, `512Mi` memory | its informer caches grow with Certificates, Secrets and Ingresses |
| cert-manager webhook | `100m` CPU, `256Mi` memory | every apply of a Certificate or Issuer goes through it |
| cert-manager cainjector | `512Mi` memory or more, with `--namespace` | it watches every Secret in the cluster (cert-manager issue #6217) |

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
| [terraform_data.kubeconfig](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [kubernetes_resource.wildcard_certificate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/resource) | data source |
| [kubernetes_service_v1.haproxy_controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/service_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acme_email"></a> [acme\_email](#input\_acme\_email) | Contact address Let's Encrypt uses for expiry warnings and account recovery. | `string` | n/a | yes |
| <a name="input_acme_private_key_secret_name"></a> [acme\_private\_key\_secret\_name](#input\_acme\_private\_key\_secret\_name) | Name of the secret in which cert-manager stores the ACME account private key. Null names it after the Let's Encrypt environment. | `string` | `null` | no |
| <a name="input_cert_manager_cainjector_resources"></a> [cert\_manager\_cainjector\_resources](#input\_cert\_manager\_cainjector\_resources) | Resource requests and limits of the cert-manager cainjector. The default fits a demonstration cluster; the README lists production values. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_crds_keep"></a> [cert\_manager\_crds\_keep](#input\_cert\_manager\_crds\_keep) | Keep the cert-manager CRDs, and with them every Certificate and ClusterIssuer, when the release is destroyed. | `bool` | `false` | no |
| <a name="input_cert_manager_extra_args"></a> [cert\_manager\_extra\_args](#input\_cert\_manager\_extra\_args) | Extra command line arguments for the cert-manager controller. | `list(string)` | <pre>[<br/>  "--certificate-request-minimum-backoff-duration=1m"<br/>]</pre> | no |
| <a name="input_cert_manager_namespace"></a> [cert\_manager\_namespace](#input\_cert\_manager\_namespace) | Namespace of cert-manager. | `string` | `"cert-manager"` | no |
| <a name="input_cert_manager_resources"></a> [cert\_manager\_resources](#input\_cert\_manager\_resources) | Resource requests and limits of the cert-manager controller. The default fits a demonstration cluster; the README lists production values. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_startupapicheck_resources"></a> [cert\_manager\_startupapicheck\_resources](#input\_cert\_manager\_startupapicheck\_resources) | Resource requests and limits of the cert-manager startupapicheck Job. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "32Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_webhook_resources"></a> [cert\_manager\_webhook\_resources](#input\_cert\_manager\_webhook\_resources) | Resource requests and limits of the cert-manager admission webhook. The default fits a demonstration cluster; the README lists production values. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "32Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_issuer_name"></a> [cluster\_issuer\_name](#input\_cluster\_issuer\_name) | Name of the ClusterIssuer that application teams set in the `cert-manager.io/cluster-issuer` annotation. | `string` | n/a | yes |
| <a name="input_dns01"></a> [dns01](#input\_dns01) | If null, cert-manager issues one certificate per Ingress over HTTP-01. If set, it issues the wildcard certificate `*.<domain>` over DNS-01 with `solver`, the `dns01` block of a cert-manager ACME solver, and HAProxy serves it as its default certificate to every Ingress. | <pre>object({<br/>    domain = string<br/>    solver = any<br/>  })</pre> | `null` | no |
| <a name="input_haproxy_crdjob_resources"></a> [haproxy\_crdjob\_resources](#input\_haproxy\_crdjob\_resources) | Resource requests and limits of the Job that installs the HAProxy CRDs. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "32Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_haproxy_namespace"></a> [haproxy\_namespace](#input\_haproxy\_namespace) | Namespace of the HAProxy ingress controller and of the wildcard certificate. | `string` | `"haproxy-ingress"` | no |
| <a name="input_haproxy_release_name"></a> [haproxy\_release\_name](#input\_haproxy\_release\_name) | Helm release name of the HAProxy ingress controller. | `string` | `"haproxy"` | no |
| <a name="input_haproxy_replica_count"></a> [haproxy\_replica\_count](#input\_haproxy\_replica\_count) | Number of HAProxy ingress controller replicas; production wants at least 2. | `number` | n/a | yes |
| <a name="input_haproxy_resources"></a> [haproxy\_resources](#input\_haproxy\_resources) | Resource requests and limits of the HAProxy ingress controller. The default fits a demonstration cluster; the README lists production values. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "500m",<br/>    "memory": "768Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "20m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_haproxy_service_annotations"></a> [haproxy\_service\_annotations](#input\_haproxy\_service\_annotations) | Annotations on the HAProxy controller Service that configure the cloud load balancer; the README lists the common ones. | `map(string)` | n/a | yes |
| <a name="input_haproxy_service_type"></a> [haproxy\_service\_type](#input\_haproxy\_service\_type) | Service type of the HAProxy ingress controller. | `string` | `"LoadBalancer"` | no |
| <a name="input_haproxy_timeout"></a> [haproxy\_timeout](#input\_haproxy\_timeout) | Seconds to wait for the HAProxy release, including its cloud load balancer, to become ready. | `number` | `1200` | no |
| <a name="input_imports"></a> [imports](#input\_imports) | Set to `{}` to take over the namespaces, Helm releases and ClusterIssuer of an existing installation. | `object({})` | `null` | no |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | Name of the IngressClass the controller serves and the HTTP-01 solver uses. | `string` | n/a | yes |
| <a name="input_release_on_destroy"></a> [release\_on\_destroy](#input\_release\_on\_destroy) | Leave the namespaces and Helm releases in place on destroy. Cannot change once they are managed. | `bool` | n/a | yes |
| <a name="input_use_letsencrypt_staging"></a> [use\_letsencrypt\_staging](#input\_use\_letsencrypt\_staging) | Issue from Let's Encrypt staging, for development and testing. No browser trusts its certificates. | `bool` | `false` | no |
| <a name="input_wildcard_certificate_name"></a> [wildcard\_certificate\_name](#input\_wildcard\_certificate\_name) | Name of the wildcard Certificate and its secret in `haproxy_namespace`; used with `dns01`. | `string` | `"wildcard-tls"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_issuer_name"></a> [cluster\_issuer\_name](#output\_cluster\_issuer\_name) | Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress. |
| <a name="output_haproxy_lb_ip"></a> [haproxy\_lb\_ip](#output\_haproxy\_lb\_ip) | External IP of the HAProxy LoadBalancer service. Point application DNS A records here before TLS provisioning can complete. |
| <a name="output_haproxy_namespace"></a> [haproxy\_namespace](#output\_haproxy\_namespace) | Namespace of the HAProxy ingress controller and of the wildcard certificate. |
| <a name="output_ingress_class_name"></a> [ingress\_class\_name](#output\_ingress\_class\_name) | Name of the IngressClass an application puts on its Ingress to be served by this controller. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown on the building block. |
| <a name="output_wildcard_certificate_domain"></a> [wildcard\_certificate\_domain](#output\_wildcard\_certificate\_domain) | Domain the wildcard certificate `*.<domain>` covers; null without `dns01`. |
<!-- END_TF_DOCS -->
