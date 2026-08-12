variable "stackit_service_account_email" {
  type        = string
  description = "Email of the STACKIT service account the building block authenticates with via workload identity federation. The account needs permission to create AI Model Serving tokens in the tenant projects this definition targets."
}

variable "stackit_region" {
  type        = string
  default     = "eu01"
  description = "STACKIT region the Model Serving token is issued in. The region is part of the inference endpoint URL."
}

variable "stackit_token_ttl_duration" {
  type    = string
  default = "2160h"
  # STACKIT parses this with Go's duration parser, which knows no day unit. '90d' is rejected,
  # so 90 days has to be written as '2160h'.
  description = "Lifetime of every token this definition issues, as a Go duration. '2160h' is 90 days. Valid units are 'ns', 'us', 'ms', 's', 'm' and 'h'."
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
    display_name        = "STACKIT AI Model Serving Access"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/model-serving/buildingblock/logo.png"
    description         = "Issues a STACKIT AI Model Serving token so a tenant can call STACKIT's OpenAI-compatible inference endpoint."
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = chomp(<<-EOT
      This building block issues a STACKIT AI Model Serving token in your own STACKIT project, so
      your application can call STACKIT's OpenAI-compatible inference endpoint. Every project gets
      its own token, so usage and revocation stay per project.

      ## 🎯 When to use it

      Use this building block when you:
      - Want to call a large language model hosted on STACKIT from your application.
      - Need an endpoint that works with the usual OpenAI client libraries and with gateways such as LiteLLM.
      - Want a model credential that belongs to your project alone, instead of one token shared across the whole platform.

      ## 💡 Usage examples

      **Example 1: A chat feature in an application**
      An application team orders this building block in their project and reads the API base URL
      and the token from the outputs. The team stores both in a Kubernetes secret and points the
      OpenAI client library of the application at them.

      **Example 2: A model backend in LiteLLM**
      A team registers STACKIT AI Model Serving as a backend in LiteLLM. The `api_base` output goes
      into the `api_base` field of the model entry and the token goes into the `api_key` field,
      which LiteLLM sends upstream as a bearer token in the `Authorization` header.

      ## 🔑 Calling the endpoint

      The `api_base` output already ends in `/v1`, and that suffix belongs to the base URL. A caller
      that drops it gets a "Not Found" error. Send the token as a bearer token:

      ```sh
      curl "$API_BASE/models" \
        -H "Authorization: Bearer $API_TOKEN"
      ```

      The token is shown once, when the building block runs. Copy it into your own secret store.
      When it expires, order the building block again to get a fresh one.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Enable STACKIT AI Model Serving and provide the service account that issues tokens | ✅ | ❌ |
      | Set the token lifetime that applies to every project | ✅ | ❌ |
      | Store the token in the application's own secret store | ❌ | ✅ |
      | Choose the model and carry the cost of the calls | ❌ | ✅ |
      | Order the building block again before the token expires | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.11.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/model-serving/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project ID of the tenant the token is issued in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      service_account_email = {
        display_name    = "Service Account Email"
        description     = "Email of the STACKIT service account for WIF-based authentication."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_service_account_email)
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

      region = {
        display_name    = "STACKIT Region"
        description     = "Region the Model Serving token is issued in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
      }

      ttl_duration = {
        display_name    = "Token Lifetime"
        description     = "Lifetime of the token as a Go duration, for example '2160h' for 90 days."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_token_ttl_duration)
      }

      token_name = {
        display_name                   = "Token Name"
        description                    = "Name of the token, shown next to it in the STACKIT portal."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^.{1,200}$"
        validation_regex_error_message = "The token name must be between 1 and 200 characters long."
      }

      # STACKIT rejects an empty description, so the regex enforces at least one character.
      token_description = {
        display_name                   = "Token Description"
        description                    = "Description of the token, shown next to it in the STACKIT portal."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        updateable_by_consumer         = true
        default_value                  = jsonencode("Managed by meshStack.")
        value_validation_regex         = "^.{1,2000}$"
        validation_regex_error_message = "The token description must be between 1 and 2000 characters long."
      }
    }

    outputs = {
      api_base = {
        display_name    = "API Base URL"
        description     = "OpenAI-compatible base URL of the inference endpoint, including the '/v1' suffix."
        type            = "STRING"
        assignment_type = "NONE"
      }

      token = {
        display_name    = "API Token"
        description     = "The token the application sends as a bearer token in the 'Authorization' header."
        type            = "STRING"
        assignment_type = "NONE"
      }

      token_id = {
        display_name    = "Token ID"
        description     = "ID of the Model Serving token in STACKIT."
        type            = "STRING"
        assignment_type = "NONE"
      }

      valid_until = {
        display_name    = "Valid Until"
        description     = "Timestamp at which the token expires."
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
  }
}
