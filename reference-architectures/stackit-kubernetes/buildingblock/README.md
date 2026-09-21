# STACKIT Kubernetes Platform — Building Block

Terraform for the importable **STACKIT Kubernetes Platform** reference architecture. Ordered on top
of a deployed STACKIT Landing Zone, it bootstraps the whole platform: a self-hosted STACKIT project,
an SKE cluster, in-cluster platform services (ingress, cert-manager, meshStack
replication/metering), a STACKIT Git instance, and the meshStack SKE platform with dev/prod landing
zones.

It also **registers building block definitions of its own** — `ske/cluster` and `stackit/git` on
every run, and `stackit/git-repository` plus `ske/forgejo-connector` once a Forgejo token is
supplied. Their backplanes are deployed as the landing zone's bootstrap identity, read from the
landing zone building block named by `landingzone_building_block_uuid`.

The architecture itself (overview, diagram, the two-phase order, shared responsibilities) lives in
the [reference architecture README](../README.md). Registration into meshStack is in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.99.0, < 1.0.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cluster_integration"></a> [cluster\_integration](#module\_cluster\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/cluster | main |
| <a name="module_cluster_issuer_integration"></a> [cluster\_issuer\_integration](#module\_cluster\_issuer\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/cluster-issuer | main |
| <a name="module_forgejo_connector_integration"></a> [forgejo\_connector\_integration](#module\_forgejo\_connector\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector | main |
| <a name="module_git_integration"></a> [git\_integration](#module\_git\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/git | main |
| <a name="module_git_repository_integration"></a> [git\_repository\_integration](#module\_git\_repository\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/git-repository | main |
| <a name="module_platform_services_integration"></a> [platform\_services\_integration](#module\_platform\_services\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/platform-services | main |

## Resources

| Name | Type |
| ---- | ---- |
| [meshstack_building_block.cluster](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.cluster_issuer](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.git](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.platform_services](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_landingzone.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/landingzone) | resource |
| [meshstack_location.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/location) | resource |
| [meshstack_platform.ske](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/platform) | resource |
| [meshstack_project.hosting](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_tenant.hosting](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |
| [random_string.identifier_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [meshstack_building_block.landingzone](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/building_block) | data source |
| [meshstack_platforms.host](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/platforms) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_issuer_email"></a> [cluster\_issuer\_email](#input\_cluster\_issuer\_email) | Contact email registered with Let's Encrypt for the ACME ClusterIssuer installed on the cluster. | `string` | `"ske@meshcloud.io"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the SKE cluster (2-11 chars, lowercase alphanumeric or dashes, no leading/trailing dash). | `string` | `"starterkit"` | no |
| <a name="input_creator"></a> [creator](#input\_creator) | Creator of the platform, injected by meshStack. Their display name is written to the hosting project's owner tag (see `tags.project_owner_tag_key`). | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_forgejo_api_token"></a> [forgejo\_api\_token](#input\_forgejo\_api\_token) | Personal Access Token of a bot account in the Forgejo instance this architecture creates, with `write:organization`, `write:repository` and `read:user` scopes. Leave empty on the first order and fill it in afterwards — see this building block's summary. | `string` | `null` | no |
| <a name="input_harbor_password"></a> [harbor\_password](#input\_harbor\_password) | Secret of the STACKIT Harbor pull robot account named in `harbor_username`. | `string` | `null` | no |
| <a name="input_harbor_username"></a> [harbor\_username](#input\_harbor\_username) | Username of a STACKIT Harbor pull robot account, handed to the Forgejo connector so application pods can pull private images. Optional: the Harbor project is shared across STACKIT customers and we hold robot credentials for it rather than admin rights, so nothing here creates them. Without them the connector still works for public images. | `string` | `null` | no |
| <a name="input_host_landing_zone_name"></a> [host\_landing\_zone\_name](#input\_host\_landing\_zone\_name) | Name of the landing zone on the host STACKIT platform that the hosting tenant is placed in. | `string` | n/a | yes |
| <a name="input_host_platform_identifier"></a> [host\_platform\_identifier](#input\_host\_platform\_identifier) | Full `<platform>.<location>` identifier of the existing STACKIT Project platform (e.g. from the STACKIT Landing Zone) on which the cluster's hosting project is provisioned as a meshStack tenant. | `string` | n/a | yes |
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: meshstack-hub reference used to source the nested cluster and platform-services modules. `const` so it can be interpolated into the module source at init time.<br/>`bbd_draft`: Forwarded to those nested integrations' `hub.bbd_draft`, so their building block definition draft state tracks this architecture's own release state. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_landingzone_building_block_uuid"></a> [landingzone\_building\_block\_uuid](#input\_landingzone\_building\_block\_uuid) | UUID of the deployed STACKIT Landing Zone building block this platform is built on. Read at order time for the foundation project and landing-zone folder the registered definitions' backplanes deploy into, and for the bootstrap service account credential this run applies as. | `string` | n/a | yes |
| <a name="input_payment_method_identifier"></a> [payment\_method\_identifier](#input\_payment\_method\_identifier) | Payment method identifier assigned to the hosting meshProject. | `string` | n/a | yes |
| <a name="input_playground_mode"></a> [playground\_mode](#input\_playground\_mode) | Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the hosting project and tenant are left destroyable. Set to false for a platform that is actually used. | `bool` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags forwarded to the nested integrations.<br/>`landingzone` tags are applied to the created SKE landing zones.<br/>`building_block` tags are applied to the nested building block definitions.<br/>`project` tags are applied to the hosting meshProject.<br/>`project_owner_tag_key` names the tag that receives the creator's display name on the hosting project (empty to set none). Set it to the mandatory owner tag your meshStack enforces (e.g. `projectOwner`). | <pre>object({<br/>    landingzone           = map(list(string))<br/>    building_block        = map(list(string))<br/>    project               = map(list(string))<br/>    project_owner_tag_key = optional(string, "")<br/>  })</pre> | n/a | yes |
| <a name="input_use_global_location"></a> [use\_global\_location](#input\_use\_global\_location) | Use the global meshStack location instead of creating a dedicated one for this platform. | `bool` | `false` | no |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that owns the platform, location, landing zones, hosting project and the building block definitions this architecture registers. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_building_block_uuid"></a> [cluster\_building\_block\_uuid](#output\_cluster\_building\_block\_uuid) | UUID of the SKE Cluster building block this architecture ordered. |
| <a name="output_forgejo_instance_url"></a> [forgejo\_instance\_url](#output\_forgejo\_instance\_url) | URL of the STACKIT Git (Forgejo) instance this architecture created. Sign in here to mint the token the second phase needs. |
| <a name="output_forgejo_organization"></a> [forgejo\_organization](#output\_forgejo\_organization) | Forgejo organization application repositories are created in, or null while no token has been supplied. |
| <a name="output_hosting_project_id"></a> [hosting\_project\_id](#output\_hosting\_project\_id) | STACKIT project id the SKE cluster and its assets run in (self-hosted meshStack tenant). |
| <a name="output_hosting_project_url"></a> [hosting\_project\_url](#output\_hosting\_project\_url) | Deep link to the hosting project in the STACKIT portal. |
| <a name="output_platform_ref"></a> [platform\_ref](#output\_platform\_ref) | Reference to the meshStack SKE platform this architecture registered. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the resources created by this reference architecture. |
<!-- END_TF_DOCS -->
