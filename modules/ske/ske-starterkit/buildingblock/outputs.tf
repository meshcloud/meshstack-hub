output "dev_project_identifier" {
  description = "The meshStack project identifier for the dev environment."
  value       = meshstack_project.dev.metadata[0].name
}

output "prod_project_identifier" {
  description = "The meshStack project identifier for the prod environment."
  value       = meshstack_project.prod.metadata[0].name
}

output "dev_tenant_identifier" {
  description = "The meshStack tenant identifier for the dev environment."
  value       = meshstack_tenant_v4.dev.metadata[0].name
}

output "prod_tenant_identifier" {
  description = "The meshStack tenant identifier for the prod environment."
  value       = meshstack_tenant_v4.prod.metadata[0].name
}
