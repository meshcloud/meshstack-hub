variable "gcp_billing_account_id" {
  type        = string
  description = "GCP billing account ID the budgets are created under. Budgets are billing-account scoped, so this is also where the building block's service account is granted its budget roles."
}

variable "gcp_backplane_project_id" {
  type        = string
  description = "GCP project ID hosting the backplane service account and the Cloud Monitoring notification channels the budget alerts are delivered through."
}

variable "default_alert_thresholds_yaml" {
  type        = string
  description = "Default alert thresholds offered to application teams, as a YAML list of objects with 'percent' and 'basis' (ACTUAL or FORECASTED) fields."
  default     = <<-EOT
    - percent: 80
      basis: ACTUAL
    - percent: 100
      basis: FORECASTED
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

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/gcp/budget-alert/backplane?ref=${var.hub.git_ref}"

  backplane_project_id = var.gcp_backplane_project_id
  billing_account_id   = var.gcp_billing_account_id
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = "GCP Budget Alert"
    description         = "Sends email alerts when a GCP project's spend crosses configurable thresholds of a monthly budget."
    support_url         = ""
    documentation_url   = ""
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/gcp/budget-alert/buildingblock/logo.png"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "GCP" }]

    readme = chomp(<<-EOT
      This building block creates a **GCP billing budget** for your project and an email notification
      channel, so you find out about unexpected spend from an email rather than from the invoice.

      ## 🎯 When to use it

      Use this building block when you:
      - Want to be told when your project's monthly GCP spend approaches or exceeds a figure you set.
      - Want a forecast-based warning early in the month, before the spend has actually happened.

      Note that a budget alert only notifies. It never caps or stops spending, and it never disables
      resources.

      ## 💡 Usage examples

      **Example 1: Guarding a development project**
      A team sets a 200 EUR monthly budget on their dev project and gets an email once actual spend
      passes 80%, giving them time to shut down a forgotten GPU VM before the month ends.

      **Example 2: Catching a runaway workload early**
      A team keeps the default 100% forecasted threshold, so a job that starts burning budget on day
      three triggers an alert immediately — the forecast crosses the budget long before actual spend
      does.

      ## ⚙️ Configuring thresholds

      `Alert Thresholds` takes a YAML list, one entry per alert:

      ```yaml
      - percent: 80
        basis: ACTUAL
      - percent: 100
        basis: FORECASTED
      ```

      `percent` is the percentage of the budget that triggers the alert. `basis` is `ACTUAL` for spend
      already incurred, or `FORECASTED` for spend projected to the end of the month.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the budget and notification automation | ✅ | ❌ |
      | Grant the billing account permissions it needs | ✅ | ❌ |
      | Choose the budget amount and currency | ❌ | ✅ |
      | Choose the alert thresholds | ❌ | ✅ |
      | Keep the contact email address current | ❌ | ✅ |
      | Act on an alert — investigating and reducing spend | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/gcp/budget-alert/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      GOOGLE_APPLICATION_CREDENTIALS = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "Google Application Credentials"
        description     = "Path to the credentials file the google provider authenticates with."
        is_environment  = true
        argument        = jsonencode("./CREDENTIALS_FILE")
      }
      CREDENTIALS_FILE = {
        type            = "FILE"
        assignment_type = "STATIC"
        display_name    = "Credentials File"
        description     = "Key of the backplane service account, passed to the building block as a file."

        sensitive = {
          argument = {
            secret_value   = "data:application/json;base64,${base64encode(module.backplane.credentials_json)}"
            secret_version = null
          }
        }
      }
      billing_account_id = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "Billing Account ID"
        description     = "The billing account the budget is created under."
        argument        = jsonencode(var.gcp_billing_account_id)
      }
      backplane_project_id = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "Backplane Project ID"
        description     = "The project hosting the notification channel the budget alerts are delivered through."
        argument        = jsonencode(var.gcp_backplane_project_id)
      }
      project_id = {
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
        display_name    = "GCP Project ID"
        description     = "The GCP project whose spend the budget tracks."
      }
      budget_name = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "Budget Name"
        description     = "Display name of the budget in the GCP console."
      }
      monthly_budget_amount = {
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        display_name    = "Monthly Budget Amount"
        description     = "The monthly budget, in whole units of the budget currency."
        default_value   = jsonencode(100)
      }
      budget_currency = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "Budget Currency"
        description     = "Currency code of the budget amount. Must match the billing account's currency."
        default_value   = jsonencode("EUR")
      }
      contact_email = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "Contact Email"
        description     = "Email address the budget alerts are sent to."
      }
      alert_thresholds_yaml = {
        type            = "CODE"
        assignment_type = "USER_INPUT"
        display_name    = "Alert Thresholds"
        description     = "YAML list of alert thresholds, each with a 'percent' and a 'basis' of ACTUAL or FORECASTED."
        # CODE values are parsed by the runner, so a YAML document has to be encoded twice to arrive
        # as the string the building block expects.
        default_value = jsonencode(jsonencode(var.default_alert_thresholds_yaml))
      }
    }

    outputs = {
      budget_id = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "Budget ID"
        description     = "Resource name of the created budget"
      }
      budget_url = {
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
        display_name    = "GCP Console"
        description     = "Opens the budget in the GCP console"
      }
      notification_channel_id = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "Notification Channel ID"
        description     = "Resource name of the Cloud Monitoring notification channel the alerts are delivered to"
      }
      summary = {
        type            = "STRING"
        assignment_type = "SUMMARY"
        display_name    = "Summary"
        description     = "A markdown summary of the created budget"
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
    google = {
      source  = "hashicorp/google"
      version = ">= 6.12.0"
    }
  }
}
