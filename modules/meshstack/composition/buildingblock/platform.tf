# The second thing this composition creates: an *empty* platform with a landing zone on it. Empty means
# the least a platform can carry — a CUSTOM platform type, no cloud connection config, and a landing
# zone whose platform properties are `{}`. That is enough for meshStack to record and show creation
# provenance on both, and it needs no cloud credentials and no operator.
#
# As in main.tf, everything here is created with the run's ephemeral API key, which is what makes
# meshStack attribute the creation to the building block this module runs for.

locals {
  # A platform, location and platform type identifier is globally unique and cannot be reused once
  # deleted, so the objects below are named after the building block that owns them. Unlike a random
  # suffix this survives re-runs without a stored value, and it makes the identifiers point back at
  # their creator on sight.
  suffix     = substr(replace(var.building_block_uuid, "-", ""), 0, 8)
  identifier = "composition-demo-${local.suffix}"
}

# meshStack ships no CUSTOM platform type, and every built-in type is a cloud platform whose config
# would need real credentials — so an empty platform needs a type of its own.
resource "meshstack_platform_type" "created" {
  metadata = {
    # Platform type identifiers are uppercase, unlike every other identifier here.
    name               = upper(local.identifier)
    owned_by_workspace = var.workspace_identifier
  }

  spec = {
    # Carries the suffix because meshStack requires platform type display names to be globally unique.
    display_name = "${var.platform_name} ${upper(local.suffix)}"

    # A 1x1 transparent PNG. The API requires an icon, and nothing here is meant to be looked at.
    icon = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNgAAIAAAUAAen63NgAAAAASUVORK5CYII="
  }
}

resource "meshstack_location" "created" {
  metadata = {
    name               = local.identifier
    owned_by_workspace = var.workspace_identifier
  }

  spec = {
    display_name = "${var.platform_name} Location"
    description  = "Location created by the Composition Demo building block."
  }
}

resource "meshstack_platform" "created" {
  metadata = {
    name               = local.identifier
    owned_by_workspace = var.workspace_identifier
  }

  spec = {
    display_name = var.platform_name
    description  = "Empty platform created by the Composition Demo building block."
    endpoint     = "https://docs.meshcloud.io"

    location_ref = {
      name = meshstack_location.created.metadata.name
    }

    # Keeps the platform out of the marketplace, which is where an empty platform belongs. meshStack
    # ties the three fields together: UNPUBLISHED is only allowed with PRIVATE, and PRIVATE requires
    # `restricted_to_workspaces` to name exactly the owner.
    availability = {
      restriction              = "PRIVATE"
      publication_state        = "UNPUBLISHED"
      restricted_to_workspaces = [var.workspace_identifier]
    }

    config = {
      custom = {
        platform_type_ref = {
          name = meshstack_platform_type.created.metadata.name
        }
      }
    }
  }
}

resource "meshstack_landingzone" "created" {
  metadata = {
    # Only unique per platform, so it can repeat the platform's identifier.
    name               = local.identifier
    owned_by_workspace = var.workspace_identifier
  }

  spec = {
    display_name = "${var.platform_name} Landing Zone"
    description  = "Empty landing zone created by the Composition Demo building block."

    automate_deletion_approval    = false
    automate_deletion_replication = false

    platform_ref = {
      uuid = meshstack_platform.created.metadata.uuid
    }

    # A custom platform has no landing zone properties at all.
    platform_properties = {
      custom = {}
    }
  }
}
