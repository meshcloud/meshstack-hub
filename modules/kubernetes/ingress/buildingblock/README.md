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
LoadBalancer annotations differ, and those are an input.

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

## DNS-01 is off in the definition

Setting `dns01` switches the ClusterIssuer to a DNS-01 solver (STACKIT or Route53) and issues the
wildcard certificate. The definition in `meshstack_integration.tf` does not send it, so it stays at
its null default: DNS-01 needs a long-lived credential for the zone inside the cluster, and
`modules/stackit/dns` creates the zone without one, because the architectures using it
authenticate through workload identity federation. Certificates are issued per hostname over
HTTP-01. Wiring DNS-01 in means adding `dns01` as an input of the definition.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |

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
| <a name="input_acme_server"></a> [acme\_server](#input\_acme\_server) | ACME directory URL. Point this at https://acme-staging-v02.api.letsencrypt.org/directory while you test, because the production endpoint has strict rate limits. | `string` | n/a | yes |
| <a name="input_cert_manager_cainjector_resources"></a> [cert\_manager\_cainjector\_resources](#input\_cert\_manager\_cainjector\_resources) | Resource requests and limits of the cert-manager cainjector. The default is sized for a<br/>demonstration cluster and a production consumer has to raise it.<br/><br/>The cainjector watches every Secret in the cluster, so its memory grows with the number of<br/>Secrets. cert-manager issue #6217 reports it reaching gigabytes on large clusters. The limit<br/>here is `256Mi` because a demonstration cluster holds few Secrets, and a production cluster<br/>wants `512Mi` or more together with the `--namespace` flag that narrows the watch. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_crds_keep"></a> [cert\_manager\_crds\_keep](#input\_cert\_manager\_crds\_keep) | Keep the cert-manager CRDs when the Helm release is destroyed. Keeping them preserves existing Certificate and ClusterIssuer objects across a reinstall. | `bool` | `false` | no |
| <a name="input_cert_manager_extra_args"></a> [cert\_manager\_extra\_args](#input\_cert\_manager\_extra\_args) | Extra command line arguments for the cert-manager controller. | `list(string)` | <pre>[<br/>  "--certificate-request-minimum-backoff-duration=1m"<br/>]</pre> | no |
| <a name="input_cert_manager_namespace"></a> [cert\_manager\_namespace](#input\_cert\_manager\_namespace) | Namespace for cert-manager and, when DNS-01 runs through STACKIT, for the STACKIT cert-manager webhook. The webhook chart expects both in the same namespace. | `string` | `"cert-manager"` | no |
| <a name="input_cert_manager_resources"></a> [cert\_manager\_resources](#input\_cert\_manager\_resources) | Resource requests and limits of the cert-manager controller. The default is sized for a<br/>demonstration cluster and a production consumer has to raise it.<br/><br/>The cert-manager Helm chart sets no resources at all and documents `10m` CPU and `32Mi` memory<br/>as its example request. The memory request here is `64Mi` instead, because the controller keeps<br/>informer caches for Certificates, Secrets and Ingresses and a container that runs out of memory<br/>is OOMKilled rather than slowed down. A cluster that issues certificates continuously wants<br/>`100m` CPU and `512Mi` memory. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_startupapicheck_resources"></a> [cert\_manager\_startupapicheck\_resources](#input\_cert\_manager\_startupapicheck\_resources) | Resource requests and limits of the cert-manager startupapicheck Job. The default is sized for<br/>a demonstration cluster and a production consumer has to raise it.<br/><br/>The Job runs once per install, checks that the webhook answers and then exits, so it never<br/>holds resources for long. Its request still has to fit on a node, which is why it is kept this<br/>small. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "32Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of the cert-manager Helm chart. See https://github.com/cert-manager/cert-manager/releases. | `string` | n/a | yes |
| <a name="input_cert_manager_webhook_resources"></a> [cert\_manager\_webhook\_resources](#input\_cert\_manager\_webhook\_resources) | Resource requests and limits of the cert-manager admission webhook. The default is sized for a<br/>demonstration cluster and a production consumer has to raise it.<br/><br/>The webhook validates cert-manager objects and holds no cache, so it is the smallest of the<br/>three cert-manager pods. Every apply that touches a Certificate or an Issuer goes through it,<br/>so keep the limit above the request. A production cluster wants `100m` CPU and `256Mi` memory. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "32Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_issuer_name"></a> [cluster\_issuer\_name](#input\_cluster\_issuer\_name) | Name of the ClusterIssuer. Application teams reference it from the cert-manager.io/cluster-issuer annotation on their Ingress. | `string` | n/a | yes |
| <a name="input_dns01"></a> [dns01](#input\_dns01) | Enables a wildcard certificate via DNS-01. Set exactly one provider. Null keeps HTTP-01<br/>per-hostname issuance.<br/><br/>`zone_name` is the DNS zone the solver is authorised for, and the ClusterIssuer selects the<br/>solver for every name inside it. `certificate_domain` is the domain the wildcard certificate<br/>covers and defaults to `zone_name`, which gives `*.<zone_name>`. Set it to a name below the<br/>zone, for example `cluster1.likvid.stackit.run` inside the zone `likvid.stackit.run`, to narrow<br/>the certificate to that label while the solver keeps answering for the whole zone. | <pre>object({<br/>    zone_name          = string<br/>    certificate_domain = optional(string)<br/>    stackit            = optional(object({ project_id = string, service_account_key = string }))<br/>    route53            = optional(object({ hosted_zone_id = string, access_key_id = string, secret_access_key = string, region = optional(string, "eu-central-1") }))<br/>  })</pre> | `null` | no |
| <a name="input_haproxy_crdjob_resources"></a> [haproxy\_crdjob\_resources](#input\_haproxy\_crdjob\_resources) | Resource requests and limits of the Job the HAProxy chart runs to install its CRDs. The default<br/>is sized for a demonstration cluster and a production consumer has to raise it.<br/><br/>The chart requests `250m` CPU and `400Mi` memory for this Job. The Job applies a handful of<br/>CRDs and exits, so a much smaller request is enough, and a smaller request also means the Job<br/>still schedules on a small node. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "50m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_haproxy_namespace"></a> [haproxy\_namespace](#input\_haproxy\_namespace) | Namespace for the HAProxy ingress controller. The wildcard certificate is created here as well, so its secret survives the teardown of any application namespace. | `string` | `"haproxy-ingress"` | no |
| <a name="input_haproxy_release_name"></a> [haproxy\_release\_name](#input\_haproxy\_release\_name) | Helm release name of the HAProxy ingress controller. The chart names the controller Service '<release>-kubernetes-ingress'. | `string` | `"haproxy"` | no |
| <a name="input_haproxy_replica_count"></a> [haproxy\_replica\_count](#input\_haproxy\_replica\_count) | Number of HAProxy ingress controller replicas. A value of 1 is sized for a demonstration cluster and gives no redundancy: every restart or node drain interrupts ingress traffic. Production wants at least 2, spread over separate nodes. | `number` | n/a | yes |
| <a name="input_haproxy_resources"></a> [haproxy\_resources](#input\_haproxy\_resources) | Resource requests and limits of the HAProxy ingress controller. The default is sized for a<br/>demonstration cluster and a production consumer has to raise it.<br/><br/>The chart requests `250m` CPU and `400Mi` memory and sets no limit. The pod runs two processes,<br/>HAProxy itself and the Go controller, and the container entrypoint hands HAProxy two thirds of<br/>the cgroup memory limit. Users of this chart version report that HAProxy reloads in a loop<br/>instead of serving traffic when the memory limit stays below `500Mi`, and a maintainer<br/>recommends at least `1Gi` (haproxytech/kubernetes-ingress issue #799). The `768Mi` limit here is<br/>the smallest value that clears that threshold with headroom. Production wants `1Gi` to `2Gi`<br/>and a CPU limit that matches the traffic the controller has to terminate. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "500m",<br/>    "memory": "768Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "100m",<br/>    "memory": "256Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_haproxy_service_annotations"></a> [haproxy\_service\_annotations](#input\_haproxy\_service\_annotations) | Annotations on the HAProxy controller Service. The cloud provider reads them to configure the<br/>load balancer. Two values matter in practice:<br/>- AKS needs `service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path = "/healthz"`.<br/>- STACKIT uses `lb.stackit.cloud/internal-lb` to keep the load balancer off the public internet. | `map(string)` | n/a | yes |
| <a name="input_haproxy_service_type"></a> [haproxy\_service\_type](#input\_haproxy\_service\_type) | Service type of the HAProxy ingress controller. | `string` | `"LoadBalancer"` | no |
| <a name="input_haproxy_timeout"></a> [haproxy\_timeout](#input\_haproxy\_timeout) | Seconds to wait for the HAProxy Helm release to become ready. The default of 20 minutes covers the time a cloud provider takes to provision the load balancer. | `number` | `1200` | no |
| <a name="input_haproxy_version"></a> [haproxy\_version](#input\_haproxy\_version) | Version of the haproxytech/kubernetes-ingress Helm chart. See https://github.com/haproxytech/helm-charts/blob/main/kubernetes-ingress/Chart.yaml. | `string` | n/a | yes |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | Name of the IngressClass the controller serves. The HTTP-01 solver of the ClusterIssuer uses the same name. | `string` | n/a | yes |
| <a name="input_kubeconfig"></a> [kubeconfig](#input\_kubeconfig) | Raw kubeconfig (YAML) of the target cluster, from a preceding building block so it is known at plan time. | `string` | n/a | yes |
| <a name="input_stackit_webhook_resources"></a> [stackit\_webhook\_resources](#input\_stackit\_webhook\_resources) | Resource requests and limits of the STACKIT cert-manager webhook. Only used when dns01.stackit<br/>is set. The default is sized for a demonstration cluster and a production consumer has to raise<br/>it.<br/><br/>The chart sets no resources and its values file states that `100m` CPU and `128Mi` memory are<br/>enough for the webhook, which is what the limit uses. The webhook answers one DNS-01 challenge<br/>per certificate renewal, so the request stays well below that. Production wants the chart's own<br/>figures as the request as well. | <pre>object({<br/>    requests = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>    limits   = optional(object({ cpu = optional(string), memory = optional(string) }), {})<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "10m",<br/>    "memory": "64Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_stackit_webhook_version"></a> [stackit\_webhook\_version](#input\_stackit\_webhook\_version) | Version of the stackit-cert-manager-webhook Helm chart. Must be a version served by the chart index at https://stackitcloud.github.io/stackit-cert-manager-webhook, which lags behind the GitHub release tags. Only used when dns01.stackit is set. | `string` | `"0.4.9"` | no |
| <a name="input_wildcard_certificate_name"></a> [wildcard\_certificate\_name](#input\_wildcard\_certificate\_name) | Name of the wildcard Certificate and of the secret it writes, both in haproxy\_namespace. Only used when dns01 is set. | `string` | `"wildcard-tls"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_issuer_name"></a> [cluster\_issuer\_name](#output\_cluster\_issuer\_name) | Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress. |
| <a name="output_haproxy_lb_ip"></a> [haproxy\_lb\_ip](#output\_haproxy\_lb\_ip) | External IP of the HAProxy LoadBalancer service. Point application DNS A records here before TLS provisioning can complete. |
| <a name="output_haproxy_namespace"></a> [haproxy\_namespace](#output\_haproxy\_namespace) | Namespace of the HAProxy ingress controller and of the wildcard certificate secret. |
| <a name="output_ingress_class_name"></a> [ingress\_class\_name](#output\_ingress\_class\_name) | Name of the IngressClass an application puts on its Ingress to be served by this controller. |
| <a name="output_wildcard_certificate_domain"></a> [wildcard\_certificate\_domain](#output\_wildcard\_certificate\_domain) | Domain the wildcard certificate covers, so the certificate is issued for `*.<domain>`. Equals dns01.zone\_name when the caller set no dns01.certificate\_domain. Null when dns01 is not set. |
| <a name="output_wildcard_certificate_secret_name"></a> [wildcard\_certificate\_secret\_name](#output\_wildcard\_certificate\_secret\_name) | Name of the secret in haproxy\_namespace holding the wildcard certificate. Null when dns01 is not set. |
<!-- END_TF_DOCS -->
