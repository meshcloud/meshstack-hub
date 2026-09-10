run "building_block_gcp_storage_bucket_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "gcp storage-bucket hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["bucket_name"].value) == "${var.test_context.run_id}-bucket"
    error_message = "gcp storage-bucket hub building block expected bucket_name to be '${var.test_context.run_id}-bucket', got ${jsondecode(meshstack_building_block.this.status.outputs["bucket_name"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["bucket_url"].value), "console.cloud.google.com/storage/browser/${var.test_context.run_id}-bucket")
    error_message = "gcp storage-bucket hub building block expected bucket_url to link the bucket in the GCP console, got ${jsondecode(meshstack_building_block.this.status.outputs["bucket_url"].value)}"
  }

  # GCS reports bucket locations in upper case (EUROPE-WEST1), so compare case-insensitively.
  assert {
    condition     = strcontains(lower(jsondecode(meshstack_building_block.this.status.outputs["summary"].value)), "**location**: europe-west1")
    error_message = "gcp storage-bucket hub building block expected summary to report the requested location, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), "gs://${var.test_context.run_id}-bucket")
    error_message = "gcp storage-bucket hub building block expected summary to contain the gsutil URI, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }
}
