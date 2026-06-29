output "lz_folder_container_id" {
  value       = stackit_resourcemanager_folder.this.container_id
  description = "Container ID of the STACKIT resourcemanager folder created for the landing zone. Tenant projects are created inside this folder."
}

output "backplane_project_id" {
  value       = stackit_resourcemanager_project.backplane.project_id
  description = "Project ID of the STACKIT backplane project that hosts the service account used for tenant project creation."
}

output "backplane_project_url" {
  value       = "https://portal.stackit.cloud/projects/${stackit_resourcemanager_project.backplane.project_id}"
  description = "Deep link to the backplane project in the STACKIT portal."
}
