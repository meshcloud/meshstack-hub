output "runner_ref" {
  description = "meshStack building block runner reference. Wire into meshstack_building_block_definition.version_spec.runner_ref."
  value       = meshstack_building_block_runner.this.ref
}

output "cloud_run_service_url" {
  description = "URL of the deployed Cloud Run runner service."
  value       = google_cloud_run_v2_service.runner.uri
}
