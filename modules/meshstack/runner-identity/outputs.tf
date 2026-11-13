output "ref" {
  description = "The `ref` of the looked-up runner. Set `version_spec.runner_ref` to it, so that every run uses the runner the other outputs describe."
  value       = data.meshstack_building_block_runner.this.ref
}

output "token_path" {
  description = "The path where the runner writes the token for `cloud`. Use it as a static input of the definition."
  value       = local.token.token_path
}

output "issuer" {
  description = "The issuer of the runner's tokens, for the backplane to trust."
  value       = data.meshstack_building_block_runner.this.spec.workload_identity_federation.issuer
}

output "audience" {
  description = "The audience of the runner's token for `cloud`, for the backplane to trust."
  value       = local.token.audience
}

output "identities" {
  description = "One entry per runner with the issuer, audience and subject of its tokens. The runner in `runner_ref` comes first, then the runners in `trusted_runner_refs`, ordered by uuid. Two runners with the same issuer and audience share one entry with the uuid of the first. `subject` is null for a runner that no version uses."
  value = [
    for identity in local.identities : {
      runner_uuid = identity.runner_uuid
      issuer      = identity.issuer
      audience    = identity.audience
      subject     = length(identity.subjects) == 1 ? identity.subjects[0] : null
    }
  ]

  precondition {
    condition     = alltrue([for identity in local.identities : length(identity.subjects) <= 1])
    error_message = "Two of the runners in runner_ref and trusted_runner_refs have the same issuer and audience but different subject templates. The module cannot match the versions to one of the two, so it supports only one of them. If you remove one, the cloud rejects the tokens of its building blocks."
  }
}

output "trusted_identities" {
  description = "`identities` without its first entry. Use it if the backplane takes the runner in `runner_ref` in a separate variable."
  value = [
    for identity in slice(local.identities, 1, length(local.identities)) : {
      runner_uuid = identity.runner_uuid
      issuer      = identity.issuer
      audience    = identity.audience
      subject     = length(identity.subjects) == 1 ? identity.subjects[0] : null
    }
  ]

  precondition {
    condition     = alltrue([for identity in local.identities : length(identity.subjects) <= 1])
    error_message = "Two of the runners in runner_ref and trusted_runner_refs have the same issuer and audience but different subject templates. The module cannot match the versions to one of the two, so it supports only one of them. If you remove one, the cloud rejects the tokens of its building blocks."
  }

  precondition {
    condition     = local.latest_version_fits_runner
    error_message = "Version ${coalesce(local.latest_version_number, 0)} of the building block definition is released and uses another runner than meshstack.runner_ref. Set hub.bbd_draft = true to create a draft version with the new runner."
  }
}
