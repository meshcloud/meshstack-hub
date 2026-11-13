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

data "meshstack_building_block_runner" "trusted" {
  for_each = toset(var.trusted_runner_refs[*].uuid)

  metadata = {
    uuid = each.key
  }

  lifecycle {
    postcondition {
      # try: a runner without any workload identity federation has a null spec.workload_identity_federation.
      condition     = try(self.spec.workload_identity_federation[var.cloud], null) != null
      error_message = "The trusted building block runner ${each.key} offers no ${var.cloud} token. Remove it from var.meshstack.trusted_runner_refs."
    }
  }
}

locals {
  token = data.meshstack_building_block_runner.this.spec.workload_identity_federation[var.cloud]

  runners = concat(
    [data.meshstack_building_block_runner.this],
    [
      for uuid, runner in data.meshstack_building_block_runner.trusted : runner
      if uuid != data.meshstack_building_block_runner.this.ref.uuid
    ],
  )

  version_claims = [
    for version in var.versions : {
      issuer   = version.workload_identity_federation.issuer
      audience = version.workload_identity_federation[var.cloud].audience
      subject  = version.workload_identity_federation.subject
    }
    if version.workload_identity_federation != null && version.workload_identity_federation[var.cloud] != null
  ]

  runner_claims = [
    for runner in local.runners : {
      runner_uuid = runner.ref.uuid
      issuer      = runner.spec.workload_identity_federation.issuer
      audience    = runner.spec.workload_identity_federation[var.cloud].audience
    }
  ]

  runner_claim_keys = [for claims in local.runner_claims : "${claims.issuer} ${claims.audience}"]

  identities = [
    for i, runner in local.runner_claims : {
      runner_uuid = runner.runner_uuid
      issuer      = runner.issuer
      audience    = runner.audience
      subjects = distinct([
        for claims in local.version_claims : claims.subject
        if claims.issuer == runner.issuer && claims.audience == runner.audience
      ])
    }
    if index(local.runner_claim_keys, local.runner_claim_keys[i]) == i
  ]
}
