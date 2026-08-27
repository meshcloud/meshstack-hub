# Captures the moment this building block first creates the workspace, so `local.expiry_timestamp`
# below can be computed as `time_static.created + workspace_ttl_days` on every later run without the
# caller ever supplying a date. Never gated by `lifecycle.enabled` — it has to keep existing (and keep
# the same value) for as long as the block does, including after everything else it creates has been
# destroyed, or the next run would see no created-at record, capture a fresh "now", and un-expire.
#
# `rfc3339 = plantimestamp()` rather than leaving it unset: `time_static` would otherwise capture the
# real creation time via a value that is itself unknown until apply, and `local.expired` below has to
# be known at *plan* time for `lifecycle.enabled` to accept it — including on the very first run, when
# the resource does not exist yet. `plantimestamp()` is known immediately, so the resource's own
# `rfc3339` attribute is too. `ignore_changes` then keeps that first value pinned forever: without it,
# every later run would recompute `plantimestamp()` to the current time and try to update the resource
# with it, which defeats the entire point of capturing a stable creation timestamp.
resource "time_static" "created" {
  rfc3339 = plantimestamp()

  lifecycle {
    ignore_changes = [rfc3339]
  }
}

locals {
  expiry_timestamp = timeadd(time_static.created.rfc3339, "${var.workspace_ttl_days * 24}h")
  expiry_date      = formatdate("YYYY-MM-DD", local.expiry_timestamp)

  # `timestamp()` is deliberately unknown until apply (so it can't be baked into a stored resource
  # attribute), which makes it unusable in `lifecycle.enabled` — count/for_each/enabled must be known
  # at plan time. `plantimestamp()` exists for exactly this: it resolves once, at plan time, to "now".
  expired = timecmp(plantimestamp(), local.expiry_timestamp) > 0

  payment_method_identifier = "${var.workspace_identifier}-payment-method"
}

# Every resource below (other than time_static.created above) is gated on the same `!local.expired`
# flag. Running this building block again once workspace_ttl_days have elapsed since creation
# therefore tears down everything it created — bindings and the tenant first, then the project and
# payment method, then the workspace itself.
resource "meshstack_workspace" "this" {
  lifecycle {
    enabled = !local.expired
  }

  metadata = {
    name = var.workspace_identifier
    tags = merge(var.tags.workspace, {
      (var.workspace_expiry_tag_key) = [local.expiry_date]
    })
  }

  spec = {
    display_name = var.workspace_display_name
  }
}

resource "meshstack_payment_method" "this" {
  lifecycle {
    enabled = !local.expired
  }

  metadata = {
    name               = local.payment_method_identifier
    owned_by_workspace = meshstack_workspace.this.metadata.name
  }

  spec = {
    display_name = "${var.workspace_display_name} Budget"
    amount       = var.payment_method_amount
    # Same computed date as the workspace's expiry tag, not a separate input: the payment method has no
    # reason to outlive (or expire before) the workspace it is scoped to.
    expiration_date = local.expiry_date
    tags            = var.tags.payment_method
  }
}

resource "meshstack_project" "this" {
  lifecycle {
    enabled = !local.expired
  }

  metadata = {
    name               = var.project_identifier
    owned_by_workspace = meshstack_workspace.this.metadata.name
  }

  spec = {
    display_name              = var.project_display_name
    payment_method_identifier = meshstack_payment_method.this.metadata.name
    tags                      = var.tags.project
  }
}

resource "meshstack_tenant" "this" {
  lifecycle {
    enabled = !local.expired
  }

  metadata = {
    owned_by_workspace = meshstack_workspace.this.metadata.name
    owned_by_project   = meshstack_project.this.metadata.name
  }

  spec = {
    platform_ref     = var.platform_ref
    landing_zone_ref = var.landing_zone_ref
  }
}

resource "meshstack_workspace_user_binding" "owner" {
  lifecycle {
    enabled = !local.expired
  }

  metadata = {
    name = "${var.workspace_identifier}-owner"
  }

  role_ref = {
    name = var.workspace_role_name
  }

  target_ref = {
    name = meshstack_workspace.this.metadata.name
  }

  subject = {
    name = var.workspace_owner_username
  }

  expiry_date = local.expiry_date
}

resource "meshstack_project_user_binding" "admin" {
  lifecycle {
    enabled = !local.expired
  }

  metadata = {
    name = "${var.project_identifier}-admin"
  }

  role_ref = {
    name = var.project_role_name
  }

  target_ref = {
    owned_by_workspace = meshstack_workspace.this.metadata.name
    name               = meshstack_project.this.metadata.name
  }

  subject = {
    name = var.workspace_owner_username
  }
}
