# STACKIT Kubernetes Platform — Building Block

Terraform for the importable **STACKIT Kubernetes Platform** reference architecture. Ordered on top
of a deployed STACKIT Landing Zone, it bootstraps the whole platform: a self-hosted STACKIT project,
an SKE cluster, in-cluster ingress (cert-manager, HAProxy and a Let's Encrypt ClusterIssuer), the
meshStack replicator and metering identities, a STACKIT Git instance, and the meshStack SKE platform
with dev/prod landing zones.

Only the cluster and the Git instance are STACKIT-specific. Ingress and the meshStack identities
come from `modules/kubernetes/*` and know nothing about SKE.

It also **registers building block definitions of its own** — `ske/cluster`, `stackit/git`,
`kubernetes/ingress` and `kubernetes` on every run, and `stackit/git-repository`
plus `ske/forgejo-connector` once a Forgejo token is supplied. Their backplanes are deployed as the landing zone's bootstrap identity, read from the
landing zone building block named by `landingzone_building_block_uuid`.

The architecture itself (overview, diagram, the two-phase order, shared responsibilities) lives in
the [reference architecture README](../README.md). Registration into meshStack is in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cluster_integration"></a> [cluster\_integration](#module\_cluster\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/cluster | main |
| <a name="module_forgejo_connector_integration"></a> [forgejo\_connector\_integration](#module\_forgejo\_connector\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector | main |
| <a name="module_git_integration"></a> [git\_integration](#module\_git\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/git | main |
| <a name="module_git_repository_integration"></a> [git\_repository\_integration](#module\_git\_repository\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/git-repository | main |
| <a name="module_ingress_integration"></a> [ingress\_integration](#module\_ingress\_integration) | github.com/meshcloud/meshstack-hub//modules/kubernetes/ingress | main |
| <a name="module_kubernetes_integration"></a> [kubernetes\_integration](#module\_kubernetes\_integration) | github.com/meshcloud/meshstack-hub//modules/kubernetes | main |

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.cluster](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.git](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.ingress](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.kubernetes_platform](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.platform_service_account](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_location.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/location) | resource |
| [meshstack_project.hosting](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_tenant.hosting](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |
| [random_string.identifier_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [meshstack_building_block.stackit_lz_ref_arch](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/building_block) | data source |
| [meshstack_integrations.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/integrations) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_issuer_email"></a> [cluster\_issuer\_email](#input\_cluster\_issuer\_email) | Overrides the Let's Encrypt contact email registered for the ACME ClusterIssuer. | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Overrides the generated SKE cluster name. 2-11 chars, lowercase alphanumeric or dashes. | `string` | `null` | no |
| <a name="input_creator"></a> [creator](#input\_creator) | Creator of the platform, injected by meshStack. Their display name is written to the hosting project's owner tag (see `tags.project_owner_tag_key`). | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_forgejo_api_token"></a> [forgejo\_api\_token](#input\_forgejo\_api\_token) | Personal Access Token of a bot account in the Forgejo instance this architecture creates, with `write:organization`, `write:repository` and `read:user` scopes. Leave empty on the first order and fill it in afterwards — see this building block's summary. | `string` | `null` | no |
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: meshstack-hub reference used to source the nested cluster, git, ingress and kubernetes modules. `const` so it can be interpolated into the module source at init time.<br/>`bbd_draft`: Forwarded to those nested integrations' `hub.bbd_draft`, so their building block definition draft state tracks this architecture's own release state. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_landingzone_building_block_uuid"></a> [landingzone\_building\_block\_uuid](#input\_landingzone\_building\_block\_uuid) | UUID of the STACKIT Landing Zone building block this platform is built on. | `string` | n/a | yes |
| <a name="input_landingzone_variant"></a> [landingzone\_variant](#input\_landingzone\_variant) | Key into the landing zone's `landingzone_refs` output. `networked` requires hub-and-spoke networking enabled there. | `string` | `"default"` | no |
| <a name="input_payment_method_identifier"></a> [payment\_method\_identifier](#input\_payment\_method\_identifier) | Payment method identifier assigned to the hosting meshProject. | `string` | n/a | yes |
| <a name="input_playground_mode"></a> [playground\_mode](#input\_playground\_mode) | Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the hosting project and tenant are left destroyable. Set to false for a platform that is actually used. | `bool` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags forwarded to the nested integrations.<br/>`landingzone` tags are applied to the created SKE landing zones.<br/>`building_block` tags are applied to the nested building block definitions.<br/>`project` tags are applied to the hosting meshProject.<br/>`project_owner_tag_key` names the tag that receives the creator's display name on the hosting project (empty to set none). Set it to the mandatory owner tag your meshStack enforces (e.g. `projectOwner`). | <pre>object({<br/>    landingzone           = map(list(string))<br/>    building_block        = map(list(string))<br/>    project               = map(list(string))<br/>    project_owner_tag_key = optional(string, "")<br/>  })</pre> | n/a | yes |
| <a name="input_use_global_location"></a> [use\_global\_location](#input\_use\_global\_location) | Use the global meshStack location instead of creating a dedicated one for this platform. | `bool` | `false` | no |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that owns the platform, location, landing zones, hosting project and the building block definitions this architecture registers. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ske_project_url"></a> [ske\_project\_url](#output\_ske\_project\_url) | Deep link to the STACKIT project the SKE cluster and its assets run in. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the resources created by this reference architecture. |
<!-- END_TF_DOCS -->
