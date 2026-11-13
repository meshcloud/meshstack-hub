---
name: Platform Metering
supportedPlatforms:
  - meshstack
description: Sets up custom metering for the clouds a platform team selects, in one Kubernetes namespace with one metering CronJob per cloud.
# A composition of other building blocks that authenticates with the run's ephemeral meshStack API
# key, so there is nothing to set up cloud-side beforehand.
requiresBackplane: false
---

# Metering Starterkit

> ⚠️ **Experimental: set it up together with meshcloud.** The starterkit works and is built from
> supported building blocks: [`kubernetes/service-account`](../../../kubernetes/service-account),
> [`kubernetes/cronjob`](../../../kubernetes/cronjob) and
> [`stackit/kubernetes-workload-identity`](../../../stackit/kubernetes-workload-identity). Wiring it
> into a meshStack still takes several credentials and cloud-specific settings, so expect to set it
> up with help from your meshcloud contact rather than on your own. The metering images themselves
> come from [mesh-custom-metering](https://github.com/meshcloud/mesh-custom-metering), which is
> maintained on its own and not covered by meshStack support.

`meshstack_integration.tf` sets up the whole custom metering of a meshStack in one apply. It creates
**Platform Metering**, the definition workspaces order, and the definitions it orders:

- [`kubernetes/service-account`](../../../kubernetes/service-account), with a deployer identity on the cluster.
- [`kubernetes/cronjob`](../../../kubernetes/cronjob), which runs every metering job.
- [`stackit/kubernetes-workload-identity`](../../../stackit/kubernetes-workload-identity) with
  `stackit_enabled`, with a STACKIT service account that may read the organization's costs.

A workspace then orders Platform Metering and ticks the clouds. That creates a project with one
namespace, a service account allowed to deploy only into it, and per cloud a CronJob with the
metering image of [mesh-custom-metering](https://github.com/meshcloud/mesh-custom-metering). For
STACKIT it also federates that CronJob's Kubernetes service account, so the job reads the costs
without a STACKIT key. The jobs submit usage reports to the meshStack the starterkit was applied
against.

## Setting it up

The starterkit configures no providers; the caller configures three:

| Provider | Identity |
|---|---|
| `meshstack` | The meshStack the metering reports to, with a workspace that owns the definitions. |
| `kubernetes` | A cluster admin login for the cluster of `kubernetes_platform_ref`. It only creates the deployer identity; meshStack gets the deployer's kubeconfig. |
| `stackit` | With `stackit_enabled`, an identity that may create service accounts in `stackit_project_id` and assign roles on the organization. Without it, a placeholder, because OpenTofu configures the providers of a module with `count = 0` too. |

How to get the cluster admin login depends on the cloud. On STACKIT Kubernetes Engine an ephemeral
`stackit_ske_kubeconfig` keeps it out of the state:

```hcl
provider "meshstack" {
  endpoint  = "https://federation.example.meshcloud.io"
  workspace = "platform-team"
}

provider "stackit" {
  service_account_key = var.stackit_org_service_account_key
  default_region      = "eu01"
  experiments         = ["iam"]
}

# A second login only for the SKE admin kubeconfig.
provider "stackit" {
  alias               = "ske"
  service_account_key = var.stackit_ske_service_account_key
  default_region      = "eu01"
  experiments         = ["ske"]
}

ephemeral "stackit_ske_kubeconfig" "admin" {
  provider     = stackit.ske
  project_id   = "<SKE project id>"
  cluster_name = "<SKE cluster name>"
  expiration   = 1800
}

locals {
  admin_kubeconfig = yamldecode(ephemeral.stackit_ske_kubeconfig.admin.kube_config)
  admin_cluster    = one(local.admin_kubeconfig["clusters"])["cluster"]
  admin_user       = one(local.admin_kubeconfig["users"])["user"]
}

provider "kubernetes" {
  host                   = local.admin_cluster["server"]
  cluster_ca_certificate = base64decode(local.admin_cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.admin_user["client-certificate-data"])
  client_key             = base64decode(local.admin_user["client-key-data"])
}

data "meshstack_platforms" "kubernetes" {
  identifier = "<kubernetes platform>.<location>"
}

module "metering_starterkit" {
  source = "git::https://github.com/meshcloud/meshstack-hub.git//modules/meshstack/metering-starterkit?ref=<hub ref>"

  kubernetes_platform_ref      = one(data.meshstack_platforms.kubernetes.platforms).ref
  kubernetes_landing_zone_name = "<landing zone>"
  kubernetes_cluster_name      = "<SKE cluster name>"
  # Written out, because the ephemeral admin kubeconfig cannot feed a module variable.
  kubernetes_cluster_server = "https://api.<cluster>.<project>.s.ske.eu01.onstackit.cloud"

  stackit_enabled                = true
  stackit_platform_identifier    = "stackit.global"
  stackit_organization_id        = "<STACKIT organization id>"
  stackit_project_id             = "<STACKIT project of the metering service accounts>"
  stackit_kubernetes_oidc_issuer = "<issuer from the cluster's /.well-known/openid-configuration>"

  tcloud_enabled             = true
  tcloud_platform_identifier = "otc.global"
  tcloud_api_token           = var.tcloud_api_token

  metering_api_user   = "<meshStack API user>"
  metering_api_secret = var.metering_api_secret

  meshstack = { owning_workspace_identifier = "platform-team" }
  hub       = { git_ref = "<hub ref>" }
}
```

On another cloud, replace the SKE kubeconfig with that cloud's admin login, e.g. the
`azurerm_kubernetes_cluster` credentials on AKS. For T Cloud Public only, configure the `stackit`
provider with a placeholder:

```hcl
provider "stackit" {
  use_oidc                        = true
  service_account_email           = "unused@sa.stackit.cloud"
  service_account_federated_token = "unused"
}
```

The meshStack API user comes from meshPanel, because the metering API accepts no API keys. The
Financial Dashboard API key is valid for at most 90 days: apply again with a new one before then.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.27.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [meshstack_building_block.metering](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.service_account](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_project.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_tenant.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_clouds"></a> [clouds](#input\_clouds) | Clouds whose costs are metered, keys of `metering_building_block_definition_version_refs`. | `list(string)` | n/a | yes |
| <a name="input_landing_zone_ref"></a> [landing\_zone\_ref](#input\_landing\_zone\_ref) | Landing zone of the metering namespace. | <pre>object({<br/>    name = string<br/>  })</pre> | n/a | yes |
| <a name="input_metering_building_block_definition_version_refs"></a> [metering\_building\_block\_definition\_version\_refs](#input\_metering\_building\_block\_definition\_version\_refs) | Versions of the metering definitions, keyed by the cloud name offered in `clouds`. | <pre>map(object({<br/>    uuid = string<br/>  }))</pre> | n/a | yes |
| <a name="input_payment_method"></a> [payment\_method](#input\_payment\_method) | Payment method of the metering project. | <pre>object({<br/>    kind = string<br/>    name = string<br/>  })</pre> | n/a | yes |
| <a name="input_platform_ref"></a> [platform\_ref](#input\_platform\_ref) | Kubernetes meshPlatform the metering namespace is created on. | <pre>object({<br/>    uuid = string<br/>  })</pre> | n/a | yes |
| <a name="input_project_display_name"></a> [project\_display\_name](#input\_project\_display\_name) | Display name of the metering project in meshPanel. | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the metering project, and so part of its namespace. | `string` | n/a | yes |
| <a name="input_project_tags"></a> [project\_tags](#input\_project\_tags) | Tags of the metering project. | `map(list(string))` | n/a | yes |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | Cron schedule of every metering job. | `string` | n/a | yes |
| <a name="input_service_account_definition_version_ref"></a> [service\_account\_definition\_version\_ref](#input\_service\_account\_definition\_version\_ref) | Version of the Kubernetes Service Account definition the metering deploys with. | <pre>object({<br/>    uuid = string<br/>  })</pre> | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Workspace that gets the metering project. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
