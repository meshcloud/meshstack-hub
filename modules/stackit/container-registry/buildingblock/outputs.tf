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

# One object rather than four strings, so a consumer wires the registry with a single input. Null
# until a bootstrap robot is supplied, which is what tells a consumer there is nothing to wire yet.
#
# meshStack has no sensitive building block output, so this travels in the clear, as the Forgejo
# token already does.
output "access_credentials" {
  description = "Robot credentials for this registry: `push` for pipelines, `pull` for workloads. Null until a bootstrap robot is supplied."
  value = local.mint_robots ? jsonencode({
    push = { user = local.push_robot_username, password = local.push_robot_password }
    pull = { user = local.pull_robot_username, password = local.pull_robot_password }
  }) : jsonencode(null)
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
