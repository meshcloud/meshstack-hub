variable "ai_cluster_kubeconfig" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "kubeconfig of the AI platform cluster, as YAML. The gateway and the shared ClickHouse are installed here, and every tenant's tracing instance lands here later. It reaches the building block as an encrypted static input, so one building block definition targets one cluster. A service account token and a client certificate pair are both accepted."
}

variable "app_cluster_kubeconfig" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "kubeconfig of the cluster the application teams' namespaces live on, as YAML. Only the Secret carrying a tenant's model credential is written there. Leave it empty when the applications run on the AI platform cluster itself."
}

variable "app_platform_identifier" {
  type        = string
  nullable    = false
  default     = ""
  description = "Full identifier of the meshStack platform the application cluster is registered as, in the `<platform>.<location>` form. It is the `platform_identifier` output of the Kubernetes architecture below this one."
}

variable "apps_domain" {
  type        = string
  nullable    = false
  default     = ""
  description = "Domain the cluster's application hostnames live under, for example `ai.likvid.stackit.run`. It is the `apps_domain` output of the Kubernetes architecture below this one: every name under it already resolves and is already covered by the wildcard certificate, so this architecture creates no DNS record and requests no certificate."
}

variable "ingress_class_name" {
  type        = string
  nullable    = false
  default     = "haproxy"
  description = "Name of the IngressClass that serves the gateway and the tenants' tracing instances."
}

variable "litellm_hostname_label" {
  type        = string
  nullable    = false
  default     = "litellm"
  description = "Label the gateway is published under inside `apps_domain`, so it answers on `<label>.<apps_domain>`."
}

variable "litellm_model_backends" {
  type = map(object({
    model    = string
    api_base = string
  }))
  nullable = false
  default  = {}

  description = <<-EOT
  Models the gateway offers, keyed by the alias a caller puts in the `model` field of a request.
  `model` is the name at the upstream provider and `api_base` its OpenAI-compatible base URL,
  including the `/v1` suffix.

  An Azure OpenAI deployment, a STACKIT AI Model Serving deployment and a self-hosted vLLM are three
  entries of the same shape here, and a tenant sees only the alias.
  EOT
}

variable "litellm_model_backend_api_keys" {
  type        = map(string)
  nullable    = false
  default     = {}
  sensitive   = true
  description = "API key per model alias, keyed exactly like `litellm_model_backends`. These are the platform team's upstream credentials, and no tenant ever sees one."
}

variable "litellm_console_sso_enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "Let the platform team log in to the gateway's admin console through the identity provider. The console holds at most five users, because native single sign-on is free in the open-source proxy up to that number and the sixth login locks out everyone."
}

variable "litellm_replica_count" {
  type        = number
  nullable    = false
  default     = 1
  description = "Number of gateway pods. Anything above 1 needs `litellm_redis_enabled`, because each pod otherwise counts rate limits and spend on its own."
}

variable "litellm_redis_enabled" {
  type        = bool
  nullable    = false
  default     = false
  description = "Point the gateway at the shared Valkey instance for cross-pod coordination. The gateway takes no database index, so it shares the keyspace the tracing instances are separated in by index and prefix."
}

variable "clickhouse_replicas" {
  type        = number
  nullable    = false
  default     = 1
  description = "Number of ClickHouse replicas. The default is sized for a demonstration cluster and gives no redundancy. Production wants 3."
}

variable "clickhouse_storage" {
  type        = string
  nullable    = false
  default     = "20Gi"
  description = "Size of the data volume of each ClickHouse replica. The default is sized for a demonstration cluster. Production wants 100Gi or more."
}

variable "clickhouse_keeper_replicas" {
  type        = number
  nullable    = false
  default     = 1
  description = "Number of ClickHouse Keeper replicas. Keeper runs Raft, so the value must be odd. Production wants 3."
}

variable "valkey_host" {
  type        = string
  nullable    = false
  default     = ""
  description = "Hostname of the shared Valkey instance the tenants' tracing instances use as their queue backend, cache and rate limit store. The hub has no Valkey module yet, so the platform team runs the instance and passes it in here."
}

variable "valkey_password" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "Password of the Valkey instance. Use only characters that are safe in a URL, because the Langfuse chart substitutes the value into the connection URL without encoding it."
}

variable "valkey_database_count" {
  type        = number
  nullable    = false
  default     = 16
  description = "Number of Valkey database indices the instance serves. A stock Valkey serves 16, numbered 0 to 15."
}

variable "stackit_project_id" {
  type        = string
  nullable    = false
  default     = ""
  description = "STACKIT project the shared PostgreSQL Flex instance and the tenants' buckets live in."
}

variable "stackit_service_account_key" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "Service account key of the STACKIT service account, as the JSON STACKIT returns when the key is created. It needs permission to create databases and users on the PostgreSQL Flex instance and to create Object Storage credentials groups in the project."
}

variable "stackit_postgres_instance_id" {
  type        = string
  nullable    = false
  default     = ""
  description = "UUID of the shared PostgreSQL Flex instance. The architecture creates the gateway's database and every tenant's database inside it and never creates the instance itself."
}

variable "stackit_s3_admin_access_key" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "Access key of the administrative Object Storage credential the tenants' buckets are created with."
}

variable "stackit_s3_admin_secret_access_key" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "Secret access key of the administrative Object Storage credential."
}

variable "stackit_s3_admin_credentials_group_urn" {
  type        = string
  nullable    = false
  default     = ""
  description = "URN of the administrative Object Storage credentials group. Every tenant's bucket policy keeps access for this group."
}

# The identity provider is deliberately a set of flat variables rather than one object with optional
# attributes. Each field then carries its own explicit default, so no consumer of this file depends
# on Terraform's object-attribute defaulting to fill the ones that have one. They are assembled into
# a single object further down and reach the building block as one encrypted static input.
variable "oidc_issuer_url" {
  type        = string
  nullable    = false
  default     = ""
  description = "Discovery base URL of the OIDC provider every service in this architecture trusts, for example `https://idp.example.com/realms/ai`. The services read `<issuer_url>/.well-known/openid-configuration`. It is required, because no service here creates a password user."
}

variable "oidc_client_id" {
  type        = string
  nullable    = false
  default     = ""
  description = "Client id of the OIDC client. Every tenant's tracing instance has a callback URL of its own, so this client needs each of them as an allowed redirect URI, or a wildcard where the provider supports one."
}

variable "oidc_client_secret" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "Client secret of the OIDC client."
}

variable "oidc_scopes" {
  type        = string
  nullable    = false
  default     = "openid email profile"
  description = "Space-separated scope list the services request. The default covers what they need."
}

variable "oidc_display_name" {
  type        = string
  nullable    = false
  default     = "Single Sign-On"
  description = "Label on the login button of the tenants' tracing instances."
}

variable "oidc_allow_account_linking" {
  type        = bool
  nullable    = false
  default     = true
  description = "Link an OIDC login to an existing tracing user with the same email address."
}

variable "oidc_proxy_admin_id" {
  type        = string
  nullable    = true
  default     = null
  description = "User id that the gateway's admin console sets to the `proxy_admin` role on every login. It is compared against the `sub` claim, so it is that claim's value and not an email address unless the claim carries one."
}

variable "oidc_allowed_email_domains" {
  type        = list(string)
  nullable    = true
  default     = null
  description = "Only users whose email address carries one of these domains may log in to the gateway's admin console. The proxy compares the part after the `@` exactly, so there is no wildcard and no subdomain match. Null lets every user the provider authenticates log in."
}

variable "oidc_auto_redirect_to_sso" {
  type        = bool
  nullable    = false
  default     = false
  description = "Send the admin console's login page straight to the identity provider instead of showing a button."
}

variable "oidc_logout_url" {
  type        = string
  nullable    = true
  default     = null
  description = "URL the admin console sends the browser to after a logout."
}

variable "oidc_authorization_endpoint" {
  type        = string
  nullable    = true
  default     = null
  description = "Authorization endpoint of the identity provider. Set this together with the token and userinfo endpoints when the provider is unreachable from the meshStack Terraform runner, and the gateway then makes no discovery request at all."
}

variable "oidc_token_endpoint" {
  type        = string
  nullable    = true
  default     = null
  description = "Token endpoint of the identity provider. See `oidc_authorization_endpoint`."
}

variable "oidc_userinfo_endpoint" {
  type        = string
  nullable    = true
  default     = null
  description = "Userinfo endpoint of the identity provider. See `oidc_authorization_endpoint`."
}

variable "model_access_secret_name" {
  type        = string
  nullable    = false
  default     = "ai-model-access"
  description = "Name of the Kubernetes Secret each tenant's model credential is delivered in. It carries `OPENAI_API_KEY` and `OPENAI_BASE_URL`."
}

variable "langfuse_default_org_role" {
  type        = string
  nullable    = false
  default     = "MEMBER"
  description = "Role every user who logs in through the identity provider receives in a tenant's tracing organisation. Set `NONE` when one OIDC client is shared across tenants and auto-join is not wanted."
}

variable "location_identifier" {
  type        = string
  nullable    = false
  default     = "global"
  description = "Identifier of the meshStack location the gateway platform is registered in."
}

variable "platform_name" {
  type        = string
  nullable    = false
  default     = "ai"
  description = "Name of the meshStack platform the gateway is registered as. Together with the location it forms the platform identifier `<name>.<location>`, and it prefixes the name of every landing zone."
}

variable "platform_type_name" {
  type        = string
  nullable    = false
  default     = "AI-MODEL"
  description = "Name of the meshStack platform type this file creates and the gateway platform belongs to. It is named for the capability rather than for LiteLLM, the product that delivers it. meshStack restricts it to uppercase letters, digits and dashes."

  validation {
    condition     = can(regex("^[A-Z0-9]+(-[A-Z0-9]+)*$", var.platform_type_name))
    error_message = "platform_type_name must be uppercase alphanumeric with dashes, with no leading, trailing or consecutive dashes. meshStack enforces the same pattern on a platform type name."
  }
}

variable "platform_type_display_name" {
  type        = string
  nullable    = false
  default     = "AI Model Gateway"
  description = "Display name of the platform type in meshPanel. It is named for the capability rather than for the product delivering it, so the platform team can replace the gateway without renaming what application teams see."
}

variable "landing_zones" {
  type = map(object({
    display_name    = string
    description     = string
    models          = optional(list(string), [])
    max_budget      = optional(number, 100)
    budget_duration = optional(string, "30d")
    tags            = optional(map(list(string)), {})
  }))
  nullable = false

  # The default is spelled out in full rather than relying on the `optional()` defaults above,
  # because this value is passed through a building block definition input and some consumers do not
  # evaluate Terraform's object-attribute defaulting.
  default = {
    standard = {
      display_name    = "AI Model Access"
      description     = "Governed access to every model the gateway offers, with a budget of 100 per 30 days per project."
      models          = []
      max_budget      = 100
      budget_duration = "30d"
      tags            = {}
    }
  }

  description = <<-EOT
  The AI landing zones, keyed by a short name that is appended to `platform_name`. Each one gets a
  model access building block definition of its own and lists it in
  `spec.mandatory_building_block_refs`, so meshStack provisions model access when a tenant of that
  landing zone is created.

  `models` is the allow-list the gateway enforces; an empty list lets a tenant call every model the
  gateway offers. Because the gateway hides the shape of the backends, `models` is what makes one
  landing zone resolve to a sovereign backend and another to a load-balanced pool across several.
  EOT
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
  const   = true
  default = { git_ref = "main", bbd_draft = true }

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

output "platform_type" {
  description = "The meshStack platform type the gateway platform belongs to. Pass its `name` to any building block definition that supports the gateway as a platform."
  value = {
    name = meshstack_platform_type.litellm.metadata.name
    uuid = meshstack_platform_type.litellm.metadata.uuid
  }
}

locals {
  # The building block takes the identity provider as one object, because the gateway and the
  # tracing instances each need a different part of the whole set. It is assembled here from the
  # flat variables above and reaches the run as a single encrypted static input.
  oidc = {
    issuer_url    = var.oidc_issuer_url
    client_id     = var.oidc_client_id
    client_secret = var.oidc_client_secret

    scopes                = var.oidc_scopes
    display_name          = var.oidc_display_name
    allow_account_linking = var.oidc_allow_account_linking

    proxy_admin_id        = var.oidc_proxy_admin_id
    allowed_email_domains = var.oidc_allowed_email_domains
    auto_redirect_to_sso  = var.oidc_auto_redirect_to_sso
    logout_url            = var.oidc_logout_url

    authorization_endpoint = var.oidc_authorization_endpoint
    token_endpoint         = var.oidc_token_endpoint
    userinfo_endpoint      = var.oidc_userinfo_endpoint
  }

  oidc_argument                   = jsonencode(local.oidc)
  model_backend_api_keys_argument = jsonencode(var.litellm_model_backend_api_keys)
}

# The platform type the gateway platform belongs to, and the type every model access definition
# names in `supported_platforms`.
#
# It is created here rather than inside the ordered building block for two reasons: a platform type
# is one catalog-wide object that outlives any single order, and creating it needs no ephemeral API
# permission whose name would have to be guessed. Ordering the architecture twice — a second AI
# cluster, say — then adds a second platform of this one type.
resource "meshstack_platform_type" "litellm" {
  metadata = {
    name               = var.platform_type_name
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name = var.platform_type_display_name
    icon         = provider::meshstack::load_image_file("${path.module}/logo.png")
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = "AI Platform"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/ai-platform/buildingblock/logo.png"
    description      = "Installs the LiteLLM gateway and the shared ClickHouse cluster into a Kubernetes cluster, registers the gateway as a meshStack platform, and creates the AI landing zones that hand every project a governed model endpoint, a budget and a tracing instance."
    support_url      = "https://docs.litellm.ai/docs/proxy/virtual_keys"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
    This building block turns a Kubernetes cluster into an AI platform. One order installs the
    **LiteLLM gateway** and the shared **ClickHouse** cluster, registers the gateway in meshStack as
    a platform of its own, and creates the AI landing zones application teams then order projects
    on. A project that lands in one of those zones receives a governed OpenAI-compatible endpoint, a
    budget of its own, the credential as a Kubernetes Secret in its namespace, and a tracing
    instance of its own — without ordering anything.

    The gateway is the component that manages model access, and it is what hides the shape of the
    backends. Behind it, one Azure OpenAI instance and one or more STACKIT AI Model Serving
    deployments are entries in a list, and no application team ever sees either. That is why one
    upstream credential per backend is not a compromise: it is the reason to put a gateway there,
    and it is what lets a landing zone resolve to a sovereign backend while the next one resolves to
    a pool across several.

    ## 🎯 When to use it

    Use this building block when you:
    - want to offer model access as a governed product — a key, a budget and a model allow-list per
      project — instead of handing out one shared credential.
    - already run a Kubernetes cluster with an ingress and a wildcard certificate, and want the AI
      platform on top of it.
    - want every project to see the prompts, the answers, the latency and the cost of its own calls,
      without sharing a tracing instance with another project.

    ## 💡 Usage examples

    **Example 1: One platform, two policies**
    You define two landing zones: one that allows every model the gateway offers with a small
    budget, and one that allows only the models your compliance team approved. Both provision model
    access automatically, and a project picks its policy by picking a landing zone.

    **Example 2: Adding a model without touching a tenant**
    A new model becomes available at your provider. You add one entry to the model list of this
    building block and re-apply. Every project that is allowed to call it can do so immediately, and
    no tenant has to re-order anything.

    ## 🌐 Hostnames and certificates

    This building block creates no DNS record and requests no certificate. It publishes the gateway
    on `<label>.<apps domain>` and every tenant's tracing instance on a name in the same domain,
    because the Kubernetes architecture below it already resolves every name there and already
    serves a wildcard certificate for them.

    ## 🔑 One identity provider

    Every service here trusts the same OIDC provider natively, with no proxy in front of anything.
    The gateway's admin console **holds at most five users**: single sign-on is free in the
    open-source proxy up to that number, and the sixth login locks out everyone. Plan the platform
    team's console access around it. The tenants' tracing instances have no such limit.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the cluster, its ingress and its wildcard certificate | ✅ | ❌ |
    | Provide the model backends and their upstream credentials | ✅ | ❌ |
    | Provide the shared Postgres instance, the Valkey instance and the object storage credential | ✅ | ❌ |
    | Install and upgrade the gateway and the shared trace storage | ✅ | ❌ |
    | Define the landing zones: allowed models, budget and budget period | ✅ | ❌ |
    | Register and maintain this building block definition | ✅ | ❌ |
    | Order projects in an AI landing zone | ❌ | ✅ |
    | Mount the delivered Secret and keep the credential out of source control | ❌ | ✅ |
    | Stay within the granted budget and the allowed models | ❌ | ✅ |
    | Review own traces and evaluations | ❌ | ✅ |
    | Build and operate the application that calls the endpoint | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # Ephemeral API key permissions for the meshStack resources one run creates: the gateway
    # platform, the AI landing zones, and the model access building block definitions the nested
    # `modules/ai/model-access` integration registers. The platform type is created by this file
    # instead, so no permission for it is needed at run time.
    permissions = [
      "PLATFORMINSTANCE_LIST",
      "PLATFORMINSTANCE_SAVE",
      "PLATFORMINSTANCE_DELETE",
      "LANDINGZONE_LIST",
      "LANDINGZONE_SAVE",
      "LANDINGZONE_DELETE",
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE"
    ]

    implementation = {
      terraform = {
        # The same version `modules/ai/model-access` runs on, so the two definitions of this
        # architecture — the one ordered here and the one it registers — share a runner version.
        # It satisfies the `>= 1.12.0` the module demands.
        terraform_version              = "1.12.2"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/ai-platform/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    # Every input is STATIC. The definition is bound to one cluster by its kubeconfig anyway, so
    # there is nothing left for a human to fill in at order time: the platform team configures the
    # architecture here, in this file, and ordering it is one click.
    inputs = {
      # ── The clusters ──

      ai_cluster_kubeconfig = {
        display_name    = "AI Platform Cluster kubeconfig"
        description     = "kubeconfig of the cluster the gateway and the shared ClickHouse are installed into."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.ai_cluster_kubeconfig
            secret_version = nonsensitive(sha256(var.ai_cluster_kubeconfig))
          }
        }
      }

      app_cluster_kubeconfig = {
        display_name    = "Application Cluster kubeconfig"
        description     = "kubeconfig of the cluster the application teams' namespaces live on. Empty uses the AI platform cluster."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.app_cluster_kubeconfig
            secret_version = nonsensitive(sha256(var.app_cluster_kubeconfig))
          }
        }
      }

      app_platform_identifier = {
        display_name    = "Application Platform Identifier"
        description     = "Identifier of the meshStack platform the application cluster is registered as, in the `<platform>.<location>` form."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.app_platform_identifier)
      }

      apps_domain = {
        display_name    = "Application Domain"
        description     = "Domain the cluster's application hostnames live under. The gateway and every tenant's tracing instance are published inside it."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.apps_domain)
      }

      ingress_class_name = {
        display_name    = "Ingress Class Name"
        description     = "Name of the IngressClass that serves the gateway and the tracing instances."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.ingress_class_name)
      }

      # ── The gateway ──

      litellm_hostname_label = {
        display_name    = "Gateway Hostname Label"
        description     = "Label the gateway is published under inside the application domain."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_hostname_label)
      }

      litellm_model_backends = {
        display_name    = "Model Backends"
        description     = "JSON object of model aliases, each with the upstream model name and the OpenAI-compatible base URL."
        type            = "CODE"
        assignment_type = "STATIC"
        # jsonencode twice is correct, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.litellm_model_backends))
      }

      litellm_model_backend_api_keys = {
        display_name    = "Model Backend API Keys"
        description     = "JSON object with the upstream API key of every model alias, keyed exactly like the model backends."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = local.model_backend_api_keys_argument
            secret_version = nonsensitive(sha256(local.model_backend_api_keys_argument))
          }
        }
      }

      litellm_console_sso_enabled = {
        display_name    = "Gateway Console Single Sign-On"
        description     = "Let the platform team log in to the gateway's admin console. The console holds at most five users."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_console_sso_enabled)
      }

      litellm_replica_count = {
        display_name    = "Gateway Replicas"
        description     = "Number of gateway pods."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_replica_count)
      }

      litellm_redis_enabled = {
        display_name    = "Gateway Coordination Through Valkey"
        description     = "Point the gateway at the shared Valkey instance for cross-pod rate limits and spend tracking."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_redis_enabled)
      }

      # ── The shared ClickHouse cluster ──

      clickhouse_replicas = {
        display_name    = "ClickHouse Replicas"
        description     = "Number of ClickHouse replicas. Production wants 3."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.clickhouse_replicas)
      }

      clickhouse_storage = {
        display_name    = "ClickHouse Storage"
        description     = "Size of the data volume of each ClickHouse replica."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.clickhouse_storage)
      }

      clickhouse_keeper_replicas = {
        display_name    = "ClickHouse Keeper Replicas"
        description     = "Number of ClickHouse Keeper replicas. Keeper runs Raft, so the value must be odd."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.clickhouse_keeper_replicas)
      }

      # ── The shared Valkey instance ──

      valkey_host = {
        display_name    = "Valkey Host"
        description     = "Hostname of the shared Valkey instance the tracing instances use as their queue backend."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.valkey_host)
      }

      valkey_password = {
        display_name    = "Valkey Password"
        description     = "Password of the Valkey instance."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.valkey_password
            secret_version = nonsensitive(sha256(var.valkey_password))
          }
        }
      }

      valkey_database_count = {
        display_name    = "Valkey Database Count"
        description     = "Number of Valkey database indices the instance serves."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.valkey_database_count)
      }

      # ── STACKIT ──

      stackit_project_id = {
        display_name    = "STACKIT Project"
        description     = "STACKIT project the shared Postgres instance and the tenants' buckets live in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_project_id)
      }

      stackit_service_account_key = {
        display_name    = "STACKIT Service Account Key"
        description     = "Service account key the architecture authenticates against STACKIT with, as JSON."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.stackit_service_account_key
            secret_version = nonsensitive(sha256(var.stackit_service_account_key))
          }
        }
      }

      stackit_postgres_instance_id = {
        display_name    = "Postgres Instance"
        description     = "UUID of the shared PostgreSQL Flex instance the gateway's and the tenants' databases are created in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_postgres_instance_id)
      }

      stackit_s3_admin_access_key = {
        display_name    = "Object Storage Admin Access Key"
        description     = "Access key of the administrative Object Storage credential the tenants' buckets are created with."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.stackit_s3_admin_access_key
            secret_version = nonsensitive(sha256(var.stackit_s3_admin_access_key))
          }
        }
      }

      stackit_s3_admin_secret_access_key = {
        display_name    = "Object Storage Admin Secret Access Key"
        description     = "Secret access key of the administrative Object Storage credential."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.stackit_s3_admin_secret_access_key
            secret_version = nonsensitive(sha256(var.stackit_s3_admin_secret_access_key))
          }
        }
      }

      stackit_s3_admin_credentials_group_urn = {
        display_name    = "Object Storage Admin Credentials Group"
        description     = "URN of the administrative Object Storage credentials group every tenant's bucket policy keeps access for."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_s3_admin_credentials_group_urn)
      }

      # ── The identity provider ──

      oidc = {
        display_name    = "Identity Provider"
        description     = "JSON object with the issuer URL, the client id, the client secret and the claim mapping of the OIDC client every service in this architecture trusts."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = local.oidc_argument
            secret_version = nonsensitive(sha256(local.oidc_argument))
          }
        }
      }

      # ── What a tenant receives ──

      model_access_secret_name = {
        display_name    = "Model Credential Secret Name"
        description     = "Name of the Kubernetes Secret each tenant's model credential is delivered in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.model_access_secret_name)
      }

      langfuse_default_org_role = {
        display_name    = "Tracing Default Role"
        description     = "Role a user who logs in receives in a tenant's tracing organisation."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_default_org_role)
      }

      # ── meshStack registration ──

      owning_workspace_identifier = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that owns the gateway platform, the AI landing zones and the model access building block definitions."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      location_identifier = {
        display_name    = "Location Identifier"
        description     = "meshStack location the gateway platform is registered in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.location_identifier)
      }

      platform_name = {
        display_name    = "Platform Name"
        description     = "Name of the meshStack platform the gateway is registered as. It also prefixes every landing zone name."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.platform_name)
      }

      platform_type_name = {
        display_name    = "Platform Type"
        description     = "Name of the platform type the gateway platform belongs to. This integration creates the type."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(meshstack_platform_type.litellm.metadata.name)
      }

      landing_zones = {
        display_name    = "AI Landing Zones"
        description     = "JSON object of landing zones, each with its display name, description, allowed models, budget and budget period."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.landing_zones))
      }

      building_block_tags = {
        display_name    = "Building Block Tags"
        description     = "JSON object of tags applied to the model access building block definitions this architecture registers."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.meshstack.tags))
      }

      hub = {
        display_name    = "Hub"
        description     = "JSON object with `git_ref`, the meshstack-hub reference used to source the gateway, the ClickHouse cluster, the Postgres database and the model access integration, and `bbd_draft`, forwarded to that integration's own building block definitions."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }
    }

    # No output carries a credential. `version_spec.outputs` has no `sensitive` block, unlike
    # `version_spec.inputs`, so every building block output is stored and displayed in cleartext in
    # meshPanel. The gateway's master key stays in the Kubernetes Secret the summary names.
    outputs = {
      litellm_url = {
        display_name    = "Gateway URL"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      litellm_console_url = {
        display_name    = "Gateway Admin Console"
        type            = "STRING"
        assignment_type = "SIGN_IN_URL"
      }

      litellm_api_base = {
        display_name    = "API Base URL"
        type            = "STRING"
        assignment_type = "NONE"
      }

      litellm_oidc_callback_url = {
        display_name    = "Console Callback URL"
        type            = "STRING"
        assignment_type = "NONE"
      }

      litellm_master_key_secret = {
        display_name    = "Master Key Secret"
        type            = "STRING"
        assignment_type = "NONE"
      }

      model_aliases = {
        display_name    = "Model Aliases"
        type            = "STRING"
        assignment_type = "NONE"
      }

      clickhouse_host = {
        display_name    = "ClickHouse Host"
        type            = "STRING"
        assignment_type = "NONE"
      }

      platform_identifier = {
        display_name    = "Gateway Platform"
        type            = "STRING"
        assignment_type = "NONE"
      }

      landing_zones = {
        display_name    = "AI Landing Zones"
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
      version = ">= 0.24.0"
    }
  }
}
