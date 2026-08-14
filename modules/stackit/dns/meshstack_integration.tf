variable "stackit_organization_id" {
  type        = string
  description = "STACKIT organization ID the folder lives under. The backplane grants the service account 'iam.member-admin' here."
}

variable "stackit_folder_id" {
  type    = string
  default = null

  description = <<-EOT
  STACKIT folder ID under which every project the building block writes into lives. The backplane
  grants the service account `dns.admin` on this folder, which covers every project below it.

  This building block definition is `TENANT_LEVEL` and takes its project from `PLATFORM_TENANT_ID`,
  so the zone lands in whichever tenant project places the order and no project can be named ahead
  of it — which is what folder scope is for. STACKIT offers no dns role at organization scope.
  EOT
}

variable "stackit_dns_zone_project_ids" {
  type    = list(string)
  default = []

  description = <<-EOT
  STACKIT projects the backplane service account is granted `dns.admin` on at project scope, on top
  of `stackit_folder_id`. Name the projects that own zones the building block writes into but that
  live outside the folder — typically the platform team's own project holding the parent zone on the
  delegation path.
  EOT
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the backplane service account will be created."
}

variable "stackit_service_account_name" {
  type        = string
  default     = null
  description = "Name of the backplane service account. Defaults to 'mesh-dns'. Override when deploying multiple backplane instances in the same STACKIT project."
}

variable "stackit_additional_organization_roles" {
  type    = list(string)
  default = []

  description = <<-EOT
  Extra STACKIT roles granted to the backplane service account at organization scope. The building
  block creates a service account and a key for cert-manager and ExternalDNS, and the backplane does
  not name the role that allows it, because how far the identity should reach is your decision.
  `iam.service-account-creator`, `iam.service-account-key-admin` and `iam.service-account-admin` all
  exist at organization scope. Put the one your organization uses here, or leave the list empty and
  set `stackit_dns_service_account_enabled` to false.
  EOT
}

variable "stackit_region" {
  type        = string
  default     = "eu01"
  description = "STACKIT region used as the provider's default. STACKIT DNS itself is global."
}

variable "stackit_dns_service_account_enabled" {
  type        = bool
  default     = true
  description = "Create a service account with `dns.admin` on the zone's project and a key for it. cert-manager's DNS-01 solver and ExternalDNS both authenticate with that key."
}

variable "stackit_dns_zone_default_ttl" {
  type        = number
  default     = 300
  description = "Default time to live offered for records in an ordered zone, in seconds."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context."
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
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/dns/backplane?ref=${var.hub.git_ref}"

  project_id                    = var.stackit_project_id
  folder_id                     = var.stackit_folder_id
  zone_project_ids              = toset(var.stackit_dns_zone_project_ids)
  organization_id               = var.stackit_organization_id
  service_account_name          = coalesce(var.stackit_service_account_name, "mesh-dns")
  additional_organization_roles = var.stackit_additional_organization_roles

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = "STACKIT DNS Zone"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/dns/buildingblock/logo.png"
    description         = "Creates a STACKIT DNS zone with its record sets and a service account key that lets cert-manager and ExternalDNS manage records at runtime."
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]
    readme = chomp(<<-EOT
      This building block creates a **public DNS zone** in your STACKIT project, the records you ask
      for inside it, and a service account key your cluster uses to manage further records on its
      own.

      ## 🎯 When to use it

      Use this building block when you:
      - Need public DNS names for a workload and want to manage the records yourself.
      - Run ExternalDNS or the SKE DNS extension in a cluster and want it to publish hostnames
        automatically.
      - Want a TLS certificate issued over the ACME DNS-01 challenge, including a wildcard.

      ## 💡 Usage examples

      **Example 1: DNS for an SKE cluster**
      A team orders the zone `myteam.stackit.run` and enables the SKE DNS extension with the zone as
      its filter. Every Ingress the team creates then gets its hostname published automatically.

      **Example 2: A wildcard certificate**
      The building block returns a STACKIT service account key. cert-manager solves the ACME DNS-01
      challenge with it and issues one wildcard certificate for the zone, so a new application needs
      no certificate request at all.

      ## 📏 A free STACKIT subdomain is one label deep

      `myteam.stackit.run` is a zone. `app.myteam.stackit.run` is **not** — STACKIT rejects a zone
      that deep with *"subdomain should only have one level"*. Everything below your zone is a
      record inside it, which is exactly what ExternalDNS and cert-manager create. Order a zone per
      team, not a zone per application.

      ## 🔑 The DNS key

      The key is the raw `sa.json` that the STACKIT cert-manager webhook expects. It carries the
      `dns.admin` role on your STACKIT project, so it can write **every record in every zone of that
      project** — it cannot be narrowed to one name. Hand it only to workloads you would trust with
      the whole zone, keep it secret, and order the building block again to rotate it.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the backplane identity used to create the zone | ✅ | ❌ |
      | Run the STACKIT DNS service and its nameservers | ✅ | ❌ |
      | Choose the zone name and the record TTLs | ❌ | ✅ |
      | Create and remove the records inside the zone | ❌ | ✅ |
      | Keep the returned service account key secret | ❌ | ✅ |
      | Avoid overwriting records another workload owns | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.11.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/dns/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project ID of the existing project the zone will be created in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      service_account_email = {
        display_name    = "Service Account Email"
        description     = "Email of the STACKIT service account for WIF-based authentication."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.service_account_email)
      }

      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "STACKIT region used as the provider's default."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
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

      dns_service_account_enabled = {
        display_name    = "Create DNS Service Account"
        description     = "Create a service account with dns.admin on this project and a key for cert-manager and ExternalDNS."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_dns_service_account_enabled)
      }

      zone_name = {
        display_name                   = "Zone Name"
        description                    = "DNS name of the zone, for example 'myteam.stackit.run'. A free STACKIT subdomain carries exactly one label — put deeper names into records."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$"
        validation_regex_error_message = "The zone name must be a lowercase domain name with at least two labels and no trailing dot, for example myteam.stackit.run."
      }

      records = {
        display_name    = "Records"
        description     = "JSON object of record sets, keyed by the name relative to the zone. Example: {\"www\": {\"type\": \"A\", \"records\": [\"203.0.113.17\"]}}. Leave as {} to let ExternalDNS write the records instead."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(jsonencode({}))
      }

      zone_default_ttl = {
        display_name    = "Default Record TTL (seconds)"
        description     = "Default time to live of records inside the zone, in seconds."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(var.stackit_dns_zone_default_ttl)
      }

      contact_email = {
        display_name    = "Contact Email"
        description     = "Contact address stored on the zone. Leave empty to let STACKIT pick its own default."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("")
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

      zone_project_id = {
        display_name    = "Zone Project ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      dns_service_account_email = {
        display_name    = "DNS Service Account"
        type            = "STRING"
        assignment_type = "NONE"
      }

      dns_service_account_key = {
        display_name    = "DNS Service Account Key"
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
      version = ">= 0.21.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.110.0"
    }
  }
}
