# Both resources below are created through the meshStack API with the run's ephemeral API key, which
# meshStack records as their creation author. That is what makes them show "created by building
# block" provenance pointing back at the building block this module runs for.

# Runs the hub's `link` building block rather than an implementation of its own: `link` provisions
# nothing but a terraform_data, needs no cloud provider and no operator, which makes it the cheapest
# real implementation to hand a created definition. See modules/meshstack/link.
resource "meshstack_building_block_definition" "created" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
  }

  spec = {
    display_name     = var.link_name
    description      = "Link building block definition created by the Composition Demo building block."
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
    A link building block definition created by a composition rather than by a platform engineer.

    Ordering it publishes a link in your workspace and provisions no infrastructure.
    EOT
    )
  }

  version_spec = {
    # Stays a draft: releasing a version needs admin approval, which the run's ephemeral key — a
    # plain workspace key — cannot obtain. Setting draft = false would leave the version DRAFT
    # anyway, warn on every run, and leave version_latest_release null. The building block below can
    # still be created from a draft because the definition and the target are the same workspace,
    # which satisfies BuildingBlockCreationValidator.requireAccess's `selfOwning` branch.
    draft = true

    # PURGE, not DELETE: DELETE would schedule a deprovisioning run for the building block below when
    # this composition is torn down, and that run cannot start until the composition's own destroy run
    # returns — a deadlock wherever the terraform runner pool has a single worker. Nothing is leaked
    # by purging, because the `link` implementation provisions nothing but a terraform_data.
    deletion_mode = "PURGE"

    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/meshstack/link/buildingblock"
        ref_name                       = var.hub_git_ref
        terraform_version              = "1.11.0"
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    # All static, so the created building block below has no inputs left to supply. Mirrors the
    # wiring in modules/meshstack/link/meshstack_integration.tf.
    inputs = {
      url = {
        display_name    = "URL"
        description     = "Target of the link."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.link_url)
      }
      title = {
        display_name    = "Title"
        description     = "Human-readable name of the linked resource."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.link_name)
      }
      # Empty falls back to the summary the link module generates from title and url.
      summary = {
        display_name    = "Summary"
        description     = "Markdown rendered for the application team after deployment."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("")
      }
    }

    outputs = {
      url = {
        display_name    = var.link_name
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }
      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

resource "meshstack_building_block" "created" {
  spec = {
    # version_latest, not version_latest_release: the definition above stays a draft, so
    # version_latest_release is null.
    building_block_definition_version_ref = {
      uuid         = meshstack_building_block_definition.created.version_latest.uuid
      content_hash = meshstack_building_block_definition.created.version_latest.content_hash
    }

    display_name = var.link_name

    target_ref = {
      kind = "meshWorkspace"
      name = var.workspace_identifier
    }

    # Every input of the definition above is static, so there is nothing for this block to set.
    inputs = {}
  }

  # Deliberately not waiting: this run would be waiting on a run of the same implementation type,
  # which a stack with a single terraform runner cannot start until this one returns. Nothing below
  # depends on the result either — provenance is recorded when the block is created.
  wait_for_completion = false
}
