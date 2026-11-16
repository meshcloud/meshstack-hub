output "runner_ref" {
  description = "meshStack building block runner reference. Pass it as meshstack.runner_ref to the module's meshstack_integration.tf."
  value       = meshstack_building_block_runner.this.ref
}

output "cloud_run_service_url" {
  description = "URL of the deployed Cloud Run runner service."
  value       = google_cloud_run_v2_service.runner.uri
}
