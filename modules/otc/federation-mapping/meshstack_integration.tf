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

variable "otc_domain_name" {
  type        = string
  description = "T Cloud Public domain (account) name, e.g. `OTC-EU-DE-00000000001000000000`."
}

variable "otc_region" {
  type        = string
  default     = "eu-de"
  description = "T Cloud Public region of the management project and the mapping bucket."
}

variable "otc_auth_url" {
  type        = string
  default     = "https://iam.eu-de.otc.t-systems.com/v3"
  description = "IAM endpoint the building block authenticates against."
}

variable "otc_access_key" {
  type        = string
  sensitive   = true
  description = "Access key the building block authenticates with. Needs Security Administrator on the domain and FunctionGraph rights in the management project."
}

variable "otc_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key belonging to `otc_access_key`."
}

variable "otc_mapping_bucket" {
  type        = string
  description = "OBS bucket project building blocks record their group membership in."
}

variable "otc_identity_provider_name" {
  type        = string
  description = "Federated identity provider whose mapping the function rebuilds."
}

variable "otc_identity_provider_email_attribute" {
  type        = string
  default     = "email"
  description = "SAML attribute or OIDC claim that carries the user's email address."
}

variable "otc_platform_type" {
  type        = string
  default     = "OTC"
  description = "Name of the custom meshStack platform type the management project's tenant lives on."
}

variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Runs this building block on the given meshStack building block runner instead of the shared one meshStack hosts."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
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
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "T Cloud Public Federation Mapping")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/otc/federation-mapping/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Runs the function that rebuilds the federated identity provider's mapping from every project's recorded group membership.")
    support_url         = "https://console.otc.t-systems.com"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = var.otc_platform_type }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    This building block runs, in your management project, the function that keeps the company
    identity provider's mapping in step with meshStack: whoever is on a meshStack project gets that
    project's T Cloud Public groups at their next sign-in.

    ## 🎯 When to use it

    The T Cloud Public Landing Zone orders it once on its management project. Order it yourself only
    when you wire a landing zone together by hand.

    ## 💡 Usage examples

    **Example 1: A colleague joins a project**
    An application team adds a colleague to their meshStack project. The project building block
    records the new member, the function rebuilds the mapping, and the colleague has the project
    role from their next sign-in.

    **Example 2: Repair after an outage**
    A bucket event was lost. The hourly resync rebuilds the mapping anyway, so nobody has to.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Run the function and its triggers in the management project | ✅ | ❌ |
    | Keep the identity provider's email claim correct | ✅ | ❌ |
    | Decide who is on each meshStack project | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"
    runner_ref = var.building_block_runner_uuid == null ? null : {
      kind = "meshBuildingBlockRunner"
      uuid = var.building_block_runner_uuid
    }

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/otc/federation-mapping/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "Project ID"
        description     = "Management project the function runs in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      region = {
        display_name    = "Region"
        description     = "Region of the management project and the mapping bucket."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.otc_region)
      }

      mapping_bucket = {
        display_name    = "Mapping Bucket"
        description     = "OBS bucket project building blocks record their group membership in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.otc_mapping_bucket)
      }

      identity_provider_name = {
        display_name    = "Identity Provider"
        description     = "Federated identity provider whose mapping the function rebuilds."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.otc_identity_provider_name)
      }

      email_attribute = {
        display_name    = "Email Claim / Attribute"
        description     = "SAML attribute or OIDC claim that carries the user's email address."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.otc_identity_provider_email_attribute)
      }

      OS_AUTH_URL = {
        display_name    = "OTC Auth URL"
        description     = "IAM endpoint the provider authenticates against."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_auth_url)
      }

      OS_DOMAIN_NAME = {
        display_name    = "OTC Domain Name"
        description     = "T Cloud Public domain the building block acts in."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_domain_name)
      }

      OS_ACCESS_KEY = {
        display_name    = "OTC Access Key"
        description     = "Access key the building block authenticates with."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = var.otc_access_key
            secret_version = nonsensitive(sha256(var.otc_access_key))
          }
        }
      }

      OS_SECRET_KEY = {
        display_name    = "OTC Secret Key"
        description     = "Secret key belonging to the access key."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = var.otc_secret_key
            secret_version = nonsensitive(sha256(var.otc_secret_key))
          }
        }
      }
    }

    outputs = {
      function_urn = {
        display_name    = "Function URN"
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
      version = ">= 0.26.2"
    }
  }
}
