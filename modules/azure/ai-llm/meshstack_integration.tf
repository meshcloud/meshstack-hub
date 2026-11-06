variable "azure_tenant_id" {
  type        = string
  description = "Azure Entra tenant ID the landing zone subscriptions belong to."
}

variable "azure_scope" {
  type        = string
  description = "RBAC scope where the deploy role is granted: a management group ('/providers/Microsoft.Management/managementGroups/<id>') or a subscription ('/subscriptions/<guid>'), typically the parent of all landing zones."
  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}$|^/providers/Microsoft\\.Management/managementGroups/.+$", var.azure_scope))
    error_message = "Must be a full resource path: '/subscriptions/<guid>' or '/providers/Microsoft.Management/managementGroups/<id>', not a bare GUID."
  }
}

variable "azure_location" {
  type        = string
  default     = "germanywestcentral"
  description = "Azure region of the backplane identity and of every AI Services account. Every model in `azure_models` must be available there for `azure_deployment_sku`; Sweden Central offers the widest choice among EU regions, where a location policy allows it."
}

variable "azure_models" {
  type = map(object({
    format  = optional(string, "OpenAI")
    version = string
  }))
  default = {
    "gpt-5-mini"             = { version = "2025-08-07" }
    "text-embedding-3-small" = { version = "1" }
  }
  description = "Models application teams may choose from, keyed by model name. Each must be available in `azure_location` for `azure_deployment_sku`, and the subscriptions it is ordered into must have quota for it, or the order fails with InsufficientQuota: `az cognitiveservices usage list` shows a subscription's limits. Quota requests take a form, there is no API for them. The default is what a new subscription gets in quota tier 0, which only covers GlobalStandard."
}

variable "azure_deployment_sku" {
  type = string
  # A new subscription starts in quota tier 0, which has quota for GlobalStandard only. Switch to
  # DataZoneStandard to keep inference in the EU once the landing zones have quota for it.
  default     = "GlobalStandard"
  description = "Deployment type of every model. `GlobalStandard` routes inference worldwide, `DataZoneStandard` keeps it inside the EU data zone of an EU region, `Standard` inside the region."
}

variable "backplane_name" {
  type        = string
  default     = "azure-ai-llm"
  description = "Name for the backplane resources (managed identity, role definition). Must match pattern ^[-a-z0-9]+$."
}

variable "notification_subscribers" {
  type        = list(string)
  default     = []
  description = "List of email addresses to notify on building block lifecycle events."
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
    trusted_runner_refs = optional(list(object({
      kind = string
      uuid = string
    })), [])
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
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

module "runner_identity" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}"

  cloud               = "azure"
  runner_ref          = var.meshstack.runner_ref
  trusted_runner_refs = var.meshstack.trusted_runner_refs
  versions            = meshstack_building_block_definition.this.versions
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/ai-llm/backplane?ref=${var.hub.git_ref}"

  name     = var.backplane_name
  scope    = var.azure_scope
  location = var.azure_location

  workload_identity_federations = module.runner_identity.identities
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = coalesce(var.bbd_display_name, "Azure AI LLM")
    description              = coalesce(var.bbd_description, "Deploys an approved AI model such as GPT-5 mini in your Azure subscription, with Entra ID authentication and a content filter.")
    support_url              = "mailto:support@meshcloud.io"
    documentation_url        = "https://hub.meshcloud.io/platforms/azure/definitions/azure-ai-llm"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/azure/ai-llm/buildingblock/logo.svg"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AZURE" }]
    run_transparency         = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block deploys an AI model, such as GPT-5 mini or an embedding model, as a ready-to-call endpoint in your Azure subscription. It speaks the Azure OpenAI API, has Microsoft's default content filter on, and accepts Entra ID tokens only, so there are no API keys to leak.

      ## 🎯 When to use it

      Use this building block when you:
      - Want to add a chat, summarization or extraction feature to an application.
      - Need embeddings for a search or retrieval-augmented generation (RAG) use case.
      - Want the model's cost on your own subscription.

      ## 💡 Usage examples

      **Example 1: Document Q&A for an internal portal**
      A team orders `gpt-5-mini` and `text-embedding-3-small`, indexes its handbook with the embedding model and lets the chat model answer questions on it. The App Service calls both with its managed identity.

      **Example 2: Ticket classification**
      A team passes the object ID of its Function App's managed identity at order time. The function classifies incoming support tickets with `gpt-5-mini` without any secret in its configuration.

      ## 🔑 Calling the model

      Use the **OpenAI Endpoint** and **Deployment Name** outputs with any Azure OpenAI client and an Entra ID token for the scope `https://cognitiveservices.azure.com/.default`. Your identity needs the role `Cognitive Services OpenAI User` on the account: the building block grants it to the identity you enter at order time.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Select approved models, region and data residency | ✅ | ❌ |
      | Provide model quota in the subscription | ✅ | ❌ |
      | Provision the endpoint with content filter and keyless auth | ✅ | ❌ |
      | Choose model and capacity for the workload | ❌ | ✅ |
      | Prompts, application logic and evaluation of answers | ❌ | ✅ |
      | Cost of tokens consumed | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft

    deletion_mode = "DELETE"
    runner_ref    = var.meshstack.runner_ref

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/azure/ai-llm/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      ARM_CLIENT_ID = {
        type            = "STRING"
        display_name    = "ARM Client ID"
        description     = "Client ID of the UAMI used to authenticate with Azure."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.identity.client_id)
      }
      ARM_TENANT_ID = {
        type            = "STRING"
        display_name    = "ARM Tenant ID"
        description     = "Azure Entra tenant ID for authentication."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.azure_tenant_id)
      }
      ARM_USE_OIDC = {
        type            = "STRING"
        display_name    = "ARM Use OIDC"
        description     = "Enables OIDC-based workload identity federation for the Azure provider."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("true")
      }
      ARM_OIDC_TOKEN_FILE_PATH = {
        type            = "STRING"
        display_name    = "ARM OIDC Token File Path"
        description     = "Path to the OIDC token file used for workload identity federation authentication."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.runner_identity.token_path)
      }
      subscription_id = {
        type            = "STRING"
        display_name    = "Subscription ID"
        description     = "The Azure subscription the endpoint is created in."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      location = {
        type            = "STRING"
        display_name    = "Location"
        description     = "The Azure region of the AI Services account."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_location)
      }
      models = {
        # CODE, not JSON: meshStack fills a JSON input through a form, which a static value has none of.
        type            = "CODE"
        display_name    = "Approved Models"
        description     = "Models application teams may choose from, with the version deployed."
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.azure_models))
      }
      deployment_sku = {
        type            = "STRING"
        display_name    = "Deployment Type"
        description     = "Where inference runs: GlobalStandard, DataZoneStandard or Standard."
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_deployment_sku)
      }
      name = {
        type                           = "STRING"
        display_name                   = "Name"
        description                    = "Name prefix of the resource group and the AI Services account. A random 5-character suffix is appended to the account (e.g. 'ticket-ai' becomes 'ticket-ai-x7k2q')."
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z][a-z0-9-]{1,20}[a-z0-9]$"
        validation_regex_error_message = "3 to 22 characters: lowercase letters, digits and dashes, starting with a letter and ending with a letter or digit."
        display_order                  = 1
      }
      model_name = {
        type              = "SINGLE_SELECT"
        display_name      = "Model"
        description       = "The model to deploy."
        assignment_type   = "USER_INPUT"
        selectable_values = keys(var.azure_models)
        display_order     = 2
      }
      capacity = {
        type            = "INTEGER"
        display_name    = "Capacity (thousand tokens per minute)"
        description     = "Rate limit of the deployment, taken from your subscription's model quota. Defaults to 10, enough for development and light production use."
        assignment_type = "USER_INPUT"
        is_optional     = true
        display_order   = 3
      }
      public_network_access_enabled = {
        type            = "BOOLEAN"
        display_name    = "Public Network Access"
        description     = "Allow calls from the public internet. Entra ID still decides who may call the model. Turn it off only if you connect the account to your network with a private endpoint yourself."
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(true)
        display_order   = 4
      }
      app_principal_id = {
        type                           = "STRING"
        display_name                   = "Application Identity Object ID"
        description                    = "Optional: object ID of the managed identity or service principal your application calls the model with. It is granted Cognitive Services OpenAI User on the account."
        assignment_type                = "USER_INPUT"
        is_optional                    = true
        value_validation_regex         = "^[0-9a-fA-F-]{36}$"
        validation_regex_error_message = "Must be an object ID (GUID)."
        display_order                  = 5
      }
    }

    outputs = {
      openai_endpoint = {
        type            = "STRING"
        display_name    = "OpenAI Endpoint"
        description     = "The endpoint OpenAI clients use as their Azure endpoint."
        assignment_type = "NONE"
      }
      endpoint = {
        type            = "STRING"
        display_name    = "AI Services Endpoint"
        description     = "The endpoint of the AI Services account."
        assignment_type = "NONE"
      }
      deployment_name = {
        type            = "STRING"
        display_name    = "Deployment Name"
        description     = "The deployment name requests address the model by."
        assignment_type = "NONE"
      }
      model = {
        type            = "STRING"
        display_name    = "Model"
        description     = "The deployed model and version."
        assignment_type = "NONE"
      }
      account_name = {
        type            = "STRING"
        display_name    = "Account Name"
        description     = "The name of the AI Services account."
        assignment_type = "NONE"
      }
      resource_group = {
        type            = "STRING"
        display_name    = "Resource Group"
        description     = "The resource group containing the AI Services account."
        assignment_type = "NONE"
      }
      portal_url = {
        type            = "STRING"
        display_name    = "Open in Azure Portal"
        description     = "Azure Portal URL of the AI Services account."
        assignment_type = "RESOURCE_URL"
      }
      summary = {
        type            = "STRING"
        display_name    = "Summary"
        description     = "A markdown summary of the endpoint and how to call it."
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.65.0, < 5.0.0"
    }
  }
}
