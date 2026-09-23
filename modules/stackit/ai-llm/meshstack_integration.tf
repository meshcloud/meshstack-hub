variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region tokens and the inference endpoint live in."
}

variable "model" {
  type        = string
  nullable    = false
  default     = "openai/gpt-oss-120b"
  description = "Model applications default to. Must be one the `/v1/models` endpoint serves."
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
    display_name        = coalesce(var.bbd_display_name, "STACKIT AI Model Serving")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/ai-llm/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Mints a STACKIT Model Serving token, so applications on this platform can call a sovereign LLM.")
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Mints a **STACKIT Model Serving** token in this project, so applications can call a large
      language model that runs on European infrastructure.

      ## 🎯 When to use it

      Use this building block when a platform offers inference to the applications running on it —
      for example the **STACKIT Kubernetes Platform** reference architecture, whose demo application
      summarises text with it.

      ## 📦 Resources created

      - **Service enablement** – `cloud.stackit.model-serving` is disabled on a fresh STACKIT
        project, so it is switched on first and waited for.
      - **Model serving token** – the credential for the inference endpoint.

      ## 🔌 How an application uses it

      The endpoint speaks the OpenAI API, so any OpenAI client works against it by pointing its base
      URL there. In the reference architecture the endpoint, the token and the model arrive in every
      application namespace as a Kubernetes secret named `stackit-ai`, with the keys
      `STACKIT_AI_BASE_URL`, `STACKIT_AI_API_KEY` and `STACKIT_AI_MODEL`.

      ## 📊 Shared responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the STACKIT project inference is billed to | ✅ | ❌ |
      | Choose the default model and rotate the token | ✅ | ❌ |
      | Use the endpoint from the application | ❌ | ✅ |
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
        repository_path                = "modules/stackit/ai-llm/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      stackit_project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project the token is created in."
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
        description     = "Region the token and the inference endpoint live in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
      }

      model = {
        display_name    = "Model"
        description     = "Model applications default to."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.model)
      }

      token_name = {
        display_name    = "Token Name"
        description     = "Name of the model serving token, shown in the STACKIT portal."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      token_description = {
        display_name    = "Token Description"
        description     = "Description of the model serving token."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("Inference access for applications on this platform.")
      }
    }

    outputs = {
      base_url = {
        display_name    = "Inference Endpoint"
        type            = "STRING"
        assignment_type = "NONE"
      }

      model = {
        display_name    = "Model"
        type            = "STRING"
        assignment_type = "NONE"
      }

      access_credentials = {
        display_name    = "Access Credentials"
        type            = "CODE"
        assignment_type = "NONE"
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
      version = ">= 0.21.0"
    }
  }
}
