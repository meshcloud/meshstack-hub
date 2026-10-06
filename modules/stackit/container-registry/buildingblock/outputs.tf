output "registry_name" {
  description = "Name of the STACKIT container registry created in the project."
  value       = local.registry_name
}

output "registry_host" {
  description = "Host applications pull images from and `docker login` targets."
  value       = local.registry_host
}

output "registry_url" {
  description = "URL of the registry in the STACKIT Harbor instance."
  value       = local.registry_url
}

output "registry_robot_url" {
  description = "Robot Accounts tab of the Harbor project, where the bootstrap robot is created."
  value       = local.registry_robot_url
}

output "summary" {
  description = "Summary of the created registry and the one manual step it still needs."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    registry_name      = local.registry_name
    registry_host      = local.registry_host
    registry_url       = local.registry_url
    registry_robot_url = local.registry_robot_url
    stackit_project_id = var.stackit_project_id
    user_assignments   = values(local.registry_role_assignments)
  })
}
