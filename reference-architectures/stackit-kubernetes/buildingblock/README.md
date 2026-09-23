# STACKIT Kubernetes Platform — Building Block

Terraform for the importable **STACKIT Kubernetes Platform** reference architecture. Ordered on top
of a deployed STACKIT Landing Zone, it bootstraps the whole platform: a self-hosted STACKIT project
and its service account, an SKE cluster, in-cluster ingress (cert-manager, HAProxy and a Let's
Encrypt ClusterIssuer), the meshStack replicator and metering identities, a DNS zone, a STACKIT Model
Serving token, a STACKIT Git instance, a container registry, and the meshStack SKE platform with one
landing zone per stage.

Ingress and the meshStack identities come from `modules/kubernetes/*` and know nothing about SKE.

It also **registers building block definitions of its own** — `ske/cluster`, `stackit/git`,
`stackit/container-registry`, `stackit/dns`, `stackit/ai-llm`, `kubernetes/ingress` and `kubernetes`
on every run, and `stackit/git-repository`, `ske/forgejo-connector` and `ske/ske-starterkit` once
`harbor_username` names the Harbor bootstrap robot. It orders the landing zone's STACKIT Service
Account definition, read from the landing zone building block named by
`landingzone_building_block_uuid`, and then the landing zone's STACKIT Service Account Federation
definition as its child, listing its STACKIT definitions in `federated_building_block_definitions`.
Their runs act as that account through workload identity federation.

The architecture itself (overview, diagram, the order and its one update, shared responsibilities)
lives in the [reference architecture README](../README.md). Registration into meshStack is in
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
| <a name="module_ai_llm_integration"></a> [ai\_llm\_integration](#module\_ai\_llm\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/ai-llm | main |
| <a name="module_cluster_integration"></a> [cluster\_integration](#module\_cluster\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/cluster | main |
| <a name="module_container_registry_integration"></a> [container\_registry\_integration](#module\_container\_registry\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/container-registry | main |
| <a name="module_dns_integration"></a> [dns\_integration](#module\_dns\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/dns | main |
| <a name="module_forgejo_connector_integration"></a> [forgejo\_connector\_integration](#module\_forgejo\_connector\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector | main |
| <a name="module_git_integration"></a> [git\_integration](#module\_git\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/git | main |
| <a name="module_git_repository_integration"></a> [git\_repository\_integration](#module\_git\_repository\_integration) | github.com/meshcloud/meshstack-hub//modules/stackit/git-repository | main |
| <a name="module_ingress_integration"></a> [ingress\_integration](#module\_ingress\_integration) | github.com/meshcloud/meshstack-hub//modules/kubernetes/ingress | main |
| <a name="module_kubernetes_integration"></a> [kubernetes\_integration](#module\_kubernetes\_integration) | github.com/meshcloud/meshstack-hub//modules/kubernetes | main |
| <a name="module_ske_starterkit_integration"></a> [ske\_starterkit\_integration](#module\_ske\_starterkit\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/ske-starterkit | main |

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.ai_llm](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.cluster](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.container_registry](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.dns](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.git](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.ingress](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.kubernetes_platform](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.platform_service_account](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_location.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/location) | resource |
| [meshstack_project.platform](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_project_user_binding.admin](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project_user_binding) | resource |
| [meshstack_tenant.stackit_project](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |
| [random_string.playground_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [meshstack_building_block.stackit_lz_ref_arch](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/building_block) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ai_model"></a> [ai\_model](#input\_ai\_model) | Model applications default to. Must be one STACKIT Model Serving's `/v1/models` endpoint serves. | `string` | n/a | yes |
| <a name="input_cluster_issuer_email"></a> [cluster\_issuer\_email](#input\_cluster\_issuer\_email) | Overrides the Let's Encrypt contact email registered for the ACME ClusterIssuer. | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Overrides the generated SKE cluster name. 2-11 chars, lowercase alphanumeric or dashes. | `string` | `null` | no |
| <a name="input_creator"></a> [creator](#input\_creator) | Creator of the platform, injected by meshStack. They become Project Admin of the platform's meshProject, and their display name is written to its owner tag (see `tags.project_owner_tag_key`). | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_dns_parent_domain"></a> [dns\_parent\_domain](#input\_dns\_parent\_domain) | Domain the platform's DNS zone is created under. | `string` | n/a | yes |
| <a name="input_dns_subdomain"></a> [dns\_subdomain](#input\_dns\_subdomain) | Label the platform's DNS zone occupies under `dns_parent_domain`. Empty uses the platform identifier. Set it to adopt a zone that already carries a different name. | `string` | `null` | no |
| <a name="input_harbor_username"></a> [harbor\_username](#input\_harbor\_username) | Name of the Harbor robot linked to this platform's STACKIT service account, empty until it exists. | `string` | `null` | no |
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: meshstack-hub reference the nested integrations are sourced from.<br/>`bbd_draft`: Forwarded to the nested integrations' `hub.bbd_draft`. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_landingzone_building_block_uuid"></a> [landingzone\_building\_block\_uuid](#input\_landingzone\_building\_block\_uuid) | UUID of the STACKIT Landing Zone building block this platform is built on. | `string` | n/a | yes |
| <a name="input_landingzone_variant"></a> [landingzone\_variant](#input\_landingzone\_variant) | Key into the landing zone's `landingzone_refs` output. `networked` requires hub-and-spoke networking enabled there. | `string` | n/a | yes |
| <a name="input_payment_method_identifier"></a> [payment\_method\_identifier](#input\_payment\_method\_identifier) | Payment method identifier assigned to the platform's meshProject. | `string` | n/a | yes |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | Identifier of the Kubernetes platform created in meshStack (letters, digits and dashes only). In playground mode a random suffix is appended to it. | `string` | n/a | yes |
| <a name="input_playground_mode"></a> [playground\_mode](#input\_playground\_mode) | Deploy a throwaway platform that gets a random identifier suffix and stays destroyable. | `bool` | n/a | yes |
| <a name="input_stages"></a> [stages](#input\_stages) | Stages the platform offers. The map keys name them, and one landing zone is created per key, so a platform can offer fewer or more than the usual `dev` and `prod`. The starter kit creates one meshProject and one namespace per key.<br/>`landingzone` and `project` carry the tags whose value differs between stages. They are merged over the matching map in `tags`, and over the `environment` tag the stage gets from its key.<br/>A tag policy pairs a landing zone tag with a project tag, so such a tag belongs here on both sides at once. | <pre>map(object({<br/>    landingzone = optional(map(list(string)), {})<br/>    project     = optional(map(list(string)), {})<br/>  }))</pre> | n/a | yes |
| <a name="input_starterkit_app_name"></a> [starterkit\_app\_name](#input\_starterkit\_app\_name) | Image name every application ordered from the starter kit builds under, set as APP\_NAME. | `string` | n/a | yes |
| <a name="input_starterkit_repo_clone_addr"></a> [starterkit\_repo\_clone\_addr](#input\_starterkit\_repo\_clone\_addr) | Template repository the starter kit initialises an application repository from. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags forwarded to the nested integrations, and shared by every stage.<br/>`landingzone` tags are applied to the created SKE landing zones. Include every tag a tag policy matches against a project tag, or no tenant can be created on them.<br/>`building_block` tags are applied to the nested building block definitions.<br/>`project` tags are applied to the platform's meshProject and to the meshProjects the starter kit creates.<br/>`project_owner_tag_key` names the tag that receives the creator's display name on the platform's meshProject (empty to set none). Set it to the mandatory owner tag your meshStack enforces (e.g. `projectOwner`). | <pre>object({<br/>    landingzone           = map(list(string))<br/>    building_block        = map(list(string))<br/>    project               = map(list(string))<br/>    project_owner_tag_key = optional(string, "")<br/>  })</pre> | n/a | yes |
| <a name="input_use_global_location"></a> [use\_global\_location](#input\_use\_global\_location) | Use the global meshStack location instead of creating a dedicated one for this platform. | `bool` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that owns the platform, location, landing zones, STACKIT project and the building block definitions this architecture registers. | `string` | n/a | yes |
| <a name="input_workspace_members"></a> [workspace\_members](#input\_workspace\_members) | Members of the owning workspace, injected by meshStack. Owners and managers become Project Admin of the platform's project. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ske_project_url"></a> [ske\_project\_url](#output\_ske\_project\_url) | Deep link to the STACKIT project the SKE cluster and its assets run in. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the resources created by this reference architecture. |
<!-- END_TF_DOCS -->
