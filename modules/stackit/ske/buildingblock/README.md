---
name: STACKIT Kubernetes Engine (SKE) Cluster
supportedPlatforms:
  - stackit
description: Provisions a STACKIT Kubernetes Engine cluster with one node pool, a maintenance window and a kubeconfig.
---

# SKE Cluster Building Block

This module provisions a [STACKIT Kubernetes Engine](https://docs.stackit.cloud/products/runtime/kubernetes-engine/)
cluster and the kubeconfig that gives access to it. It provisions nothing else — no addons, no
meshStack registration, no DNS records. Compose it with other modules to build a full platform:

- `modules/kubernetes/platform` registers the cluster as a meshStack platform whose tenants are namespaces.
- `modules/kubernetes/ingress` installs an ingress controller and certificate management.
- `modules/stackit/network` supplies the network for STACKIT Network Area (SNA) placement.

The module lives under `modules/stackit/` because that directory follows the platform the block is
**ordered on**, not the thing it produces. `modules/ske/` stays the platform whose tenants are
namespaces on an existing cluster.

## Why this module lives in the hub

The `likvid-cloudfoundation`, `internal-cloudfoundation` and `trial-cloudfoundation` foundations each
carried their own copy of this cluster definition. The copies were identical apart from the provider
block. This module replaces all three.

## Outputs the foundations rely on

The module keeps two outputs the foundations already consume through Terragrunt:

- `provider_config` — a ready-made object with `host`, `cluster_ca_certificate`, `client_certificate`
  and `client_key`, which the foundations feed into a generated `kubernetes` and `helm` provider block.
- `kubeconfig` — the decoded kubeconfig. The foundations read it as a fallback when `provider_config`
  is missing, so it stays part of the contract.

A third output, `kube_host`, exposes the API server URL on its own and is not sensitive, so a
composition can pass it to `modules/kubernetes/platform` without tainting the whole value.

## STACKIT Network Area placement

Set `network_id` to place the cluster on a network you created yourself, for example with
`modules/stackit/network`. In meshStack, wire this through a `BUILDING_BLOCK_OUTPUT` input — a network
id is not a secret, so nothing on the meshStack side blocks that. Leave `network_id` unset and SKE
places the cluster on a network of its own.

## Control plane access scope

`control_plane_access_scope` decides whether the Kubernetes control plane is reachable from the
public internet (`PUBLIC`) or only from inside a STACKIT Network Area (`SNA`). Three constraints apply
and you should read all three before you set it:

1. **The field is immutable.** STACKIT fixes the access scope when it creates the cluster. Changing the
   value later forces you to replace the cluster.
2. **The field is feature-flagged, not generally available.** STACKIT rejects the request unless your
   account is enabled for it, and enabling it takes a support ticket per organization or per project.
   Because of this, the module sends no `control_plane` block at all while the variable is unset.
3. **The field conflicts with the ACL extension.** A cluster cannot use `access_scope` and the SKE ACL
   extension (`extensions.acl`) at the same time. This module does not expose the ACL extension, which
   keeps the two apart.

Leaving `control_plane_access_scope` unset gives you a public control plane, which is the default for
this module.

## Managed ExternalDNS extension

`dns_extension` turns on the SKE managed ExternalDNS extension. It is off by default. `zones` is the
domain filter ExternalDNS applies:

```hcl
dns_extension = {
  enabled = true
  zones   = ["apps.example.runs.onstackit.cloud"]
}
```

A wildcard in the `zones` filter is not written as `*` into the DNS records ExternalDNS creates.
STACKIT rewrites it to the literal label `x-stackit-dns-wildcard`, so a record for
`*.apps.example.com` appears as `x-stackit-dns-wildcard.apps.example.com` in the STACKIT DNS zone.
Keep that in mind when you look for a record you expect to find under `*`.

## Cluster name length

STACKIT limits SKE cluster names to 11 characters and the module validates that. The trial foundation
ran into this limit and had to shorten `try-meshstack` to `try-mesh`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.88.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_ske_cluster.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/ske_cluster) | resource |
| [stackit_ske_kubeconfig.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/ske_kubeconfig) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the SKE cluster. STACKIT limits SKE cluster names to 11 characters. | `string` | n/a | yes |
| <a name="input_control_plane_access_scope"></a> [control\_plane\_access\_scope](#input\_control\_plane\_access\_scope) | Access scope of the control plane, either `PUBLIC` or `SNA`. Leave unset to get a public control plane, which is what SKE creates by default. The field is immutable after creation, it is feature-flagged per organization or project, and it cannot be combined with the ACL extension. | `string` | `null` | no |
| <a name="input_dns_extension"></a> [dns\_extension](#input\_dns\_extension) | SKE managed ExternalDNS extension. Leave unset to keep the extension off. `zones` is the domain filter ExternalDNS applies, for example `["apps.example.runs.onstackit.cloud"]`. | <pre>object({<br/>    enabled     = optional(bool, true)<br/>    zones       = optional(list(string))<br/>    gateway_api = optional(bool)<br/>  })</pre> | `null` | no |
| <a name="input_kubeconfig_expiration_seconds"></a> [kubeconfig\_expiration\_seconds](#input\_kubeconfig\_expiration\_seconds) | Lifetime of the generated kubeconfig in seconds. Terraform refreshes the kubeconfig once it reaches half of this lifetime. | `number` | `15552000` | no |
| <a name="input_maintenance"></a> [maintenance](#input\_maintenance) | Maintenance window in which SKE applies Kubernetes and machine image updates. | <pre>object({<br/>    enable_kubernetes_version_updates    = optional(bool, true)<br/>    enable_machine_image_version_updates = optional(bool, true)<br/>    start                                = optional(string, "01:00:00Z")<br/>    end                                  = optional(string, "02:00:00Z")<br/>  })</pre> | `{}` | no |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | UUID of the STACKIT Network Area (SNA) network the cluster is deployed into. Feed this from the `network_id` output of `modules/stackit/network`. Leave unset to let SKE place the cluster on its own network. | `string` | `null` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | Node pools of the cluster. The default is a single autoscaling pool of general instances, which is what the meshcloud foundations run today. | <pre>list(object({<br/>    name                    = string<br/>    machine_type            = string<br/>    minimum                 = number<br/>    maximum                 = number<br/>    availability_zones      = list(string)<br/>    max_surge               = optional(number)<br/>    max_unavailable         = optional(number)<br/>    allow_system_components = optional(bool)<br/>    labels                  = optional(map(string))<br/>    os_name                 = optional(string)<br/>    os_version_min          = optional(string)<br/>    volume_type             = optional(string)<br/>    volume_size             = optional(number)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "availability_zones": [<br/>      "eu01-1"<br/>    ],<br/>    "machine_type": "g2i.2",<br/>    "max_surge": 1,<br/>    "maximum": 3,<br/>    "minimum": 1,<br/>    "name": "pool-1"<br/>  }<br/>]</pre> | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account the provider authenticates as via workload identity federation. Leave unset when the caller supplies its own provider configuration. | `string` | `null` | no |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project UUID that holds the SKE cluster. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region the provider talks to. Ignored when the caller supplies its own provider configuration. | `string` | `"eu01"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the SKE cluster. |
| <a name="output_kube_host"></a> [kube\_host](#output\_kube\_host) | URL of the Kubernetes API server. Feed this into the `kube_host` input of `modules/kubernetes/platform`. |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Raw kubeconfig content for cluster access. |
| <a name="output_provider_config"></a> [provider\_config](#output\_provider\_config) | Kubernetes provider config values derived from the kubeconfig, for wiring a kubernetes or helm provider. |
<!-- END_TF_DOCS -->
