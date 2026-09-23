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
controller** behind a cloud LoadBalancer, a Let's Encrypt **ClusterIssuer**, and — when `ingress/` is
given a DNS-01 credential — a **wildcard Certificate** that HAProxy serves as its default TLS
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

## DNS-01 lives in `ingress/` only

Passing `dns01` to `ingress/` switches the ClusterIssuer to a DNS-01 solver (STACKIT or Route53)
and issues the wildcard certificate. The building block root does not expose it: DNS-01 needs a
long-lived credential for the zone inside the cluster, and `modules/stackit/dns` creates the zone
without one, because the architectures using it authenticate through workload identity federation.
Ordered from meshStack, certificates are issued per hostname over HTTP-01. A composition that holds
a zone credential sources `ingress/` directly and sets `dns01`.

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
| <a name="input_acme_server"></a> [acme\_server](#input\_acme\_server) | ACME directory URL the ClusterIssuer registers against. | `string` | n/a | yes |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | Version of the cert-manager Helm chart. | `string` | n/a | yes |
| <a name="input_cluster_issuer_name"></a> [cluster\_issuer\_name](#input\_cluster\_issuer\_name) | Name of the ClusterIssuer application teams reference from the cert-manager.io/cluster-issuer annotation. | `string` | n/a | yes |
| <a name="input_haproxy_replica_count"></a> [haproxy\_replica\_count](#input\_haproxy\_replica\_count) | Number of HAProxy ingress controller replicas. | `number` | n/a | yes |
| <a name="input_haproxy_service_annotations"></a> [haproxy\_service\_annotations](#input\_haproxy\_service\_annotations) | Annotations on the HAProxy controller Service, read by the cloud provider to configure the load balancer. | `map(string)` | n/a | yes |
| <a name="input_haproxy_version"></a> [haproxy\_version](#input\_haproxy\_version) | Version of the haproxytech/kubernetes-ingress Helm chart. | `string` | n/a | yes |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | Name of the IngressClass the controller serves. | `string` | n/a | yes |
| <a name="input_kubeconfig"></a> [kubeconfig](#input\_kubeconfig) | Raw kubeconfig (YAML) of the target cluster, from a preceding building block so it is known at plan time. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_issuer_name"></a> [cluster\_issuer\_name](#output\_cluster\_issuer\_name) | Name of the ClusterIssuer an application references from the cert-manager.io/cluster-issuer annotation on its Ingress. |
| <a name="output_haproxy_lb_ip"></a> [haproxy\_lb\_ip](#output\_haproxy\_lb\_ip) | External IP of the HAProxy LoadBalancer service. Point application DNS A records here before TLS provisioning can complete. |
| <a name="output_haproxy_namespace"></a> [haproxy\_namespace](#output\_haproxy\_namespace) | Namespace of the HAProxy ingress controller. |
| <a name="output_ingress_class_name"></a> [ingress\_class\_name](#output\_ingress\_class\_name) | Name of the IngressClass an application puts on its Ingress to be served by this controller. |
<!-- END_TF_DOCS -->
