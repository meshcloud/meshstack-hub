output "project_id" {
  value       = stackit_resourcemanager_project.project.project_id
  description = "The UUID of the created StackIt project."
}

output "container_id" {
  value       = stackit_resourcemanager_project.project.container_id
  description = "The user-friendly container ID of the created StackIt project."
}

output "project_name" {
  value       = stackit_resourcemanager_project.project.name
  description = "The name of the created StackIt project."
}

output "project_url" {
  value       = "https://portal.stackit.cloud/projects/${stackit_resourcemanager_project.project.project_id}"
  description = "The deep link URL to access the project in the StackIt portal."
}

output "summary" {
  description = "Summary of the created project and STACKIT organization membership onboarding for assigned project users."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    project_name       = stackit_resourcemanager_project.project.name
    project_id         = stackit_resourcemanager_project.project.project_id
    container_id       = stackit_resourcemanager_project.project.container_id
    project_url        = "https://portal.stackit.cloud/projects/${stackit_resourcemanager_project.project.project_id}"
    membership_summary = fileexists("${path.module}/stackit_organization_membership_summary.md") ? file("${path.module}/stackit_organization_membership_summary.md") : "STACKIT organization membership summary was not generated."
  })
}
