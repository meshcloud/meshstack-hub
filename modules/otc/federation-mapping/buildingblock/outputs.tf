output "function_urn" {
  value       = opentelekomcloud_fgs_function_v2.this.urn
  description = "URN of the function that rebuilds the mapping."
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # Federation mapping

    The function `${opentelekomcloud_fgs_function_v2.this.name}` rebuilds the mapping of the identity
    provider `${var.identity_provider_name}` whenever a project records or removes its membership in
    the bucket `${var.mapping_bucket}`, and every run of `${var.resync_schedule}` regardless.

    Its logs are in the FunctionGraph console of this project. A user who is missing a project role
    after signing in again usually shows up there as a rule that was not written.
  EOT
}
