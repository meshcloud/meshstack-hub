data "meshstack_building_block_runner" "this" {
  metadata = {
    uuid = var.runner_ref == null ? null : var.runner_ref.uuid
  }

  lifecycle {
    postcondition {
      # try: a runner without any workload identity federation has a null spec.workload_identity_federation.
      condition     = try(self.spec.workload_identity_federation[var.cloud], null) != null
      error_message = "The building block runner offers no ${var.cloud} token. Pick a runner that offers one via var.meshstack.runner_ref."
    }
  }
}

locals {
  token = data.meshstack_building_block_runner.this.spec.workload_identity_federation[var.cloud]
}
