# Re-exported from `./this` unchanged. Every output the building block definition declares has to be
# produced on every run, so an output added in `./this` has to be added here as well.

output "project_identifier" {
  description = "Identifier of the created meshProject, which is also the name of its STACKIT project."
  value       = module.this.project_identifier
}

output "stackit_project_url" {
  description = "Deep link to the created STACKIT project, once the tenant has replicated."
  value       = module.this.stackit_project_url
}

output "network_cidr" {
  description = "IPv4 CIDR of the spoke network created inside the project, or `n/a` when the landing zone has no network area."
  value       = module.this.network_cidr
}

output "summary" {
  description = "Summary of what the starterkit created."
  value       = module.this.summary
}
