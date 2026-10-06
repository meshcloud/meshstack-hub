variable "test_context" {
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.run_id)
    error_message = "test_context must provide workspace and run_id."
  }

  validation {
    condition = alltrue([
      can(var.test_context.fixtures.stackit.ske_platform),
      can(var.test_context.fixtures.stackit.git),
      can(var.test_context.fixtures.stackit.dns),
      can(var.test_context.fixtures.stackit.secrets_manager_instance_id),
    ])
    error_message = "test_context must provide the shared fixtures fixtures.stackit.ske_platform, .git, .dns and .secrets_manager_instance_id."
  }

  validation {
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all. A foundation
    # run would also have to hand over the refs of its STACKIT Landing Zone, which no test context
    # carries, so this test has no foundation mode.
    condition     = try(var.test_context.mode, "hub") == "hub"
    error_message = "test_context.mode must be \"hub\" (the default); this test has no foundation mode."
  }
}

locals {
  ske_fixture = var.test_context.fixtures.stackit.ske_platform
  git_fixture = var.test_context.fixtures.stackit.git

  forgejo_api_token_path = "imports/git/forgejo-api-token"

  imports = {
    project = { display_name = var.test_context.meshstack.project_display_name }
    ske     = {}
    git = {
      instance_id                     = local.git_fixture.instance_id
      instance_name                   = local.git_fixture.instance_name
      forgejo_organization            = local.git_fixture.organization
      existing_forgejo_api_token_path = local.forgejo_api_token_path
    }
  }

  existing = {
    ingress_load_balancer_ip = local.ske_fixture.ingress_load_balancer_ip
    dns = {
      zone_name = var.test_context.fixtures.stackit.dns.zone_name
    }
  }

  # Tags the test workspace requires. A landing zone has to offer every value a project assigned to
  # it may carry.
  starterkit_project_tags = {
    confidentiality = ["Public"]
  }
  landingzone_tags = {
    confidentiality = ["Public", "Internal", "Confidential"]
  }
}

module "definition" {
  source = "./modes/hub"

  test_context = var.test_context
}

provider "vault" {
  address = "https://prod.sm.eu01.stackit.cloud"
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  auth_login_userpass {
    username = module.definition.fixture_secrets_reader.username
    password = module.definition.fixture_secrets_reader.password
  }
}

ephemeral "vault_kv_secret_v2" "fixture_forgejo_api_token" {
  mount = var.test_context.fixtures.stackit.secrets_manager_instance_id
  name  = local.git_fixture.forgejo_api_token_path
}

resource "meshstack_building_block" "this" {
  # Also orders teardown: the delete run must finish before the backplanes' WIF trust is destroyed.
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.definition.version_ref

    display_name = "${var.test_context.run_id}-stackit-kubernetes"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    # Phase 1 only, because only the STACKIT portal can link a Harbor robot to the platform's
    # service account.
    inputs = {
      landingzone         = { value = jsonencode(jsonencode(module.definition.landingzone)) }
      landingzone_variant = { value = jsonencode("default") }
      platform_identifier = { value = jsonencode(var.test_context.run_id) }
      project_identifier  = { value = jsonencode(var.test_context.project) }
      cluster_name        = { value = jsonencode(local.ske_fixture.cluster_name) }
      use_global_location = { value = jsonencode(false) }
      dns_parent_domain   = { value = jsonencode("stackit.run") }
      ai_model            = { value = jsonencode("openai/gpt-oss-120b") }

      starterkit_app_name        = { value = jsonencode("ai-summarizer") }
      starterkit_repo_clone_addr = { value = jsonencode("https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git") }

      tags = { value = jsonencode(jsonencode({
        # The platform adopts the fixtures project and would otherwise rewrite its tags.
        project               = var.test_context.meshstack.project_tags
        starterkit_project    = local.starterkit_project_tags
        landingzone           = local.landingzone_tags
        building_block        = {}
        project_owner_tag_key = ""
      })) }
      stages = { value = jsonencode(jsonencode({
        dev = { landingzone = {}, project = {} }
      })) }
      imports  = { value = jsonencode(jsonencode(local.imports)) }
      existing = { value = jsonencode(jsonencode(local.existing)) }
      import_secrets = {
        sensitive = {
          secret_value = jsonencode({
            (local.forgejo_api_token_path) = { forgejo_api_token = ephemeral.vault_kv_secret_v2.fixture_forgejo_api_token.data.forgejo_api_token }
          })
          # The fixture token never changes, so a fixed version is enough; an ephemeral value cannot be
          # hashed into one.
          secret_version = "1"
        }
      }
    }
  }
}
