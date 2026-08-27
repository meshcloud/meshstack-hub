locals {
  # `timestamp()` is deliberately unknown until apply (so it can't be baked into a stored resource
  # attribute), which makes it unusable in `lifecycle.enabled` — count/for_each/enabled must be known
  # at plan time. `plantimestamp()` exists for exactly this: it resolves once, at plan time, to "now".
  #
  # Comparing the whole day, not the instant: a workspace is expired the day AFTER its expiry date, not
  # partway through it — the same "no longer effective after this date" semantics
  # meshstack_workspace_user_binding.expiry_date documents for role bindings.
  expired = timecmp(plantimestamp(), "${var.workspace_expiry_date}T23:59:59Z") > 0

  payment_method_identifier = "${var.workspace_identifier}-payment-method"

  # An empty string signals "no expiration" through a STRING input that cannot carry null; the
  # provider expects an unset field for that, not an empty one.
  payment_method_expiration_date = var.payment_method_expiration_date == "" ? null : var.payment_method_expiration_date
}

# Every resource below is gated on the same `!local.expired` flag. Ordering a run of this building
# block after the workspace's expiry date has passed therefore tears down everything it created —
# bindings and the tenant first, then the project and payment method, then the workspace itself —
# through the normal destroy graph OpenTofu builds from the resource references. No explicit
# depends_on is needed for the destroy order, and none is needed for cleanup logic either: this is not
# a self-purging building block (compare `stackit-project-starterkit`) — the block itself, and its
# `summary` output, remain after the resources it managed are gone.

resource "meshstack_workspace" "this" {
  lifecycle {
    enabled = !local.expired
  }

  metadata = {
    name = var.workspace_identifier
    tags = merge(var.tags.workspace, {
      (var.workspace_expiry_tag_key) = [var.workspace_expiry_date]
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
    display_name    = "${var.workspace_display_name} Budget"
    amount          = var.payment_method_amount
    expiration_date = local.payment_method_expiration_date
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

  expiry_date = var.workspace_expiry_date
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
    name = var.project_admin_username
  }
}
