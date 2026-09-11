# STACKIT Kubernetes Platform — Building Block

Terraform for the importable **STACKIT Kubernetes Platform** reference architecture. Ordered once
from the hub, it bootstraps the whole platform in a single click: a self-hosted STACKIT project, an
SKE cluster, in-cluster platform services (ingress, cert-manager, meshStack replication/metering),
STACKIT Git, DNS, the meshStack SKE platform with dev/prod landing zones, and the self-service SKE
Starterkit definition.

The architecture itself (overview, diagram, shared responsibilities) lives in the
[reference architecture README](../README.md). Registration into meshStack is in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.99.0, < 1.0.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cluster_integration"></a> [cluster\_integration](#module\_cluster\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/cluster | main |
| <a name="module_forgejo_connector"></a> [forgejo\_connector](#module\_forgejo\_connector) | github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector | main |
| <a name="module_git_repository"></a> [git\_repository](#module\_git\_repository) | github.com/meshcloud/meshstack-hub//modules/stackit/git-repository | main |
| <a name="module_platform_services_integration"></a> [platform\_services\_integration](#module\_platform\_services\_integration) | github.com/meshcloud/meshstack-hub//modules/ske/platform-services | main |
| <a name="module_ske_starterkit"></a> [ske\_starterkit](#module\_ske\_starterkit) | github.com/meshcloud/meshstack-hub//modules/ske/ske-starterkit | main |

## Resources

| Name | Type |
| ---- | ---- |
| [meshstack_building_block.cluster](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.platform_services](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_landingzone.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/landingzone) | resource |
| [meshstack_location.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/location) | resource |
| [meshstack_platform.ske](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/platform) | resource |
| [meshstack_project.hosting](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_tenant.hosting](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |
| [random_string.playground_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [restapi_object.forgejo_organization](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [stackit_dns_record_set.wildcard_a](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/dns_record_set) | resource |
| [stackit_dns_zone.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/dns_zone) | resource |
| [stackit_git.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/git) | resource |
| [stackit_modelserving_token.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/modelserving_token) | resource |
| [meshstack_platforms.host](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/platforms) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_add_random_name_suffix"></a> [add\_random\_name\_suffix](#input\_add\_random\_name\_suffix) | Whether the starterkit appends a random suffix to the names it creates. | `bool` | `false` | no |
| <a name="input_ai_model"></a> [ai\_model](#input\_ai\_model) | STACKIT Model Serving model id provisioned into the starterkit's dev/prod namespaces. | `string` | `"openai/gpt-oss-120b"` | no |
| <a name="input_cluster_issuer_email"></a> [cluster\_issuer\_email](#input\_cluster\_issuer\_email) | Contact email registered with Let's Encrypt for the ACME ClusterIssuer installed on the cluster. | `string` | `"ske@meshcloud.io"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the SKE cluster (2-11 chars, lowercase alphanumeric or dashes, no leading/trailing dash). | `string` | `"starterkit"` | no |
| <a name="input_dns_contact_email"></a> [dns\_contact\_email](#input\_dns\_contact\_email) | Contact email registered on the STACKIT DNS zone. | `string` | `"support@meshcloud.io"` | no |
| <a name="input_dns_name"></a> [dns\_name](#input\_dns\_name) | Subdomain label under `stackit.run` for application ingress. Creates the DNS zone `<dns_name>.stackit.run` and a wildcard A record pointing at the ingress load balancer. | `string` | n/a | yes |
| <a name="input_forgejo_organization"></a> [forgejo\_organization](#input\_forgejo\_organization) | Forgejo organization created on the git instance and used for the application repositories. | `string` | n/a | yes |
| <a name="input_forgejo_token"></a> [forgejo\_token](#input\_forgejo\_token) | Personal access token of a Forgejo bot account on the STACKIT Git instance, used to manage the organization and repositories. Created manually as a one-time prerequisite. | `string` | n/a | yes |
| <a name="input_git_instance_name"></a> [git\_instance\_name](#input\_git\_instance\_name) | Name of the STACKIT Git (Forgejo) instance. Globally unique across STACKIT; forms the instance URL `https://<name>.git.onstackit.cloud`. | `string` | n/a | yes |
| <a name="input_host_landing_zone_name"></a> [host\_landing\_zone\_name](#input\_host\_landing\_zone\_name) | Name of the landing zone on the host STACKIT platform that the hosting tenant is placed in. | `string` | n/a | yes |
| <a name="input_host_platform_identifier"></a> [host\_platform\_identifier](#input\_host\_platform\_identifier) | Full `<platform>.<location>` identifier of the existing STACKIT Project platform (e.g. from the STACKIT Landing Zone) on which the cluster's hosting project is provisioned as a meshStack tenant. | `string` | n/a | yes |
| <a name="input_hub"></a> [hub](#input\_hub) | `git_ref`: meshstack-hub reference used to source the nested cluster, platform-services, git-repository, forgejo-connector and starterkit modules. `const` so it can be interpolated into the module source at init time.<br/>`bbd_draft`: Forwarded to those nested integrations' `hub.bbd_draft`, so their building block definition draft state tracks this architecture's own release state. | <pre>object({<br/>    git_ref   = optional(string, "main")<br/>    bbd_draft = optional(bool, true)<br/>  })</pre> | <pre>{<br/>  "bbd_draft": true,<br/>  "git_ref": "main"<br/>}</pre> | no |
| <a name="input_payment_method_identifier"></a> [payment\_method\_identifier](#input\_payment\_method\_identifier) | Payment method identifier assigned to the hosting project and the starterkit's dev/prod projects. | `string` | n/a | yes |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | Identifier for the SKE platform created in meshStack (letters, digits and dashes only). Also names the location and the hosting project. | `string` | n/a | yes |
| <a name="input_playground_mode"></a> [playground\_mode](#input\_playground\_mode) | Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the hosting project and tenant are left destroyable. Set to false for a platform that is actually used. | `bool` | n/a | yes |
| <a name="input_project_tags"></a> [project\_tags](#input\_project\_tags) | Tags applied to the dev and prod meshProjects the starterkit creates. `owner_tag_key` names the tag that receives the creator's display name. | <pre>object({<br/>    dev           = map(list(string))<br/>    prod          = map(list(string))<br/>    owner_tag_key = optional(string, null)<br/>  })</pre> | n/a | yes |
| <a name="input_stackit_harbor_project"></a> [stackit\_harbor\_project](#input\_stackit\_harbor\_project) | Harbor project name in the global STACKIT registry that application images are pushed to and pulled from. | `string` | n/a | yes |
| <a name="input_stackit_harbor_pull_robot_password"></a> [stackit\_harbor\_pull\_robot\_password](#input\_stackit\_harbor\_pull\_robot\_password) | Harbor robot account secret with pull access. | `string` | n/a | yes |
| <a name="input_stackit_harbor_pull_robot_user"></a> [stackit\_harbor\_pull\_robot\_user](#input\_stackit\_harbor\_pull\_robot\_user) | Harbor robot account username with pull access (used by the cluster to pull images). | `string` | n/a | yes |
| <a name="input_stackit_harbor_push_robot_password"></a> [stackit\_harbor\_push\_robot\_password](#input\_stackit\_harbor\_push\_robot\_password) | Harbor robot account secret with push access. | `string` | n/a | yes |
| <a name="input_stackit_harbor_push_robot_user"></a> [stackit\_harbor\_push\_robot\_user](#input\_stackit\_harbor\_push\_robot\_user) | Harbor robot account username with push access (used by CI to publish images). | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region for the git instance, DNS zone and model serving token. | `string` | `"eu01"` | no |
| <a name="input_stackit_service_account_key"></a> [stackit\_service\_account\_key](#input\_stackit\_service\_account\_key) | STACKIT service account key JSON. Used by this run to create git/DNS/model-serving resources, and passed down to the SKE Cluster building block to manage the cluster. Needs SKE, STACKIT Git, DNS and Model Serving permissions in the hosting project. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags forwarded to the nested integrations.<br/>`landingzone` tags are applied to the created SKE landing zones.<br/>`building_block` tags are applied to the nested building block definitions.<br/>`project` tags are applied to the meshProjects the starterkit creates.<br/>`project_owner_tag_key` names the tag that receives the creator's display name. | <pre>object({<br/>    landingzone           = map(list(string))<br/>    building_block        = map(list(string))<br/>    project               = map(list(string))<br/>    project_owner_tag_key = string<br/>  })</pre> | n/a | yes |
| <a name="input_template_name"></a> [template\_name](#input\_template\_name) | Name of the sample application; used to name the model serving token and passed to CI as APP\_NAME. | `string` | `"ai-summarizer"` | no |
| <a name="input_template_repo_clone_url"></a> [template\_repo\_clone\_url](#input\_template\_repo\_clone\_url) | Template repository the starterkit clones new application repositories from. | `string` | `"https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git"` | no |
| <a name="input_use_global_location"></a> [use\_global\_location](#input\_use\_global\_location) | Use the global meshStack location instead of creating a dedicated one for this platform. | `bool` | `false` | no |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Identifier of the meshStack workspace that owns the platform, location, landing zones, hosting project and the building block definitions this architecture registers. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_building_block_uuid"></a> [cluster\_building\_block\_uuid](#output\_cluster\_building\_block\_uuid) | UUID of the SKE Cluster building block this architecture ordered. |
| <a name="output_dns_zone_name"></a> [dns\_zone\_name](#output\_dns\_zone\_name) | DNS zone created for application ingress hostnames. |
| <a name="output_forgejo_url"></a> [forgejo\_url](#output\_forgejo\_url) | URL of the STACKIT Git (Forgejo) instance hosting the application repositories. |
| <a name="output_hosting_project_id"></a> [hosting\_project\_id](#output\_hosting\_project\_id) | STACKIT project id the SKE cluster and its assets run in (self-hosted meshStack tenant). |
| <a name="output_hosting_project_url"></a> [hosting\_project\_url](#output\_hosting\_project\_url) | Deep link to the hosting project in the STACKIT portal. |
| <a name="output_platform_ref"></a> [platform\_ref](#output\_platform\_ref) | Reference to the meshStack SKE platform this architecture registered. |
| <a name="output_starterkit_bbd_uuid"></a> [starterkit\_bbd\_uuid](#output\_starterkit\_bbd\_uuid) | UUID of the SKE Starterkit definition this architecture registered. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the resources created by this reference architecture. |
<!-- END_TF_DOCS -->
