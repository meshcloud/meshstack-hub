locals {
  # A platform type identifier can never be reused, not even after the type is deleted, so the run
  # suffix is what keeps repeated and concurrent runs from colliding. Uppercase and dashes only.
  platform_type_name = "NOOP-TAG-${var.test_context.name_suffix}"

  # The test instance caps a project identifier at 30 characters and requires a stage suffix.
  project_identifier = "noop-tag-${var.test_context.name_suffix}-dev"

  # Tag definitions are instance-global, so every key carries the run suffix. They must also differ
  # from the instance's mandatory keys below, or the "landing zone offers every value" rule would
  # couple the project tag to the landing zone tag and block a change to either on its own.
  project_tag_key        = "noopProject${var.test_context.name_suffix}"
  payment_method_tag_key = "noopPaymentMethod${var.test_context.name_suffix}"
  landing_zone_tag_key   = "noopLandingZone${var.test_context.name_suffix}"

  # The test workspace makes these tags mandatory, and a landing zone has to offer every value a
  # project assigned to it may carry — meshStack rejects both objects otherwise.
  landingzone_tags = {
    confidentiality = ["Public", "Internal", "Confidential"]
    environment     = ["dev", "qa", "prod"]
  }

  project_tags = {
    confidentiality = ["Public"]
    environment     = ["dev"]
  }

  # Each scenario changes as little as possible against the one before it, so a failed assertion
  # names one mechanism rather than three. `initial` establishes the values, `changed_values` edits
  # all three tags, and `reassigned_payment_method` leaves every tag alone and funds the project from
  # the substitute payment method instead — which is a different trigger, not a tag edit.
  scenarios = {
    initial = {
      run_marker              = 1
      project_tag_values      = ["cc-1000"]
      primary_pm_tag_values   = ["pm-primary"]
      landing_zone_tag_values = ["lz-a", "lz-b"]
      funding                 = "primary"
    }
    changed_values = {
      run_marker              = 2
      project_tag_values      = ["cc-2000"]
      primary_pm_tag_values   = ["pm-primary-edited"]
      landing_zone_tag_values = ["lz-c"]
      funding                 = "primary"
    }
    reassigned_payment_method = {
      run_marker              = 3
      project_tag_values      = ["cc-2000"]
      primary_pm_tag_values   = ["pm-primary-edited"]
      landing_zone_tag_values = ["lz-c"]
      funding                 = "substitute"
    }
  }

  scenario = local.scenarios[var.scenario]

  # Constant, so the reassignment scenario changes the resolved value by changing which payment
  # method the project reads from — not by editing a tag.
  substitute_pm_tag_values = ["pm-substitute"]

  payment_methods = {
    primary    = meshstack_payment_method.primary.metadata.name
    substitute = meshstack_payment_method.substitute.metadata.name
  }
}

# Tag definitions are admin-scoped meshObjects (ADM_TAGDEFINITION_SAVE has no workspace-scoped
# variant) and global to the instance. The building block definition reads `spec.key` from these
# resources rather than repeating the string, which is also what gets the destroy order right:
# meshStack refuses to delete a tag definition while a building block still reads it.
resource "meshstack_tag_definition" "project" {
  spec = {
    target_kind  = "meshProject"
    key          = local.project_tag_key
    display_name = "NoOp Project Tag"
    description  = "Smoke test tag read by the tenant-level NoOp building block."
    value_type   = { string = {} }
    mandatory    = false
    immutable    = false
    restricted   = false
  }
}

resource "meshstack_tag_definition" "payment_method" {
  spec = {
    target_kind  = "meshPaymentMethod"
    key          = local.payment_method_tag_key
    display_name = "NoOp Payment Method Tag"
    description  = "Smoke test tag read by the tenant-level NoOp building block."
    value_type   = { string = {} }
    mandatory    = false
    immutable    = false
    restricted   = false
  }
}

resource "meshstack_tag_definition" "landing_zone" {
  spec = {
    target_kind  = "meshLandingZone"
    key          = local.landing_zone_tag_key
    display_name = "NoOp Landing Zone Tag"
    description  = "Smoke test tag read by the tenant-level NoOp building block."
    value_type   = { string = {} }
    mandatory    = false
    immutable    = false
    restricted   = false
  }
}

# A custom platform is what makes the tenant this test needs reachable without a cloud: it has no
# replicator, so nothing outside meshStack has to exist or succeed.
resource "meshstack_platform_type" "this" {
  metadata = {
    name               = local.platform_type_name
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name = "NoOp Tag Inputs ${var.test_context.name_suffix}"
    icon         = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciLz4="
  }
}

resource "meshstack_platform" "this" {
  metadata = {
    name               = "noop-tag-${var.test_context.name_suffix}"
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name = "NoOp Tag Inputs ${var.test_context.name_suffix}"
    description  = "Smoke test platform for the tenant-level NoOp building block."
    endpoint     = "https://hub.meshcloud.io/modules/meshstack/noop"
    location_ref = { name = "global" }

    availability = {
      restriction              = "RESTRICTED"
      publication_state        = "UNPUBLISHED"
      restricted_to_workspaces = [var.test_context.workspace]
    }

    config = {
      custom = {
        platform_type_ref = meshstack_platform_type.this.ref
      }
    }
  }

  lifecycle {
    ignore_changes = [spec.availability]
  }
}

# Without this, `meshstack_tenant` never finishes creating: the provider treats a tenant as created
# once `spec.platform_tenant_id` is set, and a custom platform has no replicator to set it. A
# mandatory building block whose only output is assigned PLATFORM_TENANT_ID supplies it instead. All
# its inputs are STATIC, so the manual run completes with no operator action.
resource "meshstack_building_block_definition" "platform_tenant_id" {
  metadata = {
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name        = "NoOp Tag Inputs Platform Tenant ID ${var.test_context.name_suffix}"
    description         = "Supplies a platform tenant ID so tenants on the custom platform replicate."
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = meshstack_platform_type.this.metadata.name }]
  }

  version_spec = {
    # Released, not draft: a landing zone's mandatory building block ref resolves the definition's
    # latest released version.
    draft          = false
    deletion_mode  = "DELETE"
    implementation = { manual = {} }

    inputs = {
      tenant_id = {
        display_name    = "Tenant ID"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("noop-tag-${var.test_context.name_suffix}")
      }
    }

    outputs = {
      # A manual output's type is derived from the matching input and must not be set.
      tenant_id = {
        display_name    = "Tenant ID"
        assignment_type = "PLATFORM_TENANT_ID"
      }
    }
  }
}

resource "meshstack_landingzone" "this" {
  metadata = {
    name               = "noop-tag-lz-${var.test_context.name_suffix}"
    owned_by_workspace = var.test_context.workspace
    tags = merge(local.landingzone_tags, {
      (meshstack_tag_definition.landing_zone.spec.key) = local.scenario.landing_zone_tag_values
    })
  }

  spec = {
    display_name = "NoOp Tag Inputs ${var.test_context.name_suffix}"
    description  = "Smoke test landing zone for the tenant-level NoOp building block."

    # Both automated, so tearing the tenant down needs no operator action.
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = meshstack_platform.this.ref

    platform_properties = {
      # Nothing to specify for a custom platform, but the block has to be present.
      custom = {}
    }

    mandatory_building_block_refs = [
      { uuid = meshstack_building_block_definition.platform_tenant_id.metadata.uuid }
    ]
  }
}

# Payment methods are admin-scoped too (ADM_PAYMENTMETHOD_SAVE). Two of them, because reassigning
# which one funds the project is the cheapest of meshStack's four tag-source reassignment triggers.
resource "meshstack_payment_method" "primary" {
  metadata = {
    name               = "noop-tag-pm-a-${var.test_context.name_suffix}"
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name = "NoOp Tag Inputs Primary ${var.test_context.name_suffix}"
    tags = {
      (meshstack_tag_definition.payment_method.spec.key) = local.scenario.primary_pm_tag_values
    }
  }
}

resource "meshstack_payment_method" "substitute" {
  metadata = {
    name               = "noop-tag-pm-b-${var.test_context.name_suffix}"
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name = "NoOp Tag Inputs Substitute ${var.test_context.name_suffix}"
    tags = {
      (meshstack_tag_definition.payment_method.spec.key) = local.substitute_pm_tag_values
    }
  }
}

resource "meshstack_project" "this" {
  metadata = {
    name               = local.project_identifier
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name              = "NoOp Tag Inputs ${var.test_context.name_suffix}"
    payment_method_identifier = local.payment_methods[local.scenario.funding]
    tags = merge(local.project_tags, {
      (meshstack_tag_definition.project.spec.key) = local.scenario.project_tag_values
    })
  }
}

resource "meshstack_tenant" "this" {
  # The delete run deprovisions the landing zone's mandatory building block, which has to still be
  # there for it. Without this OpenTofu is free to tear the landing zone down in parallel.
  depends_on          = [meshstack_landingzone.this]
  wait_for_completion = true

  metadata = {
    owned_by_workspace = var.test_context.workspace
    owned_by_project   = meshstack_project.this.metadata.name
  }

  spec = {
    platform_ref     = meshstack_platform.this.ref
    landing_zone_ref = meshstack_landingzone.this.ref
  }
}

module "noop" {
  source = "../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  tenant_tag_inputs = {
    project_tag_key        = meshstack_tag_definition.project.spec.key
    payment_method_tag_key = meshstack_tag_definition.payment_method.spec.key
    landing_zone_tag_key   = meshstack_tag_definition.landing_zone.spec.key
    platform_type_name     = meshstack_platform_type.this.metadata.name
  }
}

resource "time_sleep" "tag_settle" {
  depends_on = [
    meshstack_project.this,
    meshstack_payment_method.primary,
    meshstack_payment_method.substitute,
    meshstack_landingzone.this,
  ]

  create_duration = var.tag_settle_duration

  # Replacement is destroy-then-create, which is what makes the wait happen again on every scenario
  # rather than only the first.
  triggers = {
    scenario = var.scenario
  }
}

resource "meshstack_building_block" "this" {
  # Ordering, not just teardown: the tag writes have to land before the update that triggers the run
  # this test reads, and the settle has to sit between the two.
  depends_on = [
    module.noop,
    time_sleep.tag_settle,
  ]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = module.noop.tenant_building_block_definition.version_ref.uuid }

    display_name = "smoke-test-noop-tag-inputs-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant.this.metadata.uuid
    }

    inputs = {
      flag = { value = jsonencode(true) }
      # The run marker. A TAG input is resolved by meshStack, so nothing in the configuration makes
      # the provider notice a tag change; bumping an input it does track is what makes it issue an
      # update and wait for the run that resolves the current tags.
      num               = { value = jsonencode(local.scenario.run_marker) }
      text              = { value = jsonencode("Hello, Tag World!") }
      sensitive_text    = { sensitive = { secret_value = "Hidden value" } }
      single_select     = { value = jsonencode("single1") }
      multi_select      = { value = jsonencode(["multi1", "multi2"]) }
      multi_select_json = { value = jsonencode(["multi2", "multi1"]) }
    }
  }
}
