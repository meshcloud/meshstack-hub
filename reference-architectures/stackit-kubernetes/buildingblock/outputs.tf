output "ske_project_url" {
  description = "Deep link to the STACKIT project the SKE cluster and its assets run in."
  value       = "https://portal.stackit.cloud/projects/${local.stackit_project_id}"
}

output "summary" {
  description = "Summary of the platform, as the nested building block reports it."
  # `try` because a Platform Services building block whose run failed has no outputs, and the
  # destroy run that removes it still evaluates this.
  value = try(jsondecode(meshstack_building_block.platform.status.outputs["summary"].value), "")
}
