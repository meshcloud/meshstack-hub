output "token_path" {
  description = "The path where the current runner writes the token for `cloud`. Use it as a static input of the definition."
  value       = data.meshstack_building_block_runner.current.spec.workload_identity_federation[var.cloud].token_path
}

output "identities" {
  description = "One identity per runner to trust. `subject` is null for a runner that no version runs on."
  value = [
    for runner in local.runners : {
      issuer   = runner.spec.workload_identity_federation.issuer
      audience = runner.spec.workload_identity_federation[var.cloud].audience
      # All versions on one runner present the same subject.
      # one() fails if two runners share an issuer but have different subjects.
      subject = one(distinct([for identity in local.version_identities : identity.subject if identity.issuer == runner.spec.workload_identity_federation.issuer]))
    }
  ]
}
