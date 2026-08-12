variable "litellm_api_base" {
  type        = string
  description = "Base URL of the LiteLLM gateway, for example 'https://litellm.example.com'. The model is registered on this gateway."
}

variable "litellm_admin_api_key" {
  type        = string
  sensitive   = true
  description = "LiteLLM admin key the building block authenticates with. It needs permission to register models."
}

variable "litellm_platform_type_name" {
  type        = string
  default     = "LiteLLM"
  description = "Name of the meshStack platform type the LiteLLM platform is registered under. It must match the platform type used by the `ai/litellm` module."
}

variable "litellm_model_name" {
  type        = string
  default     = "azure-gpt-4o"
  description = "Name the model is offered under on the gateway. Application teams pass this name in the 'model' field of their requests."
}

variable "litellm_model_mode" {
  type        = string
  default     = "chat"
  description = "What the deployment is used for. LiteLLM accepts 'chat', 'completion', 'embedding', 'audio_speech', 'audio_transcription', 'image_generation', 'video_generation', 'batch' and 'rerank'."
}

variable "azure_openai_endpoint" {
  type        = string
  description = "Endpoint of the Azure OpenAI resource, for example 'https://my-aoai.openai.azure.com'."
}

variable "azure_openai_api_key" {
  type        = string
  sensitive   = true
  description = "Key of the Azure OpenAI resource. LiteLLM stores it and sends it upstream, so no application team ever sees it."
}

variable "azure_openai_api_version" {
  type        = string
  default     = "2024-10-21"
  description = "Azure OpenAI data plane API version. '2024-10-21' is the latest dated GA version of the inference API."
}

variable "azure_openai_deployment_name" {
  type        = string
  default     = "gpt-4o"
  description = "Name of the model deployment in the Azure OpenAI resource. Azure routes on the deployment name, not on the model name."
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
  description = "BBD is consumed in building block compositions, for example by the ai-platform reference architecture."
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
    display_name        = "Azure OpenAI Model Backend"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ai/azure-openai/buildingblock/logo.png"
    description         = "Registers an Azure OpenAI deployment as a model backend on the LiteLLM gateway, offered to the ordering team alone."
    support_url         = "https://learn.microsoft.com/azure/ai-foundry/openai/"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = var.litellm_platform_type_name }]

    readme = chomp(<<-EOT
      This building block adds an Azure OpenAI model to your LiteLLM team. The model is registered
      for your team alone, so the gateway offers it to you and counts its spend against your budget.
      You keep calling the same LiteLLM endpoint and only pass a different model name.

      ## 🎯 When to use it

      Use this building block when you:
      - Need a model that Azure OpenAI serves, next to or instead of the sovereign models the platform offers by default.
      - Want the Azure credential to stay on the gateway rather than in your application.
      - Want the calls to appear in the same budget and the same usage reports as the rest of your model traffic.

      ## 💡 Usage examples

      **Example 1: Adding GPT-4o to an existing assistant**
      A team already calls the gateway through its virtual key. It orders this building block, reads
      the `model_name` output and changes the `model` field of its requests to that name. Nothing
      else in the application changes.

      **Example 2: Comparing two models before choosing one**
      A team wants to compare a sovereign model against Azure OpenAI on its own prompts. Both models
      answer on the same endpoint and the same key, so the comparison is one field in the request.

      ## 🔑 Calling the model

      Send your virtual key as a bearer token and pass the model name in the `model` field:

      ```sh
      curl "$API_BASE/chat/completions" \
        -H "Authorization: Bearer $VIRTUAL_KEY" \
        -H "Content-Type: application/json" \
        -d '{"model": "$MODEL_NAME", "messages": [{"role": "user", "content": "Hello"}]}'
      ```

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Create the Azure OpenAI resource and its model deployment | ✅ | ❌ |
      | Provide and rotate the Azure OpenAI credential on the gateway | ✅ | ❌ |
      | Choose which Azure deployment is offered and under which model name | ✅ | ❌ |
      | Watch the Azure quota the deployment draws from | ✅ | ❌ |
      | Pass the model name in requests to the gateway | ❌ | ✅ |
      | Stay within the granted budget | ❌ | ✅ |
      | Build and operate the application that calls the model | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # A second model entry with the same name for the same team would only duplicate the first one,
    # so meshStack allows one per tenant. Register a further deployment with its own definition.
    only_apply_once_per_tenant = true

    implementation = {
      terraform = {
        terraform_version              = "1.12.2"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/ai/azure-openai/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      litellm_api_base = {
        display_name    = "LiteLLM API Base URL"
        description     = "Base URL of the LiteLLM gateway the model is registered on."
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

      team_id = {
        display_name    = "LiteLLM Team ID"
        description     = "ID of the LiteLLM team the model is registered for. It is the platform tenant ID that the LiteLLM Team building block produces."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      azure_openai_endpoint = {
        display_name    = "Azure OpenAI Endpoint"
        description     = "Endpoint of the Azure OpenAI resource the deployment lives in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_openai_endpoint)
      }

      azure_openai_api_key = {
        display_name    = "Azure OpenAI Key"
        description     = "Key of the Azure OpenAI resource. LiteLLM stores it and sends it upstream."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.azure_openai_api_key
            secret_version = nonsensitive(sha256(var.azure_openai_api_key))
          }
        }
      }

      azure_openai_api_version = {
        display_name    = "Azure OpenAI API Version"
        description     = "Data plane API version LiteLLM calls the deployment with."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_openai_api_version)
      }

      azure_deployment_name = {
        display_name    = "Azure Deployment Name"
        description     = "Name of the model deployment in the Azure OpenAI resource."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.azure_openai_deployment_name)
      }

      model_name = {
        display_name    = "Model Name"
        description     = "Name the model is offered under on the gateway."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_model_name)
      }

      mode = {
        display_name    = "Mode"
        description     = "What the deployment is used for, for example 'chat' or 'embedding'."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.litellm_model_mode)
      }
    }

    outputs = {
      model_name = {
        display_name    = "Model Name"
        description     = "Name to pass in the 'model' field of a request to the gateway."
        type            = "STRING"
        assignment_type = "NONE"
      }

      model_id = {
        display_name    = "Model ID"
        description     = "ID LiteLLM gave the model entry."
        type            = "STRING"
        assignment_type = "NONE"
      }

      api_base = {
        display_name    = "API Base URL"
        description     = "OpenAI-compatible base URL of the gateway, including the '/v1' suffix."
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
