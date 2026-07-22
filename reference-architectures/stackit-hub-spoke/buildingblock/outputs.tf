output "lz_folder_container_id" {
  value       = module.foundation.lz_folder_container_id
  description = "Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder."
}

output "backplane_project_id" {
  value       = module.foundation.backplane_project_id
  description = "Project ID of the STACKIT backplane project that hosts the service account used for tenant project creation."
}

output "backplane_project_url" {
  value       = module.foundation.backplane_project_url
  description = "Deep link to the backplane project in the STACKIT portal."
}
