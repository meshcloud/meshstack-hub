# Pins "now" once, at plan time (lifecycle.enabled needs a known value, unlike a real creation
# timestamp). ignore_changes keeps it stable on every later run, so the duration always counts from
# the first run, also when someone changes duration_days later.
resource "time_static" "created" {
  rfc3339 = plantimestamp()

  lifecycle {
    ignore_changes = [rfc3339]
  }
}

locals {
  expires_at  = timeadd(time_static.created.rfc3339, "${var.duration_days * 24}h")
  expiry_date = formatdate("YYYY-MM-DD", local.expires_at)

  # meshStack rejects a binding whose expiry_date lies in the past. A run that happens after expiry
  # but before the sweeper deleted this block must therefore not try to recreate the binding, e.g.
  # because meshStack already dropped it.
  expired = timecmp(plantimestamp(), local.expires_at) > 0
}

# A binding is named meshStack-wide, and one workspace can order this block several times, so the
# name cannot be derived from the inputs.
resource "random_uuid" "binding" {}

resource "meshstack_workspace_group_binding" "this" {
  lifecycle {
    enabled = !local.expired

    precondition {
      condition     = var.duration_days >= 1 && var.duration_days <= var.max_duration_days
      error_message = "duration_days must be between 1 and ${var.max_duration_days}, got ${var.duration_days}."
    }
  }

  metadata = {
    name = random_uuid.binding.result
  }

  role_ref = {
    name = var.workspace_role_name
  }

  target_ref = {
    name = var.workspace_identifier
  }

  subject = {
    name = var.group_name
  }

  # Lets meshStack end the access on its own as well, so access does not outlive its duration when
  # the sweeper is late or broken.
  expiry_date = local.expiry_date
}
