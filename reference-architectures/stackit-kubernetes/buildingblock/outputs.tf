output "ske_project_url" {
  description = "Deep link to the STACKIT project the SKE cluster and its assets run in."
  value       = "https://portal.stackit.cloud/projects/${local.stackit_project_id}"
}

output "summary" {
  description = "Summary of the resources created by this reference architecture, as the nested Platform Services building block reports it."
  value       = jsondecode(meshstack_building_block.platform.status.outputs["summary"].value)
}
