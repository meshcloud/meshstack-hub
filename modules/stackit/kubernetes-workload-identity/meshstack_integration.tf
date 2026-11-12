variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project of the platform team that holds the backplane service accounts and gets `stackit_project_roles`."
}

variable "stackit_service_account_name" {
  type        = string
  nullable    = false
  description = "Name of the workload service account Kubernetes workloads act as; the building block runs get one named `<name>-bb`."
}

variable "stackit_organization_id" {
  type        = string
  default     = null
  description = "STACKIT organization `stackit_organization_roles` are assigned on."
}

variable "stackit_organization_roles" {
  type        = list(string)
  nullable    = false
  default     = []
  description = "Roles of the workload service account on the organization, e.g. `cost-management.cost.reader`."
}

variable "stackit_project_roles" {
  type        = list(string)
  nullable    = false
  default     = []
  description = "Roles of the workload service account on `stackit_project_id`."
}

variable "kubernetes_oidc_issuer" {
  type        = string
  nullable    = false
  description = "OIDC issuer of the service account tokens of the cluster the definition is ordered on, as its `/.well-known/openid-configuration` reports it. STACKIT must reach it."
}

variable "audience" {
  type        = string
  nullable    = false
  default     = "sts.accounts.stackit.cloud"
  description = "Token audience preselected on the order form. The STACKIT SDKs request this one by default."
}

variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
  })
  description = "Shared meshStack context, see docs."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "main"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    ref         = meshstack_building_block_definition.this.ref
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

output "workload_service_account_email" {
  description = "STACKIT service account the Kubernetes workloads act as."
  value       = module.backplane.workload_service_account_email
}

# Lookup specified runner for workload identity federation info. Null results in the default hosted runner.
data "meshstack_building_block_runner" "this" {
  metadata = {
    uuid = var.meshstack.runner_ref == null ? null : var.meshstack.runner_ref.uuid
  }

  lifecycle {
    postcondition {
      # try: a runner without any workload identity federation has a null spec.workload_identity_federation.
      condition     = try(self.spec.workload_identity_federation.azure, null) != null
      error_message = "The building block runner offers no token for Azure. We use that token as a generic OIDC token for STACKIT, so pick a runner that offers one via var.meshstack.runner_ref."
    }
  }
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/kubernetes-workload-identity/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_project_id
  service_account_name = var.stackit_service_account_name
  organization_id      = var.stackit_organization_id
  organization_roles   = var.stackit_organization_roles
  project_roles        = var.stackit_project_roles

  # The runner offers no STACKIT token, so we use the one offered for Azure as a generic OIDC token. The federation trusts its issuer and audience.
  workload_identity_federation = {
    issuer   = data.meshstack_building_block_runner.this.spec.workload_identity_federation.issuer
    audience = data.meshstack_building_block_runner.this.spec.workload_identity_federation.azure.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "STACKIT Kubernetes Workload Identity")
    description         = coalesce(var.bbd_description, "Lets a Kubernetes service account in your namespace act as a STACKIT service account, so your workload reaches STACKIT without a key.")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/kubernetes-workload-identity/buildingblock/logo.png"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "KUBERNETES" }]
    run_transparency    = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **STACKIT Kubernetes Workload Identity** building block lets a Kubernetes service account in your namespace act as a STACKIT service account the platform team provides. STACKIT trusts the tokens of that Kubernetes service account through workload identity federation, so your workload needs no STACKIT key.

    ## 🎯 When to use it

    Use this building block when you:
    - Run a workload in Kubernetes that calls STACKIT APIs, such as a metering, backup or reporting job.
    - Want no STACKIT key in a Kubernetes secret that someone has to rotate.

    ## 💡 Usage examples

    **Example 1: A CronJob reads STACKIT costs**
    A Kubernetes CronJob runs as the Kubernetes service account `mesh-metering-stackit` and mounts a token with audience `sts.accounts.stackit.cloud`. This building block federates that service account, and the job reads the costs with `STACKIT_SERVICE_ACCOUNT_EMAIL` and `STACKIT_FEDERATED_TOKEN_FILE`.

    **Example 2: Part of the Metering Starterkit**
    Platform Metering orders this building block next to the STACKIT metering CronJob when the team ticks STACKIT.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the STACKIT service account and its roles | ✅ | ❌ |
    | Operate the Kubernetes cluster and keep its OIDC issuer reachable | ✅ | ❌ |
    | Run the workload as the federated Kubernetes service account | ❌ | ✅ |
    | Mount the token with the right audience | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    runner_ref    = data.meshstack_building_block_runner.this.ref
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/kubernetes-workload-identity/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      kubernetes_service_account_name = {
        display_name                   = "Kubernetes Service Account"
        description                    = "Kubernetes service account in your namespace whose tokens may act as the STACKIT service account. It need not exist yet."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$"
        validation_regex_error_message = "Name must be at most 63 lowercase letters, digits and dashes, and not start or end with a dash."
        display_order                  = 1
      }

      audience = {
        display_name           = "Token Audience"
        description            = "Audience the workload requests for its service account token."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(var.audience)
        updateable_by_consumer = true
        display_order          = 2
      }

      stackit_project_id = {
        display_name    = "STACKIT Project"
        description     = "Project of the workload service account."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_project_id)
        display_order   = 3
      }

      # Not `stackit_service_account_email`: input keys must differ from STACKIT_SERVICE_ACCOUNT_EMAIL regardless of casing.
      workload_service_account_email = {
        display_name    = "STACKIT Service Account"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.workload_service_account_email)
        display_order   = 4
      }

      kubernetes_oidc_issuer = {
        display_name    = "Kubernetes OIDC Issuer"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.kubernetes_oidc_issuer)
        display_order   = 5
      }

      namespace = {
        display_name    = "Namespace"
        description     = "Kubernetes namespace of the tenant."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
        display_order   = 6
      }

      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Email of the STACKIT service account the provider authenticates as via WIF."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.service_account_email)
      }

      STACKIT_USE_OIDC = {
        display_name    = "STACKIT Use OIDC"
        description     = "Enables OIDC-based WIF for the STACKIT provider."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("1")
      }

      STACKIT_FEDERATED_TOKEN_FILE = {
        display_name    = "STACKIT Federated Token File"
        description     = "Path to the WIF token file injected by meshStack."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(data.meshstack_building_block_runner.this.spec.workload_identity_federation.azure.token_path)
      }
    }

    outputs = {
      service_account_email = {
        display_name    = "STACKIT Service Account"
        type            = "STRING"
        assignment_type = "NONE"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.2"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}
