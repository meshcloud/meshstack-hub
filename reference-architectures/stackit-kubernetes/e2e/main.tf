variable "test_context" {
  type     = any
  nullable = false

  validation {
    condition = alltrue([
      can(var.test_context.workspace),
      can(var.test_context.run_id),
      can(var.test_context.hub_git_ref),
      can(var.test_context.meshstack.project_identifier_suffix),
      can(var.test_context.meshstack.tag_schema.mandatory.project),
    ])
    error_message = "test_context must provide workspace, run_id, hub_git_ref, meshstack.project_identifier_suffix and meshstack.tag_schema.mandatory.project."
  }

  validation {
    condition = alltrue([
      can(var.test_context.fixtures.stackit.organization_id),
      can(var.test_context.fixtures.stackit.project_id),
      can(var.test_context.fixtures.stackit.platform_uuid),
      can(var.test_context.fixtures.stackit.landing_zone_name),
    ])
    error_message = "test_context must provide fixtures.stackit.organization_id, .project_id, .platform_uuid and .landing_zone_name."
  }

  validation {
    # try: a hub run need not set `mode`. A foundation would have to hand over its STACKIT Landing
    # Zone refs, which no test context carries.
    condition     = try(var.test_context.mode, "hub") == "hub"
    error_message = "test_context.mode must be \"hub\" (the default); this test has no foundation mode."
  }
}

locals {
  stackit = var.test_context.fixtures.stackit

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  # A landing zone has to offer every value a project assigned to it may carry.
  starterkit_project_tags = {
    confidentiality = ["Public"]
  }
  landingzone_tags = {
    confidentiality = ["Public", "Internal", "Confidential"]
  }
}

provider "stackit" {
  # Credentials come from the environment, WIF in CI.
  experiments = ["iam"]
}

# The STACKIT Landing Zone this architecture is built on: the static STACKIT platform and landing zone,
# and the two definitions the landing zone would offer.
module "service_account" {
  source = "../../../modules/stackit/service-account"

  meshstack = local.meshstack
  hub       = local.hub

  bbd_display_name = "${var.test_context.run_id} STACKIT Service Account"

  stackit_organization_id      = local.stackit.organization_id
  stackit_project_id           = local.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-sabp"
  stackit_assignable_roles     = ["editor", "iam.member-admin"]

  stackit_federation_backplane_email = module.service_account_federation.backplane_service_account_email
}

module "service_account_federation" {
  source = "../../../modules/stackit/service-account-federation"

  # Also deletes this definition before its parent's, which meshStack's `fk_tbb_Parent` constraint
  # requires.
  service_account_definition_ref = module.service_account.building_block_definition.ref

  meshstack = local.meshstack
  hub       = local.hub

  bbd_display_name = "${var.test_context.run_id} STACKIT Service Account Federation"

  stackit_project_id           = local.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-safb"
}

module "stackit_kubernetes" {
  source = "../"

  meshstack = local.meshstack
  hub       = local.hub

  playground_mode = true
}

resource "meshstack_building_block" "this" {
  # Also orders teardown: the delete run must finish before the backplanes' WIF trust is destroyed.
  depends_on = [module.service_account, module.service_account_federation, module.stackit_kubernetes]

  wait_for_completion = true

  timeouts = {
    create = "50m"
    delete = "25m"
  }

  spec = {
    building_block_definition_version_ref = { uuid = module.stackit_kubernetes.building_block_definition.version_ref.uuid }

    display_name = "${var.test_context.run_id} STACKIT Kubernetes Platform"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    # Phase 1 only, because only the STACKIT portal can link a Harbor robot to the platform's
    # service account.
    inputs = {
      landingzone = { value = jsonencode(jsonencode({
        platform_ref = { uuid = local.stackit.platform_uuid, kind = "meshPlatform" }
        landingzone_refs = {
          default = { name = local.stackit.landing_zone_name, kind = "meshLandingZone" }
        }
        service_account_bbd_version_ref            = { uuid = module.service_account.building_block_definition.version_ref.uuid }
        service_account_federation_bbd_version_ref = { uuid = module.service_account_federation.building_block_definition.version_ref.uuid }
      })) }
      landingzone_variant = { value = jsonencode("default") }
      platform_identifier = { value = jsonencode(var.test_context.run_id) }
      project_identifier  = { value = jsonencode("${var.test_context.run_id}-ske${var.test_context.meshstack.project_identifier_suffix}") }
      use_global_location = { value = jsonencode(false) }
      dns_parent_domain   = { value = jsonencode("stackit.run") }
      ai_model            = { value = jsonencode("openai/gpt-oss-120b") }

      starterkit_app_name        = { value = jsonencode("ai-summarizer") }
      starterkit_repo_clone_addr = { value = jsonencode("https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git") }

      tags = { value = jsonencode(jsonencode({
        project               = var.test_context.meshstack.tag_schema.mandatory.project
        starterkit_project    = local.starterkit_project_tags
        landingzone           = local.landingzone_tags
        building_block        = {}
        project_owner_tag_key = ""
      })) }
      stages = { value = jsonencode(jsonencode({
        dev = { landingzone = {}, project = {} }
      })) }
    }
  }
}
