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
  description = "One identity per runner to trust, for the backplane. `subject` is null for a runner that no version runs on."
  value = [
    for identity in local.identities : {
      issuer   = identity.issuer
      audience = identity.audience
      subject  = length(identity.subjects) == 1 ? identity.subjects[0] : null
    }
  ]

  precondition {
    condition     = alltrue([for identity in local.identities : length(identity.subjects) <= 1])
    error_message = "Versions with the same issuer and audience present different subjects, so the subject of a runner is not clear. This happens when two of the runners share issuer and audience but not the subject template."
  }
}
