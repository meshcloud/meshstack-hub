variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    meshstack = object({
      project_identifier_suffix = string
      tag_schema = object({
        mandatory = object({
          project        = map(list(string))
          payment_method = map(list(string))
        })
      })
    })

    fixtures = object({
      github = object({
        owner      = string
        repository = string
        branch     = optional(string, "main")
      })
    })
  })
  nullable = false
}

variable "ske_kubeconfig" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "github_app_id" {
  type     = string
  nullable = false
}

variable "github_app_private_key" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "github_app_installation_id" {
  type     = string
  nullable = false
}

variable "run_controller_image" {
  type        = string
  default     = "ghcr.io/meshcloud/run-controller:623418da18b934d1daa9fcbb2d30311f07eb432f"
  description = "Run-controller image. A controller built from runner `main` carries a version no image tag has, so the Job image needs a tag too."
}

variable "run_controller_job_image" {
  type    = string
  default = "ghcr.io/meshcloud/building-block-runner:623418da18b934d1daa9fcbb2d30311f07eb432f"
}

locals {
  ske_kubeconfig = yamldecode(var.ske_kubeconfig)

  project_identifier = "${var.test_context.run_id}-rc${var.test_context.meshstack.project_identifier_suffix}"

  runner_ref = jsondecode(jsondecode(meshstack_building_block.run_controller.status.outputs["runner_ref"].value))

  github_repository_name = one(slice(split("/", var.test_context.fixtures.github.repository), 1, 2))
}

module "kubernetes_platform" {
  source = "../../../ske/ske-starterkit/e2e/modes/hub/meshstack_kubernetes_platform"

  kube_host = local.ske_kubeconfig["clusters"][0]["cluster"]["server"]
  workspace = var.test_context.workspace
  run_id    = var.test_context.run_id
}

resource "meshstack_project" "this" {
  metadata = {
    name               = local.project_identifier
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name = "${var.test_context.run_id} Run Controller"
    tags         = var.test_context.meshstack.tag_schema.mandatory.project
  }
}

resource "meshstack_tenant" "this" {
  depends_on          = [module.kubernetes_platform]
  wait_for_completion = true

  metadata = {
    owned_by_workspace = var.test_context.workspace
    owned_by_project   = meshstack_project.this.metadata.name
  }

  spec = {
    platform_ref     = module.kubernetes_platform.platform_ref
    landing_zone_ref = module.kubernetes_platform.landing_zone_refs["dev"]
  }
}

module "run_controller" {
  source = "../"

  bbd_display_name = "${var.test_context.run_id} Building Block Run Controller"

  kubernetes_api_server_url            = local.ske_kubeconfig["clusters"][0]["cluster"]["server"]
  kubernetes_api_server_ca_certificate = base64decode(local.ske_kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"])
  kubernetes_backplane_name            = "${var.test_context.run_id}-run-controller"
  run_controller_image                 = var.run_controller_image
  run_controller_job_image             = var.run_controller_job_image

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
}

resource "time_static" "runner_key_expiry" {}

resource "meshstack_api_key" "runner" {
  metadata = {
    owned_by_workspace = var.test_context.workspace
  }
  spec = {
    display_name = "${var.test_context.run_id}-run-controller"
    permissions = [
      "MANAGED_BUILDINGBLOCKRUN_SAVE",
      "MANAGED_BUILDINGBLOCKRUNSOURCE_SAVE",
    ]
    expires_at = formatdate("YYYY-MM-DD", timeadd(time_static.runner_key_expiry.rfc3339, "168h"))
  }
}

resource "meshstack_building_block" "run_controller" {
  depends_on          = [module.run_controller]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.run_controller.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-run-controller"
    target_ref   = meshstack_tenant.this.ref

    inputs = {
      runner_api_key_client_id = { value = jsonencode(meshstack_api_key.runner.status.client_id) }
      runner_api_key_client_secret = {
        sensitive = {
          secret_value   = meshstack_api_key.runner.status.client_secret
          secret_version = nonsensitive(sha256(meshstack_api_key.runner.status.client_secret))
        }
      }
    }
  }

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}

resource "meshstack_tag_definition" "noop" {
  spec = {
    target_kind  = "meshWorkspace"
    key          = "${var.test_context.run_id}-run-controller-noop-tag"
    display_name = "${var.test_context.run_id} Run Controller NoOp Tag"
    value_type   = { string = {} }
  }
}

resource "meshstack_workspace_tag" "noop" {
  metadata = {
    workspace_identifier = var.test_context.workspace
    key                  = meshstack_tag_definition.noop.spec.key
  }
  spec = {
    values = ["e2e-tag-value"]
  }
}

resource "meshstack_payment_method" "noop" {
  metadata = {
    name               = "${var.test_context.run_id}-rc-noop-pm"
    owned_by_workspace = var.test_context.workspace
  }
  spec = {
    display_name = "${var.test_context.run_id} Run Controller NoOp Payment Method"
    tags         = var.test_context.meshstack.tag_schema.mandatory.payment_method
  }
}

module "noop" {
  source = "../../noop"

  bbd_display_name = "${var.test_context.run_id} Run Controller NoOp"
  tag_object       = "WORKSPACE"
  tag_key          = meshstack_tag_definition.noop.spec.key

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    runner_ref                  = local.runner_ref
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
}

resource "meshstack_building_block" "noop" {
  depends_on          = [module.noop, meshstack_workspace_tag.noop]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.noop.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-run-controller-noop"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      flag              = { value = jsonencode(true) }
      num               = { value = jsonencode(1) }
      text              = { value = jsonencode("Hello, World!") }
      conditional_text  = { value = jsonencode("Shown because flag is true") }
      deploy_settings   = { value = jsonencode(jsonencode({ greeting = "Hello from e2e", shout = true })) }
      sensitive_text    = { sensitive = { secret_value = "Hidden value" } }
      single_select     = { value = jsonencode("single1") }
      multi_select      = { value = jsonencode(["multi1", "multi2"]) }
      multi_select_json = { value = jsonencode(["multi2", "multi1"]) }
      payment_method    = { value = jsonencode(meshstack_payment_method.noop.ref) }
      operator_text     = { value = jsonencode("Set by the platform operator") }
    }
  }

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}

resource "github_branch" "ephemeral" {
  repository    = local.github_repository_name
  branch        = "${var.test_context.run_id}/run-controller-github-workflow"
  source_branch = var.test_context.fixtures.github.branch
}

module "github_workflow" {
  source = "../../github-workflow"

  bbd_display_name         = "${var.test_context.run_id} Run Controller GitHub Workflow"
  integration_display_name = "${var.test_context.run_id} Run Controller GitHub Integration"

  github_owner               = var.test_context.fixtures.github.owner
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key
  github_repository          = var.test_context.fixtures.github.repository
  github_branch              = github_branch.ephemeral.branch
  github_async               = false
  github_destroy_workflow    = "destroy.yml"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    runner_ref                  = local.runner_ref
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
}

resource "meshstack_building_block" "github_workflow" {
  # The delete run dispatches the destroy workflow, which lives on the ephemeral branch.
  depends_on          = [module.github_workflow, github_branch.ephemeral]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.github_workflow.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-run-controller-github-workflow"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      environment = { value = jsonencode("dev") }
    }
  }

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}

module "manual" {
  source = "../../manual"

  bbd_display_name = "${var.test_context.run_id} Run Controller Manual"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    runner_ref                  = local.runner_ref
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
}

resource "meshstack_building_block" "manual" {
  depends_on          = [module.manual]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.manual.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-run-controller-manual"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      text          = { value = jsonencode("Hello, Manual World!") }
      flag          = { value = jsonencode(true) }
      num           = { value = jsonencode(42) }
      single_select = { value = jsonencode("option1") }
    }
  }

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}
