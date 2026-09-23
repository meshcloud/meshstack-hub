variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region zones are placed in."
}

variable "parent_domain" {
  type        = string
  nullable    = false
  default     = "stackit.run"
  description = "Domain zones are created under. The default is the one STACKIT delegates to its customers."
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "STACKIT DNS Zone")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/dns/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Creates a STACKIT DNS zone with a wildcard record, so applications on this platform get real hostnames.")
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Creates a **DNS zone** in this project, and a wildcard record inside it, so every application
      on the platform gets a hostname that resolves.

      ## 🎯 When to use it

      Use this building block when a platform hands out one hostname per application and stage — for
      example the **STACKIT Kubernetes Platform** reference architecture, whose starter kit names an
      application's dev and prod endpoints.

      ## 📦 Resources created

      - **DNS zone** – `<subdomain>.${var.parent_domain}`.
      - **Wildcard record** – `*.<zone>` pointing at the ingress load balancer, when an address is
        given. One record covers every hostname, so ordering an application never waits for DNS.

      ## 🔐 Certificates

      The zone is enough for HTTP-01 issuance: a hostname resolves to the load balancer, so the ACME
      server reaches the challenge. A wildcard certificate needs DNS-01 instead, which needs a
      credential for this zone inside the cluster — this building block creates none.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the STACKIT project the zone lives in | ✅ | ❌ |
      | Choose the domain and keep the wildcard pointing at the ingress | ✅ | ❌ |
      | Pick application hostnames under the zone | ❌ | ✅ |
      EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/dns/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      stackit_project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project the zone is created in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name           = "STACKIT Service Account Email"
        description            = "Email of the STACKIT service account the provider authenticates as via WIF."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        is_environment         = true
        updateable_by_consumer = true
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
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }

      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "Region the zone is placed in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
      }

      parent_domain = {
        display_name    = "Parent Domain"
        description     = "Domain the zone is created under."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.parent_domain)
      }

      contact_email = {
        display_name    = "Contact Email"
        description     = "Address in the zone's SOA record, where a resolver problem is reported."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      subdomain = {
        display_name                   = "Subdomain"
        description                    = "Label this zone occupies under the parent domain. `my-platform` gives `my-platform.${var.parent_domain}`."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$"
        validation_regex_error_message = "Subdomain must be a DNS label: lowercase letters, digits and dashes, not starting or ending with a dash."
      }

      wildcard_target_ip = {
        display_name           = "Wildcard Target IP"
        description            = "IPv4 address `*.<zone>` points at, typically an ingress load balancer. Leave empty to create no record."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        is_optional            = true
        updateable_by_consumer = true
      }

      default_ttl = {
        display_name    = "Default TTL"
        description     = "Default TTL in seconds for records in this zone."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(300)
      }
    }

    outputs = {
      zone_name = {
        display_name    = "Zone Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      zone_id = {
        display_name    = "Zone ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      zone_url = {
        display_name    = "Open Zone"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }

    permissions = []
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.25.2"
    }
  }
}
