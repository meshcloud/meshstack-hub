variable "kubernetes_service_account_definition_ref" {
  type = object({
    kind = string
    uuid = string
  })
  nullable    = false
  description = "Ref of the `kubernetes/service-account` building block definition whose kubeconfig the CronJob deploys with. Order it with a role that may manage service accounts, Secrets and CronJobs, such as `edit`."
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
    ref         = meshstack_building_block_definition.this.ref
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

# Each object input takes its defaults from one local, which feeds both the input's `default_value`
# and the `default` of each field in its schema, because the order form only shows the latter.
locals {
  resources_default = {
    cpu_request    = "100m"
    memory_request = "256Mi"
    cpu_limit      = "500m"
    memory_limit   = "512Mi"
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "Kubernetes CronJob")
    description         = coalesce(var.bbd_description, "Runs a container image on a cron schedule in your Kubernetes namespace, with plain and secret environment variables.")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/cronjob/buildingblock/logo.png"
    support_url         = "https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "KUBERNETES" }]
    run_transparency    = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **Kubernetes CronJob** building block runs a container image on a cron schedule in your namespace. Secret environment variables go into a Kubernetes secret, and the job can get a token of its own service account to sign in to a cloud through workload identity federation.

    ## 🎯 When to use it

    Use this building block when you:
    - Run a recurring task, such as a report, an export, a cleanup or a metering job, from a container image.
    - Already have a namespace with a Kubernetes Service Account building block that may manage service accounts, Secrets and CronJobs, such as one with the `edit` role.

    ## 💡 Usage examples

    **Example 1: Nightly export**
    A team orders a CronJob that runs its export image at `0 2 * * *` and passes the database password as a secret environment variable.

    **Example 2: Cloud access without a key**
    A job reads from a cloud API. It mounts a service account token with the cloud's audience, and the cloud trusts that token through workload identity federation, so there is no cloud key to store.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Operate the Kubernetes cluster | ✅ | ❌ |
    | Provide the container image and its configuration | ❌ | ✅ |
    | Rotate the secret environment variables | ❌ | ✅ |
    | Monitor failed job runs | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    runner_ref    = var.meshstack.runner_ref
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/kubernetes/cronjob/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    dependency_refs = [var.kubernetes_service_account_definition_ref]

    inputs = {
      name = {
        display_name                   = "Name"
        description                    = "Name of the CronJob and of the Kubernetes service account its pods run as."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([-a-z0-9]{0,50}[a-z0-9])?$"
        validation_regex_error_message = "Name must be at most 52 lowercase letters, digits and dashes, and not start or end with a dash."
        display_order                  = 1
      }

      image = {
        display_name           = "Image"
        description            = "Container image the job runs, e.g. ghcr.io/example/report:1.2.3. It is pulled on every run."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 2
      }

      schedule = {
        display_name           = "Schedule"
        description            = "Cron schedule of the job, e.g. 0 * * * *."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("0 * * * *")
        updateable_by_consumer = true
        display_order          = 3
      }

      env = {
        display_name           = "Environment Variables"
        description            = "Environment variables of the container, as name and value."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(jsonencode({}))
        updateable_by_consumer = true
        display_order          = 4
        json_schema = jsonencode({
          "$schema"            = "http://json-schema.org/draft-07/schema#"
          type                 = "object"
          additionalProperties = { type = "string" }
        })
      }

      # CODE, because meshStack only encrypts STRING, FILE and CODE inputs, so a sensitive one cannot be JSON.
      secret_env = {
        display_name           = "Secret Environment Variables"
        description            = "Environment variables of the container that are kept in a Kubernetes secret, as a JSON object of name and value, e.g. {\"API_TOKEN\": \"...\"}."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        is_optional            = true
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 5
      }

      secret_env_revision = {
        display_name           = "Secret Revision"
        description            = "Increase to write changed secret environment variables to the Kubernetes secret."
        type                   = "INTEGER"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(1)
        updateable_by_consumer = true
        display_order          = 6
      }

      service_account_token = {
        display_name           = "Service Account Token"
        description            = "Mounts a token of the job's Kubernetes service account with this audience at <mount path>/token, for workload identity federation with a cloud. Leave it empty for no token."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        is_optional            = true
        updateable_by_consumer = true
        display_order          = 7
        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["audience", "mount_path"]
          properties = {
            audience   = { type = "string", title = "Audience" }
            mount_path = { type = "string", title = "Mount Path, e.g. /var/run/secrets/tokens" }
          }
        })
      }

      resources = {
        display_name           = "Resources"
        description            = "CPU and memory requests and limits of the container."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(jsonencode(local.resources_default))
        updateable_by_consumer = true
        display_order          = 8
        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["cpu_request", "memory_request", "cpu_limit", "memory_limit"]
          properties = {
            cpu_request    = { type = "string", title = "CPU Request", default = local.resources_default.cpu_request }
            memory_request = { type = "string", title = "Memory Request", default = local.resources_default.memory_request }
            cpu_limit      = { type = "string", title = "CPU Limit", default = local.resources_default.cpu_limit }
            memory_limit   = { type = "string", title = "Memory Limit", default = local.resources_default.memory_limit }
          }
        })
      }

      kubeconfig = {
        display_name    = "Kubeconfig"
        description     = "Kubeconfig of the parent Kubernetes Service Account building block."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = jsonencode("${var.kubernetes_service_account_definition_ref.uuid}.kubeconfig")
        display_order   = 9
      }

      namespace = {
        display_name    = "Namespace"
        description     = "Kubernetes namespace of the tenant the CronJob runs in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
        display_order   = 10
      }
    }

    outputs = {
      cron_job_name = {
        display_name    = "CronJob"
        type            = "STRING"
        assignment_type = "NONE"
      }

      service_account_subject = {
        display_name    = "Service Account Subject"
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
      version = ">= 0.27.2"
    }
  }
}
