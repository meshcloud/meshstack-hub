---
name: Kubernetes Platform Registration
supportedPlatforms:
  - kubernetes
description: Registers a Kubernetes cluster as a meshStack platform of type kubernetes, with its namespace landing zones and the in-cluster service accounts meshStack authenticates with.
# The module creates its identities inside the target cluster and receives the cluster credentials
# as inputs, so there is no cloud-side setup to perform ahead of time.
requiresBackplane: false
---

# Kubernetes Platform Registration Building Block

This module registers a Kubernetes cluster as a meshStack platform whose tenants are namespaces. It
creates three things:

1. The in-cluster identities meshStack authenticates with — a replicator service account that creates
   namespaces, resource quotas and role bindings, and a metering service account that reads pods and
   persistent volume claims.
2. A `meshstack_platform` of type `kubernetes` that points at the cluster's API server.
3. One `meshstack_landingzone` per environment, each with its own quotas and tags.

Nothing in the module names a cloud provider. It serves STACKIT Kubernetes Engine today and any
conformant cluster later, as long as the cluster accepts service account tokens for authentication.

## Why this module cannot serve AKS

meshStack models AKS namespace platforms differently, and the difference is a modelling fact rather
than a design choice:

- AKS uses `spec.config.aks`, not `spec.config.kubernetes`, and its landing zones use
  `platform_properties.aks`.
- AKS authenticates with an Entra service principal through workload identity federation, read from
  `data.meshstack_integrations`, instead of an in-cluster service account token.
- The AKS config carries fields that have no counterpart here: `group_name_pattern`,
  `user_lookup_strategy`, `send_azure_invitation_mail`, `redirect_url`, `aks_subscription_id`,
  `aks_cluster_name`, `aks_resource_group` and the Entra tenant.

An AKS platform registration therefore needs its own module.

## What the module replaces

Five copies of this configuration existed before, three of them on the SKE side. This module is built
from those three and turns every value they disagreed on into a variable. The defaults are the
`likvid-cloudfoundation` values.

## Where the credentials come from

The module needs cluster-admin credentials to create the service accounts and the cluster roles.
Supply them through `kube_host`, `cluster_ca_certificate`, `client_certificate` and `client_key`, for
example from the `provider_config` output of `modules/stackit/ske`. Callers that generate their own
`provider "kubernetes"` block — Terragrunt does this — can leave the three credential variables unset
and pass only `kube_host`, which meshStack also stores as the platform endpoint.

## Running more than one registration on one cluster

The in-cluster resource names are fixed (`meshfed-service`, `meshfed-metering`) so that an existing
deployment of the `terraform-kubernetes-meshplatform` module can be moved into this one without
renaming anything. Set `resource_name_suffix` when a single cluster carries more than one meshStack
platform registration, so the service accounts and cluster roles do not collide.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.20.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role.metering](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role.replicator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.metering](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_cluster_role_binding.replicator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_namespace.meshcloud](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.metering](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.replicator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.metering](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_service_account.replicator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [meshstack_landingzone.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/landingzone) | resource |
| [meshstack_platform.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/platform) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_client_certificate"></a> [client\_certificate](#input\_client\_certificate) | PEM encoded client certificate the module authenticates with while it creates the in-cluster service accounts. Leave unset when the caller supplies its own provider configuration. | `string` | `null` | no |
| <a name="input_client_key"></a> [client\_key](#input\_client\_key) | PEM encoded client key that belongs to `client_certificate`. Leave unset when the caller supplies its own provider configuration. | `string` | `null` | no |
| <a name="input_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#input\_cluster\_ca\_certificate) | PEM encoded CA certificate of the cluster. Leave unset when the caller supplies its own provider configuration. | `string` | `null` | no |
| <a name="input_disable_ssl_validation"></a> [disable\_ssl\_validation](#input\_disable\_ssl\_validation) | Skip SSL validation when meshStack calls the Kubernetes API server. SKE clusters serve a certificate that meshStack does not trust by default, which is why this is on. | `bool` | `true` | no |
| <a name="input_documentation_url"></a> [documentation\_url](#input\_documentation\_url) | Link to the platform documentation shown in meshPanel. | `string` | `""` | no |
| <a name="input_kube_host"></a> [kube\_host](#input\_kube\_host) | URL of the Kubernetes API server, for example `https://k8s.example.com:6443`. meshStack calls this URL to replicate tenants and to collect metering data. | `string` | n/a | yes |
| <a name="input_landing_zones"></a> [landing\_zones](#input\_landing\_zones) | Landing zones to create for the platform, keyed by environment. The key becomes the suffix of the landing zone identifier, for example `dev` gives `ske-namespace-dev`. | <pre>map(object({<br/>    display_name = string<br/>    description  = string<br/>    info_link    = optional(string, "")<br/>    tags         = optional(map(list(string)), {})<br/>    quotas       = optional(list(object({ key = string, value = number })), [])<br/>  }))</pre> | <pre>{<br/>  "dev": {<br/>    "description": "Landing zone for development workloads.",<br/>    "display_name": "SKE Kubernetes Namespace – Development",<br/>    "quotas": [<br/>      {<br/>        "key": "limits.cpu",<br/>        "value": 500<br/>      },<br/>      {<br/>        "key": "requests.cpu",<br/>        "value": 250<br/>      },<br/>      {<br/>        "key": "limits.memory",<br/>        "value": 512<br/>      },<br/>      {<br/>        "key": "requests.memory",<br/>        "value": 256<br/>      },<br/>      {<br/>        "key": "requests.storage",<br/>        "value": 1<br/>      },<br/>      {<br/>        "key": "persistentvolumeclaims",<br/>        "value": 2<br/>      }<br/>    ],<br/>    "tags": {<br/>      "LandingZoneFamily": [<br/>        "cloud-native"<br/>      ],<br/>      "confidentiality": [<br/>        "internal"<br/>      ],<br/>      "environment": [<br/>        "dev"<br/>      ]<br/>    }<br/>  },<br/>  "prod": {<br/>    "description": "Landing zone for production workloads.",<br/>    "display_name": "SKE Kubernetes Namespace – Production",<br/>    "quotas": [<br/>      {<br/>        "key": "limits.cpu",<br/>        "value": 1000<br/>      },<br/>      {<br/>        "key": "requests.cpu",<br/>        "value": 500<br/>      },<br/>      {<br/>        "key": "limits.memory",<br/>        "value": 1024<br/>      },<br/>      {<br/>        "key": "requests.memory",<br/>        "value": 512<br/>      },<br/>      {<br/>        "key": "requests.storage",<br/>        "value": 2<br/>      },<br/>      {<br/>        "key": "persistentvolumeclaims",<br/>        "value": 4<br/>      }<br/>    ],<br/>    "tags": {<br/>      "LandingZoneFamily": [<br/>        "cloud-native"<br/>      ],<br/>      "confidentiality": [<br/>        "public"<br/>      ],<br/>      "environment": [<br/>        "prod"<br/>      ]<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_location_identifier"></a> [location\_identifier](#input\_location\_identifier) | Identifier of the meshStack location the platform is registered in. | `string` | n/a | yes |
| <a name="input_metering_additional_rules"></a> [metering\_additional\_rules](#input\_metering\_additional\_rules) | Extra RBAC rules added to the metering cluster role. | <pre>list(object({<br/>    api_groups        = list(string)<br/>    resources         = list(string)<br/>    verbs             = list(string)<br/>    resource_names    = optional(list(string))<br/>    non_resource_urls = optional(list(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_metering_enabled"></a> [metering\_enabled](#input\_metering\_enabled) | Create the metering service account and register metering on the platform. Turn this off when meshStack should not collect usage data from the cluster. | `bool` | `true` | no |
| <a name="input_metering_processing"></a> [metering\_processing](#input\_metering\_processing) | How long meshMetering keeps timelines and raw data. Only used when `metering_enabled` is true. | <pre>object({<br/>    compact_timelines_after_days = optional(number, 30)<br/>    delete_raw_data_after_days   = optional(number, 65)<br/>  })</pre> | `{}` | no |
| <a name="input_namespace_name_pattern"></a> [namespace\_name\_pattern](#input\_namespace\_name\_pattern) | Pattern meshStack uses to name the namespace it creates for a tenant. | `string` | `"#{workspaceIdentifier}-#{projectIdentifier}"` | no |
| <a name="input_owning_workspace_identifier"></a> [owning\_workspace\_identifier](#input\_owning\_workspace\_identifier) | Identifier of the meshStack workspace that owns the platform and its landing zones. | `string` | n/a | yes |
| <a name="input_platform_description"></a> [platform\_description](#input\_platform\_description) | Description of the platform as users see it in meshPanel. | `string` | `"Provides a kubernetes namespace on STACKIT Kubernetes Engine (SKE)."` | no |
| <a name="input_platform_display_name"></a> [platform\_display\_name](#input\_platform\_display\_name) | Name of the platform as users see it in meshPanel. | `string` | `"Kubernetes namespace on SKE"` | no |
| <a name="input_platform_name"></a> [platform\_name](#input\_platform\_name) | meshStack platform identifier. The landing zones derive their names from it, for example `ske-namespace-dev`. | `string` | `"ske-namespace"` | no |
| <a name="input_quota_definitions"></a> [quota\_definitions](#input\_quota\_definitions) | Quota keys a tenant can request on this platform, with the upper bound and the threshold below which meshStack approves a request automatically. | <pre>list(object({<br/>    quota_key               = string<br/>    label                   = string<br/>    description             = string<br/>    unit                    = string<br/>    min_value               = number<br/>    max_value               = number<br/>    auto_approval_threshold = number<br/>  }))</pre> | <pre>[<br/>  {<br/>    "auto_approval_threshold": 1000,<br/>    "description": "The sum of CPU limits across all pods in a non-terminal state cannot exceed this value.",<br/>    "label": "CPU limit",<br/>    "max_value": 1000,<br/>    "min_value": 0,<br/>    "quota_key": "limits.cpu",<br/>    "unit": "m"<br/>  },<br/>  {<br/>    "auto_approval_threshold": 500,<br/>    "description": "The sum of CPU requests across all pods in a non-terminal state cannot exceed this value.",<br/>    "label": "CPU requests",<br/>    "max_value": 1000,<br/>    "min_value": 0,<br/>    "quota_key": "requests.cpu",<br/>    "unit": "m"<br/>  },<br/>  {<br/>    "auto_approval_threshold": 1024,<br/>    "description": "The sum of memory limits across all pods in a non-terminal state cannot exceed this value.",<br/>    "label": "Memory limit",<br/>    "max_value": 1024,<br/>    "min_value": 0,<br/>    "quota_key": "limits.memory",<br/>    "unit": "Mi"<br/>  },<br/>  {<br/>    "auto_approval_threshold": 512,<br/>    "description": "The sum of memory requests across all pods in a non-terminal state cannot exceed this value.",<br/>    "label": "Memory requests",<br/>    "max_value": 1024,<br/>    "min_value": 0,<br/>    "quota_key": "requests.memory",<br/>    "unit": "Mi"<br/>  },<br/>  {<br/>    "auto_approval_threshold": 2,<br/>    "description": "Across all persistent volume claims, the sum of storage requests cannot exceed this value.",<br/>    "label": "Total Storage Requests",<br/>    "max_value": 5,<br/>    "min_value": 0,<br/>    "quota_key": "requests.storage",<br/>    "unit": "Gi"<br/>  },<br/>  {<br/>    "auto_approval_threshold": 2,<br/>    "description": "The total number of PersistentVolumeClaims that can exist in the namespace.",<br/>    "label": "Persistent Volume Claims",<br/>    "max_value": 4,<br/>    "min_value": 0,<br/>    "quota_key": "persistentvolumeclaims",<br/>    "unit": ""<br/>  }<br/>]</pre> | no |
| <a name="input_replicator_additional_rules"></a> [replicator\_additional\_rules](#input\_replicator\_additional\_rules) | Extra RBAC rules added to the replicator cluster role. | <pre>list(object({<br/>    api_groups        = list(string)<br/>    resources         = list(string)<br/>    verbs             = list(string)<br/>    resource_names    = optional(list(string))<br/>    non_resource_urls = optional(list(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_resource_name_suffix"></a> [resource\_name\_suffix](#input\_resource\_name\_suffix) | Suffix appended to the in-cluster resource names. Set it when one cluster carries more than one meshStack platform registration, so the service accounts and cluster roles do not collide. | `string` | `""` | no |
| <a name="input_service_account_namespace"></a> [service\_account\_namespace](#input\_service\_account\_namespace) | Namespace that holds the replicator and metering service accounts. | `string` | `"meshcloud"` | no |
| <a name="input_support_url"></a> [support\_url](#input\_support\_url) | Link to the support channel shown in meshPanel. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_landing_zone_identifiers"></a> [landing\_zone\_identifiers](#output\_landing\_zone\_identifiers) | meshStack landing zone identifiers keyed by environment. |
| <a name="output_landing_zone_refs"></a> [landing\_zone\_refs](#output\_landing\_zone\_refs) | meshStack landing zone references keyed by environment, for use in building block compositions. |
| <a name="output_metering_token"></a> [metering\_token](#output\_metering\_token) | Access token of the metering service account, or null when metering is off. |
| <a name="output_platform_identifier"></a> [platform\_identifier](#output\_platform\_identifier) | Platform identifier in the `<name>.<location>` form meshStack uses to address a platform, for example `ske-namespace.eu-de-central`. |
| <a name="output_platform_ref"></a> [platform\_ref](#output\_platform\_ref) | Reference to the platform, for use in building block compositions that create tenants on it. |
| <a name="output_replicator_token"></a> [replicator\_token](#output\_replicator\_token) | Access token of the replicator service account. meshStack already holds this token, so you only need the output to debug the cluster connection. |
<!-- END_TF_DOCS -->
