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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

variable "approval_policies" {
  type = object({
    building_block_creation = optional(bool, false)
    user_input_changes      = optional(bool, false)
    any_input_changes       = optional(bool, false)
    manual_triggers         = optional(bool, false)
    version_upgrade         = optional(bool, false)
  })
  nullable = false
  default = {
    building_block_creation = false
    user_input_changes      = false
    any_input_changes       = false
    manual_triggers         = false
    version_upgrade         = false
  }
  description = "Run triggers that need an operator's approval before a run of this architecture is applied. The defaults are the provider's own, and the provider asserts them whenever the definition sets no policies — so a gate switched on in meshPanel is turned off again by the next apply unless it is set here."
}

variable "playground_mode" {
  type     = bool
  nullable = false
  default  = true

  description = "Deploy a throwaway platform: the platform identifier and the backplane IAM user get a random suffix so they do not occupy a name for good. Set to false for a platform that is actually used. Passed to the building block as a STATIC input, so whoever orders the architecture cannot choose. A playground platform and the building block definition it registers are not meant to be published to other workspaces."
}

variable "default_tags" {
  type = object({
    landingzone           = optional(map(list(string)), {})
    building_block        = optional(map(list(string)), {})
    project               = optional(map(list(string)), {})
    project_owner_tag_key = optional(string, "")
  })
  nullable = false

  # Spelled out rather than left to the `optional()` defaults: this feeds an input's `json_schema`
  # default, and a consumer that does not evaluate object-attribute defaulting would see unset
  # fields. See .agents/references/meshstack-integration.md.
  default = {
    landingzone = {
      LandingZoneFamily = ["sandbox"]
      confidentiality   = ["internal", "public"]
      environment       = ["dev"]
    }
    building_block = {}
    project        = {}

    # Empty, because a tag key the instance has no tag definition for fails the management project
    # with `409 TagValidation`. Set it to the owner tag your meshStack enforces, e.g. `projectOwner`.
    project_owner_tag_key = ""
  }

  description = "Starter values pre-filling the Tags form, as maps of tag key to values. Ships with an example set; override per foundation to match the instance's own tag schema. The operator can still edit, extend or clear them when ordering."
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

# The Tags input is a meshPanel form the operator fills from scratch: for each of the three tag maps
# they add as many {key, values} entries as they need — nothing is read from the instance's tag
# schema. A map of free-form keys has no form widget (meshPanel renders only declared properties), so
# each map is modelled as a growable array of entries; buildingblock/ folds them back into the
# map(list(string)) the nested integrations take.
locals {
  tag_list_schema = {
    type = "array"
    items = {
      type     = "object"
      required = ["key", "values"]
      properties = {
        key    = { type = "string", title = "Tag Key" }
        values = { type = "array", title = "Values", minItems = 1, items = { type = "string" } }
      }
    }
  }

  # The form's starter entries come from var.default_tags, so each foundation seeds keys matching its
  # own tag schema instead of anything hard-coded here. Each map is turned into the {key, values}
  # entry list the form (and the buildingblock variable) use.
  tags_default_entries = {
    for section, m in {
      landingzone    = var.default_tags.landingzone
      building_block = var.default_tags.building_block
      project        = var.default_tags.project
    } : section => [for tk, tv in m : { key = tk, values = tv }]
  }

  tags_json_schema = {
    "$schema" = "http://json-schema.org/draft-07/schema#"
    type      = "object"
    # Nothing is required. meshPanel counts an empty array as a missing required value, and does so
    # silently: the order button stays disabled with no field marked. Any of the maps may be empty,
    # and the buildingblock variable defaults each of them.
    required = []
    properties = {
      landingzone           = merge(local.tag_list_schema, { title = "Landing Zone Tags", default = local.tags_default_entries.landingzone })
      building_block        = merge(local.tag_list_schema, { title = "Building Block Tags", default = local.tags_default_entries.building_block })
      project               = merge(local.tag_list_schema, { title = "Management Project Tags", default = local.tags_default_entries.project })
      project_owner_tag_key = { type = "string", title = "Project Owner Tag Key", default = var.default_tags.project_owner_tag_key }
    }
  }
}


resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name      = coalesce(var.bbd_display_name, "T Cloud Public Landing Zone Reference Architecture")
    symbol            = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/otc-landingzone/buildingblock/logo.png"
    description       = coalesce(var.bbd_description, "Onboards a T Cloud Public (Open Telekom Cloud) domain into meshStack: the T Cloud Public Project platform with its landing zone, a management project, and optionally federated sign-in through your company identity provider.")
    support_url       = "https://console.otc.t-systems.com"
    target_type       = "WORKSPACE_LEVEL"
    run_transparency  = true
    approval_policies = var.approval_policies

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **T Cloud Public Landing Zone** building block onboards a T Cloud Public (Open Telekom Cloud)
    domain into meshStack in one run. It registers a meshStack location, creates the IAM user meshStack
    creates projects as, federates your company identity provider, and wires up the **T Cloud Public
    Project** platform together with its default landing zone.

    ## 🎯 When to use it

    Use this building block when you:
    - want application teams to request T Cloud Public projects self-service, without hand-building
      the platform, landing zone and project automation in meshStack.
    - want access to those projects to follow meshStack project roles, with users signing in through
      your company identity provider (SAML or OIDC) instead of local IAM users.

    ## 💡 Usage examples

    **Example 1: Sandbox projects for every team**
    A platform engineer runs this building block once with the domain's admin access key. Teams can
    then create meshStack projects in the T Cloud Public landing zone, each backed by a
    `eu-de_<project>` project.

    **Example 2: Federated access with Entra ID**
    The platform engineer also fills in the **Identity Provider** form with the Entra ID issuer, client
    ID and signing keys. Project users then sign in with their company account and receive exactly the
    roles their meshStack project grants them.

    ## 📦 Resources created

    - **meshStack location** – named after the chosen platform identifier.
    - **Backplane IAM user and group** – `mesh-<platform identifier>`, holding Security Administrator
      on the domain and Tenant Administrator on all projects, with an access key the building blocks
      authenticate with.
    - **T Cloud Public Project platform** – the `T Cloud Public Project` building block definition,
      platform and default landing zone. Every project gets one IAM group per meshStack role.
    - **Management project** – the meshProject `<platform identifier>-mgmt` with a tenant on the new
      platform, so the T Cloud Public project `<region>_<platform identifier>-mgmt`. Workspace owners
      and managers become its Project Admins.
    - **Federated sign-in** *(with an identity provider)* – your company SAML or OIDC provider,
      federated into the domain, the bucket every project records its members in, and the
      **Federation Mapping** building block on the management project, whose function keeps the
      identity provider's mapping in step with meshStack.

    ## 🔑 Authentication

    You provide an access key and secret key of an IAM user in the domain's `admin` group. They are
    used on every run of this building block, never by the building blocks it registers, which run
    as the backplane user instead.

    ## 🧪 Playground mode

    **Playground Mode** is fixed by whoever deployed this definition. With it on, the platform
    identifier and the backplane user name get a random suffix, so the deployment can be thrown away
    without occupying a name for good. Do not publish a playground platform to other workspaces.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the admin access key, domain and role mapping | ✅ | ❌ |
    | Federate the company identity provider | ✅ | ❌ |
    | Provision the location, backplane user and T Cloud Public Project platform | ✅ | ❌ |
    | Request T Cloud Public projects through the landing zone | ❌ | ✅ |
    | Decide who is on each project, and with which role | ❌ | ✅ |
    | Manage workloads inside the provisioned projects | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    permissions = [
      "INTEGRATION_LIST",
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
      "LANDINGZONE_LIST",
      "LANDINGZONE_SAVE",
      "LANDINGZONE_DELETE",
      "PLATFORMINSTANCE_LIST",
      "PLATFORMINSTANCE_SAVE",
      "PLATFORMINSTANCE_DELETE",
      "PROJECT_LIST",
      "PROJECT_SAVE",
      "PROJECT_DELETE",
      "PROJECTPRINCIPALROLE_LIST",
      "PROJECTPRINCIPALROLE_SAVE",
      "PROJECTPRINCIPALROLE_DELETE",
      "TENANT_LIST",
      "TENANT_SAVE",
      "TENANT_DELETE"
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/otc-landingzone/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier for the T Cloud Public platform created in meshStack (up to 20 lowercase letters, digits and dashes)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9-]{1,20}$"
        validation_regex_error_message = "platform_identifier must be 1-20 lowercase letters, digits, or dashes."
        display_order                  = 10
      }

      otc_domain_name = {
        display_name                   = "T Cloud Public Domain Name"
        description                    = "Account name exactly as the console shows it, e.g. `OTC-EU-DE-00000000001000000000`."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^OTC(-[A-Z0-9]+-[A-Z0-9]+-)?[0-9]+$"
        validation_regex_error_message = "Use the account name exactly as the console shows it, e.g. OTC-EU-DE-00000000001000000000."
        display_order                  = 20
      }

      otc_region = {
        display_name      = "Region"
        description       = "Region tenant projects are created in."
        type              = "SINGLE_SELECT"
        assignment_type   = "USER_INPUT"
        selectable_values = ["eu-de", "eu-nl"]
        default_value     = jsonencode("eu-de")
        display_order     = 30
      }

      otc_access_key = {
        display_name           = "Access Key"
        description            = "Access key of an IAM user in the domain's `admin` group (Security Administrator and Tenant Administrator), reused on every run."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 40
      }

      otc_secret_key = {
        display_name           = "Secret Key"
        description            = "Secret key belonging to the access key."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 50
      }

      identity_provider = {
        display_name           = "Identity Provider"
        description            = "Company identity provider project users sign in through. Leave it empty to skip federation; otherwise fill only the fields of the chosen protocol."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        is_optional            = true
        display_order          = 60

        # No defaults: meshPanel submits a form with defaults as a value, so an untouched form would
        # switch federation on. Choosing a protocol is what does.

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          properties = {
            protocol                    = { type = "string", title = "Protocol", enum = ["oidc", "saml"] }
            name                        = { type = "string", title = "Name (default: company-idp)" }
            email_attribute             = { type = "string", title = "Email Claim / Attribute (default: email)" }
            oidc_provider_url           = { type = "string", title = "OIDC Issuer URL" }
            oidc_client_id              = { type = "string", title = "OIDC Client ID" }
            oidc_signing_key            = { type = "string", title = "OIDC Signing Keys (JWKS JSON)" }
            oidc_authorization_endpoint = { type = "string", title = "OIDC Authorization Endpoint" }
            saml_metadata               = { type = "string", title = "SAML Metadata XML" }
          }
        })
      }

      role_mapping = {
        display_name           = "T Cloud Public Role Mapping"
        description            = "Maps each meshStack project role to the T Cloud Public system roles (by role name) its project group gets."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 70

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["admin", "user", "reader"]
          properties = {
            admin  = { type = "array", title = "admin", items = { type = "string" }, default = ["te_admin"] }
            user   = { type = "array", title = "user", items = { type = "string" }, default = ["te_admin"] }
            reader = { type = "array", title = "reader", items = { type = "string" }, default = ["readonly"] }
          }
        })
      }

      # Keep this description under roughly 200 characters. meshStack answers a longer one with
      # `500 InternalError` on the version update, not a 400.
      tags = {
        display_name           = "Tags"
        description            = "Tags forwarded to the nested integrations and the management meshProject. Build them in the form: add {key, values} entries, plus the project owner tag key."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 80
        json_schema            = jsonencode(local.tags_json_schema)
      }

      payment_method_identifier = {
        display_name    = "Payment Method Identifier"
        description     = "Payment method assigned to the management meshProject. Leave empty if your meshStack does not require one."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        display_order   = 85
      }

      creator = {
        display_name    = "Creator"
        description     = "Who ordered the landing zone, injected by meshStack."
        type            = "CODE"
        assignment_type = "AUTHOR"
      }

      workspace_members = {
        display_name    = "Workspace Members"
        description     = "Members of the owning workspace. Owners and managers become Project Admin of the management project."
        type            = "CODE"
        assignment_type = "USER_PERMISSIONS"
      }

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the existing global meshStack location instead of creating a dedicated location for this platform."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 90
      }

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location, landing zone and management project."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_order   = 100
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference used to source the nested integration) and `bbd_draft` (forwarded to its building block definition draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
        display_order   = 110
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: the identifier and backplane user get a random suffix. Do not publish such a platform or its definition to other workspaces. Set false for real use."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.playground_mode)
        display_order   = 120
      }
    }

    outputs = {
      platform_identifier = {
        display_name    = "Platform Identifier"
        type            = "STRING"
        assignment_type = "NONE"
      }

      console_login_url = {
        display_name    = "Sign In"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
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
