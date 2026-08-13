variable "litellm_api_base" {
  type        = string
  description = "Base URL of the LiteLLM gateway, for example 'https://litellm.example.com'. Every team and virtual key this definition creates lives on this gateway."
}

variable "litellm_admin_api_key" {
  type        = string
  sensitive   = true
  description = "LiteLLM admin key the building block authenticates with. It needs permission to create teams and keys."
}

variable "litellm_platform_type_name" {
  type        = string
  default     = "LiteLLM"
  description = "Name of the meshStack platform type the LiteLLM platform is registered under. It must match the platform type used by the `ai/litellm` module, because this building block runs on the AI model tenant."
}

variable "litellm_team_models" {
  type        = list(string)
  default     = []
  description = "Names of the models on the gateway that every team created by this definition may call. An empty list sends no allow-list to LiteLLM. Create one definition per landing zone to grant different model sets."
}

variable "litellm_team_max_budget" {
  type        = number
  default     = 100
  description = "Spending limit of a team for one budget period, in the currency the gateway reports spend in. LiteLLM blocks the team once the limit is reached."
}

variable "litellm_team_budget_duration" {
  type        = string
  default     = "30d"
  description = "Length of one budget period, after which LiteLLM resets the spend counter. Written as a LiteLLM duration such as '30d', '7d' or '1h'."
}

variable "ai_platform_cluster_kubeconfig" {
  type        = string
  sensitive   = true
  description = "kubeconfig of the AI platform cluster, as YAML. The tenant's tracing instance is deployed here. The credential needs permission to create a namespace, a secret and a Helm release."
}

variable "demo_app_cluster_kubeconfig" {
  type        = string
  sensitive   = true
  description = "kubeconfig of the demo application cluster, as YAML. Only the Secret with the model credential is written here, so the credential needs no more than `get`, `create`, `update` and `patch` on secrets."
}

variable "demo_app_platform_identifier" {
  type        = string
  description = "Full identifier of the meshStack platform the demo application cluster is registered as, in the form '<platform>.<location>'. The building block looks up the sibling tenant of this platform in the same meshProject to learn the namespace it writes the Secret into."
}

variable "kubernetes_secret_name" {
  type        = string
  default     = "ai-model-access"
  description = "Name of the Kubernetes Secret the building block writes into the namespace of the application team."
}

variable "langfuse_domain" {
  type        = string
  description = "Domain the tenants' tracing instances are published under. Each instance answers on '<derived label>.<langfuse_domain>', and the label is derived from the workspace and the project."
}

variable "langfuse_ingress_class_name" {
  type        = string
  default     = "haproxy"
  description = "Name of the IngressClass that serves the tenants' tracing instances. The default matches the controller the `kubernetes/ingress` module installs."
}

variable "langfuse_default_org_role" {
  type        = string
  default     = "MEMBER"
  description = "Role every user who logs in through the identity provider receives in a tenant's tracing organisation. Set 'NONE' when one OIDC client is shared across tenants and auto-join is not wanted."
}

variable "langfuse_postgres_host" {
  type        = string
  description = "Hostname of the shared Postgres server the tracing instances keep their relational data in, each in a database of its own."
}

variable "langfuse_postgres_username" {
  type        = string
  description = "Postgres user the tracing instances connect as. It has to own each tenant's database, because the schema migrations run under it on every pod start."
}

variable "langfuse_postgres_password" {
  type        = string
  sensitive   = true
  description = "Password of the Postgres user. Use only characters that are safe in a URL, because Langfuse builds its connection URL by string substitution."
}

variable "langfuse_clickhouse_host" {
  type        = string
  description = "Fully qualified hostname of the shared ClickHouse cluster, without a scheme. Take it from the `host` output of the `ai/clickhouse` module."
}

variable "langfuse_clickhouse_username" {
  type        = string
  description = "ClickHouse user the tracing instances connect as."
}

variable "langfuse_clickhouse_password" {
  type        = string
  sensitive   = true
  description = "Password of the ClickHouse user. Avoid '&', '=', '#', '?', '%', '+', '@' and spaces, because the Langfuse migration script puts the value into a query string without encoding it."
}

variable "langfuse_valkey_host" {
  type        = string
  description = "Hostname of the shared Valkey instance the tracing instances use as their queue backend, cache and rate limit store."
}

variable "langfuse_valkey_password" {
  type        = string
  sensitive   = true
  description = "Password of the Valkey instance. Use only characters that are safe in a URL."
}

variable "langfuse_valkey_database_count" {
  type        = number
  default     = 16
  description = "Number of Valkey database indices the instance serves. A stock Valkey serves 16, numbered 0 to 15."
}

variable "langfuse_s3_endpoint" {
  type        = string
  description = "Endpoint URL of the object storage the tenants' buckets live in, including the scheme."
}

variable "langfuse_s3_access_key_id" {
  type        = string
  sensitive   = true
  description = "Access key id of the object storage credential."
}

variable "langfuse_s3_secret_access_key" {
  type        = string
  sensitive   = true
  description = "Secret access key of the object storage credential."
}

# The identity provider is deliberately six flat variables rather than one object with optional
# attributes. Each field then carries its own explicit default, so no consumer of this file depends on
# Terraform's object-attribute defaulting to fill the three that have one.
variable "oidc_issuer_url" {
  type        = string
  description = "Discovery base URL of the OIDC provider the tenants' tracing instances trust, for example 'https://idp.example.com/realms/ai'. The instances read '<issuer_url>/.well-known/openid-configuration'. It is required, because the building block creates no password user."
}

variable "oidc_client_id" {
  type        = string
  description = "Client id of the OIDC client. Every tenant's tracing instance has a callback URL of its own, so this client needs each of them as an allowed redirect URI, or a wildcard where the provider supports one."
}

variable "oidc_client_secret" {
  type        = string
  sensitive   = true
  description = "Client secret of the OIDC client."
}

variable "oidc_display_name" {
  type        = string
  default     = "Single Sign-On"
  description = "Label on the login button of the tracing instances."
}

variable "oidc_scopes" {
  type        = string
  default     = "openid email profile"
  description = "Space-separated scope list the tracing instances request. The default covers what they need."
}

variable "oidc_allow_account_linking" {
  type        = bool
  default     = true
  description = "Link an OIDC login to an existing user with the same email address. Turn it on when a user can already exist from another login path."
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
  description = "BBD is consumed in building block compositions. Add it to `spec.mandatory_building_block_refs` of the AI landing zone, so meshStack provisions model access when a tenant of that landing zone is created."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

locals {
  # The building block takes the identity provider as one object, because Langfuse needs the whole set
  # to register the provider. It is assembled here from the flat variables above.
  oidc = {
    issuer_url            = var.oidc_issuer_url
    client_id             = var.oidc_client_id
    client_secret         = var.oidc_client_secret
    display_name          = var.oidc_display_name
    scopes                = var.oidc_scopes
    allow_account_linking = var.oidc_allow_account_linking
  }

  oidc_argument = jsonencode(local.oidc)
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    # Named for the capability, not for the products that deliver it. LiteLLM and Langfuse stay
    # behind this name, so the platform team can replace either without renaming what the
    # application team ordered.
    display_name        = "AI Model Access"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ai/model-access/buildingblock/logo.png"
    description         = "Gives a project a governed OpenAI-compatible model endpoint with a budget, a credential delivered into its namespace, and a tracing instance of its own."
    support_url         = "https://docs.litellm.ai/docs/proxy/virtual_keys"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = var.litellm_platform_type_name }]

    # The application team never orders this block by hand. The AI landing zone lists it in
    # `spec.mandatory_building_block_refs`, so meshStack provisions everything when the tenant is
    # created. Every input below is STATIC or assigned from tenant context, which is what makes that
    # work: a mandatory block that stops to ask a human defeats its own purpose, and API-driven
    # tenant creation only succeeds when every input is defaulted or static.
    use_in_landing_zones_only = true

    readme = chomp(<<-EOT
      This building block gives your project a governed, OpenAI-compatible model endpoint with a
      budget of its own, delivers the credential as a Kubernetes Secret in your namespace, and gives
      you a tracing instance where you can see every call your application made. meshStack
      provisions all of it when your tenant in the AI landing zone is created, so there is nothing
      to order and nothing to fill in.

      ## 🎯 When to use it

      Use this building block when you:
      - Want a governed model endpoint for your application instead of a credential shared across the whole platform.
      - Need the spend of your project to be counted and capped on its own.
      - Want to see the prompts, the answers, the latency and the cost of every call your application made.
      - Want the platform team to decide which models you may call, through the landing zone you picked.

      ## 💡 Usage examples

      **Example 1: A chat assistant in a web application**
      Your project lands in the AI landing zone, and the platform writes the credential into the
      Secret `ai-model-access` in your namespace. Your Deployment mounts the whole Secret with
      `envFrom`, and the OpenAI client library of your application picks up the endpoint and the
      credential from the environment without a line of configuration.

      **Example 2: Finding out why an answer got worse**
      A user reports a bad answer. You open your tracing instance from the sign-in link of this
      building block, find the call, and see the prompt, the answer, the model that served it and
      what it cost. Nobody outside your project can see any of it.

      ## 🔑 Getting the credential

      The credential is a bearer token, so this building block never shows it in meshPanel. It is
      delivered as a Kubernetes Secret in the namespace of your project, and your workload reads it
      from there. The Secret carries two keys, named after the environment variables the OpenAI
      client libraries read:

      | Key | Content |
      |---|---|
      | `OPENAI_API_KEY` | The credential, as a bearer token. |
      | `OPENAI_BASE_URL` | The endpoint, already ending in `/v1`. |

      ```sh
      curl "$OPENAI_BASE_URL/models" \
        -H "Authorization: Bearer $OPENAI_API_KEY"
      ```

      The endpoint stops answering once your project reaches its budget for the current period, and
      the spend counter resets at the end of every period.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Operate the gateway, the model backends and the tracing backends | ✅ | ❌ |
      | Set the budget, the budget period and the allowed models per landing zone | ✅ | ❌ |
      | Create the endpoint credential and the tracing instance when the tenant is created | ✅ | ❌ |
      | Deliver the credential into the namespace of the project as a Kubernetes Secret | ✅ | ❌ |
      | Upgrade the tracing instance | ✅ | ❌ |
      | Mount the Secret into the workload and keep the credential out of source control | ❌ | ✅ |
      | Stay within the granted budget and the allowed models | ❌ | ✅ |
      | Review own traces and evaluations | ❌ | ✅ |
      | Build and operate the application that calls the endpoint | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # One tenant is one team, one credential and one tracing instance. Applying the block a second
    # time in the same tenant would create a second set, so meshStack refuses it.
    only_apply_once_per_tenant = true

    # The run looks up the sibling tenant of the same meshProject to learn the namespace the Secret
    # goes into. meshStack grants an ephemeral API token with these permissions to the run.
    # `modules/aks/github-connector` proves that a TENANT_LEVEL block can hold them.
    permissions = ["TENANT_LIST"]

    implementation = {
      terraform = {
        terraform_version              = "1.12.2"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/ai/model-access/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── The shared gateway ──

      litellm_api_base = {
        display_name    = "LiteLLM API Base URL"
        description     = "Base URL of the LiteLLM gateway the team is created on."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_api_base)
      }

      litellm_api_key = {
        display_name    = "LiteLLM Admin Key"
        description     = "Admin key the building block authenticates with against the LiteLLM API."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.litellm_admin_api_key
            secret_version = nonsensitive(sha256(var.litellm_admin_api_key))
          }
        }
      }

      models = {
        display_name    = "Allowed Models"
        description     = "Names of the models on the gateway that the team may call."
        type            = "CODE"
        assignment_type = "STATIC"
        # jsonencode twice is correct, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.litellm_team_models))
      }

      max_budget = {
        display_name    = "Budget"
        description     = "Spending limit of the team for one budget period."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_team_max_budget)
      }

      budget_duration = {
        display_name    = "Budget Duration"
        description     = "Length of one budget period, for example '30d'."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_team_budget_duration)
      }

      # ── The tenant context every derived name comes from ──
      #
      # These three are assigned by meshStack and cannot be forged by the tenant. Together with the
      # STATIC values above and below they decide which namespace in which cluster receives the
      # credential, so none of them may ever become a USER_INPUT.

      workspace_identifier = {
        display_name    = "Workspace Identifier"
        description     = "Identifier of the meshStack workspace. It is part of the team alias and of every per-tenant name the building block derives."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      project_identifier = {
        display_name    = "Project Identifier"
        description     = "Identifier of the meshStack project. It is part of the team alias and of every per-tenant name the building block derives."
        type            = "STRING"
        assignment_type = "PROJECT_IDENTIFIER"
      }

      meshstack_tenant_uuid = {
        display_name    = "Tenant UUID"
        description     = "UUID of the meshStack tenant, written to the team metadata so an operator can trace a team back to its tenant."
        type            = "STRING"
        assignment_type = "MESHSTACK_TENANT_UUID"
      }

      # ── The two clusters ──

      ai_platform_cluster_kubeconfig = {
        display_name    = "AI Platform Cluster kubeconfig"
        description     = "kubeconfig of the AI platform cluster, as YAML. The tenant's tracing instance is deployed here."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.ai_platform_cluster_kubeconfig
            secret_version = nonsensitive(sha256(var.ai_platform_cluster_kubeconfig))
          }
        }
      }

      demo_app_cluster_kubeconfig = {
        display_name    = "Application Cluster kubeconfig"
        description     = "kubeconfig of the demo application cluster, as YAML. Only the Secret with the model credential is written here."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.demo_app_cluster_kubeconfig
            secret_version = nonsensitive(sha256(var.demo_app_cluster_kubeconfig))
          }
        }
      }

      demo_app_platform_identifier = {
        display_name    = "Application Platform Identifier"
        description     = "Full identifier of the meshStack platform the demo application cluster is registered as, used to look up the sibling tenant of the same meshProject."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.demo_app_platform_identifier)
      }

      secret_name = {
        display_name    = "Secret Name"
        description     = "Name of the Kubernetes Secret the credential is delivered in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.kubernetes_secret_name)
      }

      # ── The tenant's tracing instance ──

      langfuse_domain = {
        display_name    = "Tracing Domain"
        description     = "Domain the tenants' tracing instances are published under."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_domain)
      }

      langfuse_ingress_class_name = {
        display_name    = "Ingress Class"
        description     = "Name of the IngressClass that serves the tenants' tracing instances."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_ingress_class_name)
      }

      langfuse_default_org_role = {
        display_name    = "Tracing Default Role"
        description     = "Role a user who logs in receives in the tenant's tracing organisation."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_default_org_role)
      }

      oidc = {
        display_name    = "Identity Provider"
        description     = "JSON object with the issuer URL, the client id and the client secret of the OIDC client the tracing instances trust."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = local.oidc_argument
            secret_version = nonsensitive(sha256(local.oidc_argument))
          }
        }
      }

      langfuse_postgres_host = {
        display_name    = "Postgres Host"
        description     = "Hostname of the shared Postgres server."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_postgres_host)
      }

      langfuse_postgres_username = {
        display_name    = "Postgres User"
        description     = "Postgres user the tracing instances connect as."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_postgres_username)
      }

      langfuse_postgres_password = {
        display_name    = "Postgres Password"
        description     = "Password of the Postgres user."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.langfuse_postgres_password
            secret_version = nonsensitive(sha256(var.langfuse_postgres_password))
          }
        }
      }

      langfuse_clickhouse_host = {
        display_name    = "ClickHouse Host"
        description     = "Fully qualified hostname of the shared ClickHouse cluster."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_clickhouse_host)
      }

      langfuse_clickhouse_username = {
        display_name    = "ClickHouse User"
        description     = "ClickHouse user the tracing instances connect as."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_clickhouse_username)
      }

      langfuse_clickhouse_password = {
        display_name    = "ClickHouse Password"
        description     = "Password of the ClickHouse user."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.langfuse_clickhouse_password
            secret_version = nonsensitive(sha256(var.langfuse_clickhouse_password))
          }
        }
      }

      langfuse_valkey_host = {
        display_name    = "Valkey Host"
        description     = "Hostname of the shared Valkey instance."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_valkey_host)
      }

      langfuse_valkey_password = {
        display_name    = "Valkey Password"
        description     = "Password of the Valkey instance."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.langfuse_valkey_password
            secret_version = nonsensitive(sha256(var.langfuse_valkey_password))
          }
        }
      }

      langfuse_valkey_database_count = {
        display_name    = "Valkey Database Count"
        description     = "Number of Valkey database indices the instance serves."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_valkey_database_count)
      }

      langfuse_s3_endpoint = {
        display_name    = "Object Storage Endpoint"
        description     = "Endpoint URL of the object storage, including the scheme."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.langfuse_s3_endpoint)
      }

      langfuse_s3_access_key_id = {
        display_name    = "Object Storage Access Key Id"
        description     = "Access key id of the object storage credential."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.langfuse_s3_access_key_id
            secret_version = nonsensitive(sha256(var.langfuse_s3_access_key_id))
          }
        }
      }

      langfuse_s3_secret_access_key = {
        display_name    = "Object Storage Secret Access Key"
        description     = "Secret access key of the object storage credential."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.langfuse_s3_secret_access_key
            secret_version = nonsensitive(sha256(var.langfuse_s3_secret_access_key))
          }
        }
      }

      hub = {
        display_name    = "Hub"
        description     = "JSON object with `git_ref`, the meshstack-hub reference the building block sources the tracing module from. It is the same reference the building block itself is checked out at."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode({ git_ref = var.hub.git_ref }))
      }
    }

    # No output below carries the virtual key, and none can: `version_spec.outputs` has no
    # `sensitive` block, unlike `version_spec.inputs`, so every building block output is stored and
    # displayed in cleartext in meshPanel. The key is created, written into the Kubernetes Secret and
    # left inside the Terraform run. The `summary` output names the Secret it landed in.
    outputs = {
      team_id = {
        display_name    = "Team ID"
        description     = "ID of the LiteLLM team. It becomes the platform tenant ID, so building blocks ordered later can bind their resources to this team."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      team_alias = {
        display_name    = "Team Alias"
        description     = "Alias of the team on the gateway."
        type            = "STRING"
        assignment_type = "NONE"
      }

      key_id = {
        display_name    = "Credential ID"
        description     = "Hash the gateway identifies the credential by. It is not the credential."
        type            = "STRING"
        assignment_type = "NONE"
      }

      api_base = {
        display_name    = "API Base URL"
        description     = "OpenAI-compatible base URL of the endpoint, including the '/v1' suffix."
        type            = "STRING"
        assignment_type = "NONE"
      }

      secret_name = {
        display_name    = "Secret Name"
        description     = "Name of the Kubernetes Secret the credential was delivered in."
        type            = "STRING"
        assignment_type = "NONE"
      }

      secret_namespace = {
        display_name    = "Secret Namespace"
        description     = "Namespace of the application team the Secret was written into."
        type            = "STRING"
        assignment_type = "NONE"
      }

      langfuse_url = {
        display_name    = "Tracing URL"
        description     = "URL of the tenant's own tracing instance."
        type            = "STRING"
        assignment_type = "SIGN_IN_URL"
      }

      langfuse_namespace = {
        display_name    = "Tracing Namespace"
        description     = "Namespace the tenant's tracing instance runs in, in the AI platform cluster."
        type            = "STRING"
        assignment_type = "NONE"
      }

      langfuse_oidc_callback_url = {
        display_name    = "Tracing Callback URL"
        description     = "Callback URL to register at the identity provider for this tenant's tracing instance."
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
      version = ">= 0.23.0"
    }
  }
}
