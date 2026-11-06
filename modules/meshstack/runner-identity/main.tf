data "meshstack_building_block_runner" "current" {
  metadata = {
    uuid = var.runner_ref == null ? null : var.runner_ref.uuid
  }

  lifecycle {
    postcondition {
      condition     = self.spec.workload_identity_federation != null && self.spec.workload_identity_federation[var.cloud] != null
      error_message = "Building block runner ${self.ref.uuid} must have ${var.cloud} workload identity federation, so that its runs can sign in to ${var.cloud}."
    }
  }
}

data "meshstack_building_block_runner" "trusted" {
  for_each = toset([for ref in var.trusted_runner_refs : ref.uuid])

  metadata = {
    uuid = each.key
  }

  lifecycle {
    postcondition {
      condition     = self.spec.workload_identity_federation != null && self.spec.workload_identity_federation[var.cloud] != null
      error_message = "Building block runner ${self.ref.uuid} must have ${var.cloud} workload identity federation, so that its runs can sign in to ${var.cloud}."
    }
  }
}

locals {
  runners = concat(
    [data.meshstack_building_block_runner.current],
    [for uuid, runner in data.meshstack_building_block_runner.trusted : runner if uuid != data.meshstack_building_block_runner.current.ref.uuid],
  )

  version_identities = [
    for version in values(var.versions) : version.workload_identity_federation
    if version.workload_identity_federation != null
  ]
}
