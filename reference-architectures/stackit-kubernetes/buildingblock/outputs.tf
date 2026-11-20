output "ske_project_url" {
  description = "Deep link to the STACKIT project the SKE cluster and its assets run in."
  value       = "https://portal.stackit.cloud/dashboard?project=${local.stackit_project_id}"
}

output "postgres" {
  description = "Shared PostgreSQL instances by stage and what a database definition on them needs, as the nested building block reports it."
  # `try` because a nested building block whose run failed has no outputs, and the destroy run still
  # evaluates this.
  value = try(jsondecode(jsondecode(meshstack_building_block.platform.status.outputs["postgres"].value)), {})
}

output "summary" {
  description = "Summary of the platform, as the nested building block reports it."
  # `try` because a STACKIT Kubernetes Platform Services building block whose run failed has no
  # outputs, and the destroy run that removes it still evaluates this.
  value = try(jsondecode(meshstack_building_block.platform.status.outputs["summary"].value), "")
}
