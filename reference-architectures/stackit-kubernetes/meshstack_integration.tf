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
  description = "Run triggers that need an operator's approval on this architecture's own runs. The platform definitions it registers take theirs from the Approval Policies input."
}

variable "starterkit_add_random_name_suffix" {
  type        = bool
  nullable    = false
  default     = true
  description = "Append a random suffix to the projects the starterkit creates. Keep it as the adopted starterkit had it: an upgrade that changes it renames, and so replaces, every project and tenant it created."
}

variable "platform_engineer_role_mapping" {
  type = object({
    git                = optional(map(list(string)))
    container_registry = optional(map(list(string)))
    secrets_manager    = optional(map(list(string)))
  })
  nullable = false
  default = {
    git                = null
    container_registry = null
    secrets_manager    = null
  }
  description = "Maps the meshStack project roles on the platform's project to roles on the Git instance (Forgejo `owner`, `writer`, `reader`), the container registry and the Secrets Manager (STACKIT project roles). A service left out keeps its module's default: Project Admins become Forgejo owners, registry admins and Secrets Manager readers."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are propagated to the building block definition metadata."
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
  `bbd_draft`: If true, the application team definitions (starter kit, Git repository, Forgejo connector)
  are kept in draft mode. This definition and the platform's own definitions are always drafts, so they
  stay in the owning workspace.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

# meshPanel has no form widget for a map of free-form keys, so tag maps and stages are growable lists;
# buildingblock/ folds them back into maps.
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

  approval_gates = ["building_block_creation", "user_input_changes", "any_input_changes", "manual_triggers", "version_upgrade"]

  approval_policies_schema = {
    type                 = "object"
    additionalProperties = false
    required             = local.approval_gates
    properties           = { for gate in local.approval_gates : gate => { type = "boolean", title = gate } }
  }

  uuid_pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name          = "STACKIT Kubernetes Platform Reference Architecture"
    display_name_template = "STACKIT Kubernetes Platform"
    symbol                = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-kubernetes/buildingblock/logo.png"
    description           = "Bootstraps a Kubernetes platform on STACKIT on top of a STACKIT Landing Zone: SKE cluster, in-cluster platform services and the meshStack SKE platform with one landing zone per stage."
    support_url           = "https://portal.stackit.cloud/ske"
    target_type           = "WORKSPACE_LEVEL"
    run_transparency      = true
    approval_policies     = var.approval_policies

    readme = chomp(<<-EOT
    The **STACKIT Kubernetes Platform** building block builds a Kubernetes platform on STACKIT from
    one order, on top of an existing STACKIT Landing Zone.

    ## 📦 Resources created

    - **Hosting project** – a STACKIT project (self-hosted as a meshStack tenant) that the cluster
      runs in.
    - **Service account** – ordered from the landing zone's STACKIT Service Account definition.
    - **Platform Services** – one nested building block that orders everything below as the service
      account.
    - **Secrets Manager** – a STACKIT Secrets Manager instance that holds every credential the
      building blocks below create, so no building block shows one as an output.
    - **SKE cluster** – a managed STACKIT Kubernetes Engine cluster with an admin kubeconfig.
    - **In-cluster services** – HAProxy ingress, cert-manager with a Let's Encrypt ClusterIssuer, and
      the meshStack replication/metering service accounts.
    - **DNS zone** – a zone under the DNS Parent Domain with a wildcard record pointing at the
      ingress load balancer.
    - **AI Model Serving** – a STACKIT Model Serving token every application namespace receives.
    - **STACKIT Git instance** – a managed Forgejo with its organization and a STACKIT-hosted shared
      runner.
    - **Container registry** – a Harbor project for the platform's application images, with the
      template's base images mirrored into it.
    - **meshStack SKE platform** – a Kubernetes platform with one landing zone per stage, dev and
      prod unless the Stages input says otherwise, that application teams order Kubernetes
      namespaces from.

    ## 🔁 Phase 2

    Only the STACKIT portal can link a Harbor robot account to the platform:

    1. **Order it.** The summary says how to create the robot and link it to the platform's
       service account.
    2. **Set Phase 2 Completed** on the same building block. The run then mints the registry's
       push and pull robots and registers the **STACKIT Git Repository**, **SKE Forgejo
       Connector** and **SKE Starterkit** definitions application teams order. It fails while no
       robot is linked.

    ## 🔑 Authentication

    Copy the **STACKIT Landing Zone** input from the summary of the landing zone building block. No
    STACKIT credential is entered or held: every STACKIT building block authenticates as the
    platform's service account through workload identity federation.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the landing zone reference and host platform inputs | ✅ | ❌ |
    | Provision the hosting project, cluster, platform services and meshStack platform | ✅ | ❌ |
    | Order a Kubernetes namespace from the platform's landing zones | ❌ | ✅ |
    | Manage workloads in their namespaces | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = true
    deletion_mode = "DELETE"

    # meshStack lets a run order a building block only if it holds every permission of its
    # definition, so this list covers the federation and the nested definition as well.
    permissions = [
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
      "INTEGRATION_LIST",
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
        repository_path                = "reference-architectures/stackit-kubernetes/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier of the Kubernetes platform created in meshStack (letters, digits and dashes only). In playground mode a random suffix is appended to it."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9-]+$"
        validation_regex_error_message = "platform_identifier must only contain letters, digits, and dashes."
        display_order                  = 10
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: the identifier gets a random suffix and nothing is protected against deletion. Do not publish such a platform or its definitions to other workspaces. Cannot be changed after the order."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 20
      }

      landingzone = {
        display_name    = "STACKIT Landing Zone"
        description     = "HCL object of refs this platform is built on. Copy it from the summary of the STACKIT Landing Zone building block."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        display_order   = 30
      }

      dns_parent_domain = {
        display_name           = "DNS Parent Domain"
        description            = "Domain the platform's DNS zone is created under. The default is the one STACKIT delegates to its customers, so the zone resolves without owning a domain."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("stackit.run")
        updateable_by_consumer = true
        display_order          = 40
      }

      dns_subdomain = {
        display_name                   = "DNS Subdomain"
        description                    = "Label the platform's DNS zone occupies under the parent domain. Leave empty to use the platform identifier."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        is_optional                    = true
        updateable_by_consumer         = true
        value_validation_regex         = "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$"
        validation_regex_error_message = "DNS subdomain must be a DNS label: lowercase letters, digits and dashes, not starting or ending with a dash."
        display_order                  = 50
      }

      cluster_issuer_email = {
        display_name    = "ClusterIssuer Email"
        description     = "Overrides the Let's Encrypt contact email registered for the ACME ClusterIssuer. Leave empty to use the platform's service account."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        display_order   = 60
      }

      phase2_completed = {
        display_name           = "Phase 2 Completed"
        description            = "Set to true once a Harbor robot is linked to the platform's service account, as the summary describes; the run fails while none is."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(false)
        updateable_by_consumer = true
        display_order          = 70
      }

      stages = {
        display_name           = "Stages"
        description            = "One landing zone per stage, each with its own tags: `landingzone` for its landing zone, `project` for the starter kit's meshProjects (a tag a policy pairs goes on both), and optional `quotas`."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value = jsonencode(jsonencode([
          { name = "dev", landingzone = [], project = [] },
          { name = "prod", landingzone = [], project = [] },
        ]))
        display_order = 80

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "array"
          minItems  = 1
          items = {
            type                 = "object"
            additionalProperties = false
            required             = ["name", "landingzone", "project"]
            properties = {
              name        = { type = "string", title = "name", pattern = "^[a-z0-9-]+$" }
              landingzone = merge(local.tag_list_schema, { title = "landingzone" })
              project     = merge(local.tag_list_schema, { title = "project" })
              quotas = {
                type  = "array"
                title = "quotas"
                items = {
                  type                 = "object"
                  additionalProperties = false
                  required             = ["key", "value"]
                  properties = {
                    key   = { type = "string", title = "key" }
                    value = { type = "number", title = "value" }
                  }
                }
              }
            }
          }
        })
      }

      # Keep this description under roughly 200 characters: meshStack answers a longer one with a 500.
      tags = {
        display_name           = "Tags"
        description            = "Tags as {key, values} entries for landing zones, platform and app team building blocks, the platform project and the starterkit projects, plus the project owner tag key."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value = jsonencode(jsonencode({
          landingzone               = []
          building_block            = []
          starterkit_building_block = []
          project                   = []
          starterkit_project        = []
        }))
        display_order = 90

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["landingzone", "building_block", "starterkit_building_block", "project", "starterkit_project"]
          properties = {
            landingzone               = merge(local.tag_list_schema, { title = "Landing Zone Tags" })
            building_block            = merge(local.tag_list_schema, { title = "Platform Building Block Tags" })
            starterkit_building_block = merge(local.tag_list_schema, { title = "App Team Building Block Tags" })
            project                   = merge(local.tag_list_schema, { title = "Platform Project Tags" })
            starterkit_project        = merge(local.tag_list_schema, { title = "Starterkit Project Tags" })
            project_owner_tag_key = {
              type        = "string"
              title       = "Project Owner Tag Key"
              description = "Tag on the platform project and the starterkit projects that gets the creator's display name. Leave empty to set none."
            }
          }
        })
      }

      approval_policies = {
        display_name           = "Approval Policies"
        description            = "Run triggers that need an operator's approval before a run of a platform definition this architecture registers is applied. Adopting a platform needs them."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(jsonencode({ for gate in local.approval_gates : gate => false }))
        display_order          = 100
        json_schema            = jsonencode(local.approval_policies_schema)
      }

      starterkit_approval_policies = {
        display_name           = "Starterkit Approval Policies"
        description            = "Run triggers that need an operator's approval before a run of an application team building block (Git repository, Forgejo connector, starterkit) is applied."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(jsonencode({ for gate in local.approval_gates : gate => false }))
        display_order          = 110
        json_schema            = jsonencode(local.approval_policies_schema)
      }

      landingzone_variant = {
        display_name    = "Landing Zone Variant"
        description     = "Landing zone the hosting project is created in. `networked` requires hub-and-spoke networking enabled on the STACKIT Landing Zone."
        type            = "SINGLE_SELECT"
        assignment_type = "USER_INPUT"
        # TODO only include 'networked' if enabled in stackit lz ref arch (add 'network_enabled' variable here, default false?)
        selectable_values = ["default", "networked"]
        default_value     = jsonencode("default")
        display_order     = 120
      }

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the existing global meshStack location instead of creating a dedicated location for this platform."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 130
      }

      ai_model = {
        display_name           = "AI Model"
        description            = "Model applications on this platform default to. Must be one STACKIT Model Serving's `/v1/models` endpoint serves."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("openai/gpt-oss-120b")
        updateable_by_consumer = true
        display_order          = 140
      }

      starterkit_app_name = {
        display_name           = "Starter Kit Image Name"
        description            = "Image name every application ordered from the starter kit builds under, set on its repository as APP_NAME."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("ai-summarizer")
        updateable_by_consumer = true
        display_order          = 150
      }

      starterkit_repo_clone_addr = {
        display_name           = "Starter Kit Template Repository"
        description            = "Git URL the starter kit initialises every application repository from."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git")
        updateable_by_consumer = true
        display_order          = 160
      }

      project_identifier = {
        display_name    = "Project Identifier"
        description     = "Identifier of the hosting meshProject. Leave empty to use `<platform identifier>-ske`."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        display_order   = 170
      }

      cluster_name = {
        display_name                   = "Cluster Name"
        description                    = "Overrides the generated SKE cluster name. 2-11 chars, lowercase alphanumeric or dashes."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        is_optional                    = true
        value_validation_regex         = "^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$"
        validation_regex_error_message = "Cluster name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
        display_order                  = 180
      }

      payment_method_identifier = {
        display_name    = "Payment Method Identifier"
        description     = "Payment method assigned to the hosting meshProject. Leave empty to assign none."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        display_order   = 190
      }

      quota_definitions = {
        display_name           = "Quota Definitions"
        description            = "Quotas the meshPlatform offers, with their limits. CPU in millicores (m), memory in mebibytes (Mi). Leave empty to keep the defaults."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        is_optional            = true
        updateable_by_consumer = true
        display_order          = 200

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "array"
          items = {
            type                 = "object"
            additionalProperties = false
            required             = ["quota_key", "label", "description", "unit", "min_value", "max_value", "auto_approval_threshold"]
            properties = {
              quota_key               = { type = "string", title = "quota_key" }
              label                   = { type = "string", title = "label" }
              description             = { type = "string", title = "description" }
              unit                    = { type = "string", title = "unit" }
              min_value               = { type = "number", title = "min_value" }
              max_value               = { type = "number", title = "max_value" }
              auto_approval_threshold = { type = "number", title = "auto_approval_threshold" }
            }
          }
        })
      }

      imports = {
        display_name    = "Imports"
        description     = "Existing resources and definitions to take over when adopting a platform built before this architecture; see Adopting Existing Resources in the README. Leave empty to create everything."
        type            = "JSON"
        assignment_type = "USER_INPUT"
        is_optional     = true
        condition       = "!input.playground_mode"
        display_order   = 210

        json_schema = jsonencode({
          "$schema"            = "http://json-schema.org/draft-07/schema#"
          type                 = "object"
          additionalProperties = false
          properties = {
            project = {
              type                 = "object"
              title                = "project"
              description          = "Adopt the hosting project. Every other import except starterkit_definitions needs it."
              additionalProperties = false
              properties = {
                display_name   = { type = "string", title = "display_name" }
                admin_bindings = { type = "object", title = "admin_bindings", description = "Existing Project Admin binding names by username.", additionalProperties = { type = "string" } }
              }
            }
            adopt_ske = {
              type        = "boolean"
              title       = "adopt_ske"
              description = "Adopt the existing SKE cluster named by Cluster Name."
            }
            git = {
              type                 = "object"
              title                = "git"
              additionalProperties = false
              required             = ["instance_id", "instance_name", "forgejo_organization"]
              properties = {
                instance_id          = { type = "string", title = "instance_id" }
                instance_name        = { type = "string", title = "instance_name" }
                forgejo_organization = { type = "string", title = "forgejo_organization" }
              }
            }
            dns = {
              type                 = "object"
              title                = "dns"
              additionalProperties = false
              required             = ["zone_id", "record_set_id"]
              properties = {
                zone_id       = { type = "string", title = "zone_id" }
                record_set_id = { type = "string", title = "record_set_id" }
              }
            }
            adopt_ingress = {
              type        = "boolean"
              title       = "adopt_ingress"
              description = "Adopt haproxy, cert-manager and the ClusterIssuer. Needs adopt_ske."
            }
            secrets_manager = {
              type                 = "object"
              title                = "secrets_manager"
              additionalProperties = false
              required             = ["instance_id"]
              properties = {
                instance_id = { type = "string", title = "instance_id" }
              }
            }
            container_registry = {
              type                 = "object"
              title                = "container_registry"
              additionalProperties = false
              required             = ["artifactory_id", "registry_name"]
              properties = {
                artifactory_id = { type = "string", title = "artifactory_id" }
                registry_name  = { type = "string", title = "registry_name" }
              }
            }
            kubernetes_platform = {
              type                 = "object"
              title                = "kubernetes_platform"
              description          = "Adopt the meshPlatform and its landing zones by name. Needs adopt_ske."
              additionalProperties = false
              properties = {
                platform_name     = { type = "string", title = "platform_name" }
                location_name     = { type = "string", title = "location_name" }
                landingzone_names = { type = "object", title = "landingzone_names", description = "Existing landing zone names by stage.", additionalProperties = { type = "string" } }
              }
            }
            starterkit_definitions = {
              type                 = "object"
              title                = "starterkit_definitions"
              description          = "Adopt the app team definitions by uuid."
              additionalProperties = false
              properties = {
                starterkit        = { type = "string", title = "starterkit", pattern = local.uuid_pattern }
                git_repository    = { type = "string", title = "git_repository", pattern = local.uuid_pattern }
                forgejo_connector = { type = "string", title = "forgejo_connector", pattern = local.uuid_pattern }
              }
            }
          }
        })
      }

      # A sensitive input cannot be JSON.
      import_secrets = {
        display_name           = "Import Secrets"
        description            = "HCL object `{git = {forgejo_api_token}}`: the token of an owner of the Forgejo organization that `imports.git` adopts. Set it to `{}` once the organization is adopted."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        sensitive              = {}
        is_optional            = true
        updateable_by_consumer = true
        condition              = "!input.playground_mode && input.imports.git.instance_id != \"\""
        display_order          = 220
      }

      starterkit_add_random_name_suffix = {
        display_name    = "Starterkit Random Name Suffix"
        description     = "Whether the starterkit appends a random suffix to the projects it creates."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.starterkit_add_random_name_suffix)
        display_order   = 300
      }

      platform_engineer_role_mapping = {
        display_name    = "Platform Engineer Role Mapping"
        description     = "HCL object of role mappings by service (`git`, `container_registry`, `secrets_manager`) for the members of the platform's project."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.platform_engineer_role_mapping))
        display_order   = 310
      }

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location, landing zones and hosting project."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_order   = 900
      }

      creator = {
        display_name    = "Creator"
        description     = "Creator of the platform, injected by meshStack."
        type            = "CODE"
        assignment_type = "AUTHOR"
        display_order   = 910
      }

      workspace_members = {
        display_name    = "Workspace Members"
        description     = "Members of the owning workspace. Owners and managers become Project Admin of the platform's project."
        type            = "CODE"
        assignment_type = "USER_PERMISSIONS"
        display_order   = 920
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference to source nested modules from) and `bbd_draft` (draft state of the application team definitions)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
        display_order   = 1000
      }
    }

    outputs = {
      ske_project_url = {
        display_name    = "Open Hosting Project"
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
      version = ">= 0.27.0"
    }
  }
}
