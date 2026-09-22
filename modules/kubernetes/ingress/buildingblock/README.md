---
name: Kubernetes Ingress
supportedPlatforms:
  - kubernetes
description: Installs cert-manager, the HAProxy ingress controller, a Let's Encrypt ClusterIssuer and an optional DNS-01 wildcard certificate on any conformant Kubernetes cluster.
# Everything this module needs arrives as inputs — the cluster kubeconfig and an ACME contact
# address — so there is nothing to set up cloud-side beforehand.
requiresBackplane: false
---

# Kubernetes Ingress Building Block

Turns a bare Kubernetes cluster into one that serves HTTPS: **cert-manager**, the **HAProxy ingress
controller** behind a cloud LoadBalancer, a Let's Encrypt **ClusterIssuer**, and — when a DNS-01
credential is supplied — a **wildcard Certificate** that HAProxy serves as its default TLS
certificate.

Nothing here is cloud-specific. It runs on SKE, AKS, EKS or a cluster of your own; only the
LoadBalancer annotations differ, and those are an input.

## Why it is one module and not four

The wildcard certificate and HAProxy's `defaultTLSSecret` are a single decision: the certificate is
worth issuing only because HAProxy serves it, and HAProxy can only serve it if it is issued into the
controller's own namespace. Splitting them would mean two building blocks that are never useful
apart, wired by a secret name each has to agree on. The ClusterIssuer belongs with cert-manager for
the same reason.

## Layout

```
buildingblock/
├── ingress/     the whole implementation, with NO provider block
└── *.tf         a thin root that configures kubernetes + helm from var.kubeconfig
```

`ingress/` declares only `required_providers`. That is what lets a composition call it with
`count`, `for_each` or `depends_on`, and lets a caller that already holds cluster credentials
configure the providers itself — neither is possible for a module that carries its own `provider`
block. The root exists so meshStack can run the same code as an ordered building block, taking the
credentials as a kubeconfig input.

## The ClusterIssuer is rendered by Helm, not by `kubernetes_manifest`

The ClusterIssuer and the wildcard Certificate are cert-manager custom resources, so their CRDs
only exist once cert-manager is installed. `kubernetes_manifest` looks a resource's schema up at
**plan** time, which cannot work in the same run that installs the CRD — that is why foundations
used to run the ClusterIssuer as a separate Terraform unit, and why this hub had a separate
`ske/cluster-issuer` building block. Helm renders and applies manifests without any plan-time
schema lookup, so an inline chart (`chart = path.module`, with `templates/`) collapses the two runs
back into one.

## DNS-01 is supported but unused here for now

Passing `dns01` switches the ClusterIssuer to a DNS-01 solver (STACKIT or Route53) and issues the
wildcard certificate. It is left unset by the **STACKIT Kubernetes Platform** reference
architecture, because that branch carries no DNS module yet, so certificates are issued per
hostname over HTTP-01. The capability is intact — wire a zone and a credential into `dns01` and the
wildcard appears.

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
| <a name="module_ingress"></a> [ingress](#module\_ingress) | ./ingress | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acme_email"></a> [acme\_email](#input\_acme\_email) | Contact address Let's Encrypt uses for expiry warnings and account recovery. | `string` | n/a | yes |
| <a name="input_acme_private_key_secret_name"></a> [acme\_private\_key\_secret\_name](#input\_acme\_private\_key\_secret\_name) | Name of the secret in which cert-manager stores the ACME account private key. | `string` | `"letsencrypt-prod-account-key"` | no |
| <a name="input_acme_server"></a> [acme\_server](#input\_acme\_server) | ACME directory URL. Point this at the staging endpoint while testing, because production has strict rate limits. | `string` | `"https://acme-v02.api.letsencrypt.org/directory"` | no |
| <a name="input_cert_manager_cainjector_resources"></a> [cert\_manager\_cainjector\_resources](#input\_cert\_manager\_cainjector\_resources) | Resource requests and limits of the cert-manager cainjector. Sized for a demonstration cluster; its memory grows with the number of Secrets in the cluster. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_crds_keep"></a> [cert\_manager\_crds\_keep](#input\_cert\_manager\_crds\_keep) | Keep the cert-manager CRDs when the Helm release is destroyed. | `bool` | `false` | no |
| <a name="input_cert_manager_extra_args"></a> [cert\_manager\_extra\_args](#input\_cert\_manager\_extra\_args) | Extra command line arguments for the cert-manager controller. The default cuts the retry backoff for failed certificate requests from 1h to 1m. | `list(string)` | <pre>[<br/>  "--certificate-request-minimum-backoff-duration=1m"<br/>]</pre> | no |
| <a name="input_cert_manager_namespace"></a> [cert\_manager\_namespace](#input\_cert\_manager\_namespace) | Namespace for cert-manager and, when DNS-01 runs through STACKIT, for the STACKIT cert-manager webhook. | `string` | `"cert-manager"` | no |
| <a name="input_cert_manager_resources"></a> [cert\_manager\_resources](#input\_cert\_manager\_resources) | Resource requests and limits of the cert-manager controller. Sized for a demonstration cluster; see `ingress/variables.tf` for what production wants. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_startupapicheck_resources"></a> [cert\_manager\_startupapicheck\_resources](#input\_cert\_manager\_startupapicheck\_resources) | Resource requests and limits of the cert-manager startupapicheck Job, which runs once per install and exits. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "32Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of the cert-manager Helm chart. See https://github.com/cert-manager/cert-manager/releases. | `string` | `"v1.20.0"` | no |
| <a name="input_cert_manager_webhook_resources"></a> [cert\_manager\_webhook\_resources](#input\_cert\_manager\_webhook\_resources) | Resource requests and limits of the cert-manager admission webhook. Sized for a demonstration cluster. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "32Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_issuer_name"></a> [cluster\_issuer\_name](#input\_cluster\_issuer\_name) | Name of the ClusterIssuer. Application teams reference it from the cert-manager.io/cluster-issuer annotation on their Ingress. | `string` | `"letsencrypt-prod"` | no |
| <a name="input_dns01"></a> [dns01](#input\_dns01) | Enables a wildcard certificate via DNS-01. Set exactly one provider. Null keeps HTTP-01<br/>per-hostname issuance, which needs no DNS credential and is what the STACKIT Kubernetes Platform<br/>reference architecture uses today. The submodule validates the object; see `ingress/variables.tf`. | <pre>object({<br/>    zone_name          = string<br/>    certificate_domain = optional(string)<br/>    stackit            = optional(object({ project_id = string, service_account_key = string }))<br/>    route53            = optional(object({ hosted_zone_id = string, access_key_id = string, secret_access_key = string, region = optional(string, "eu-central-1") }))<br/>  })</pre> | `null` | no |
| <a name="input_haproxy_crdjob_resources"></a> [haproxy\_crdjob\_resources](#input\_haproxy\_crdjob\_resources) | Resource requests and limits of the Job the HAProxy chart runs to install its CRDs. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "50m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_haproxy_namespace"></a> [haproxy\_namespace](#input\_haproxy\_namespace) | Namespace for the HAProxy ingress controller. The wildcard certificate is created here too, so its secret survives the teardown of any application namespace. | `string` | `"haproxy-ingress"` | no |
| <a name="input_haproxy_release_name"></a> [haproxy\_release\_name](#input\_haproxy\_release\_name) | Helm release name of the HAProxy ingress controller. The chart names the controller Service '<release>-kubernetes-ingress'. | `string` | `"haproxy"` | no |
| <a name="input_haproxy_replica_count"></a> [haproxy\_replica\_count](#input\_haproxy\_replica\_count) | Number of HAProxy ingress controller replicas. The default of 1 gives no redundancy: every restart or node drain interrupts ingress traffic. Production wants at least 2. | `number` | `1` | no |
| <a name="input_haproxy_resources"></a> [haproxy\_resources](#input\_haproxy\_resources) | Resource requests and limits of the HAProxy ingress controller. The memory limit must stay above ~500Mi or HAProxy reloads in a loop; see `ingress/variables.tf`. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "500m",<br/>    "memory": "768Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "100m",<br/>    "memory": "256Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_haproxy_service_annotations"></a> [haproxy\_service\_annotations](#input\_haproxy\_service\_annotations) | Annotations on the HAProxy controller Service. The cloud provider reads them to configure the load balancer — e.g. `lb.stackit.cloud/internal-lb` on STACKIT. | `map(string)` | `{}` | no |
| <a name="input_haproxy_service_type"></a> [haproxy\_service\_type](#input\_haproxy\_service\_type) | Service type of the HAProxy ingress controller. The chart's own default is NodePort, which gives no public address at all. | `string` | `"LoadBalancer"` | no |
| <a name="input_haproxy_timeout"></a> [haproxy\_timeout](#input\_haproxy\_timeout) | Seconds to wait for the HAProxy Helm release to become ready. The default of 20 minutes covers the time a cloud provider takes to provision the load balancer. | `number` | `1200` | no |
| <a name="input_haproxy_version"></a> [haproxy\_version](#input\_haproxy\_version) | Version of the haproxytech/kubernetes-ingress Helm chart. | `string` | `"1.49.0"` | no |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | Name of the IngressClass the controller serves. The HTTP-01 solver of the ClusterIssuer uses the same name. | `string` | `"haproxy"` | no |
| <a name="input_kubeconfig"></a> [kubeconfig](#input\_kubeconfig) | Raw kubeconfig (YAML) of the cluster this runs against — for example the `kubeconfig` output of the STACKIT SKE Cluster building block. The kubernetes and helm providers are configured from it, so it must be a concrete value at plan time (i.e. supplied by a preceding building block, not created in this run). | `string` | n/a | yes |
| <a name="input_stackit_webhook_resources"></a> [stackit\_webhook\_resources](#input\_stackit\_webhook\_resources) | Resource requests and limits of the STACKIT cert-manager webhook. Only used when dns01.stackit is set. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_stackit_webhook_version"></a> [stackit\_webhook\_version](#input\_stackit\_webhook\_version) | Version of the stackit-cert-manager-webhook Helm chart. Must be a version served by the chart index, which lags behind the GitHub release tags. Only used when dns01.stackit is set. | `string` | `"0.4.9"` | no |
| <a name="input_wildcard_certificate_name"></a> [wildcard\_certificate\_name](#input\_wildcard\_certificate\_name) | Name of the wildcard Certificate and of the secret it writes, both in haproxy\_namespace. Only used when dns01 is set. | `string` | `"wildcard-tls"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_issuer_name"></a> [cluster\_issuer\_name](#output\_cluster\_issuer\_name) | Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress. |
| <a name="output_haproxy_lb_ip"></a> [haproxy\_lb\_ip](#output\_haproxy\_lb\_ip) | External IP of the HAProxy LoadBalancer service. Point application DNS A records here before TLS provisioning can complete. |
| <a name="output_haproxy_namespace"></a> [haproxy\_namespace](#output\_haproxy\_namespace) | Namespace of the HAProxy ingress controller and of the wildcard certificate secret. |
| <a name="output_ingress_class_name"></a> [ingress\_class\_name](#output\_ingress\_class\_name) | Name of the IngressClass an application puts on its Ingress to be served by this controller. |
| <a name="output_wildcard_certificate_domain"></a> [wildcard\_certificate\_domain](#output\_wildcard\_certificate\_domain) | Domain the wildcard certificate covers, so the certificate is issued for `*.<domain>`. Null when dns01 is not set. |
| <a name="output_wildcard_certificate_secret_name"></a> [wildcard\_certificate\_secret\_name](#output\_wildcard\_certificate\_secret\_name) | Name of the secret in haproxy\_namespace holding the wildcard certificate. Null when dns01 is not set. |
<!-- END_TF_DOCS -->
