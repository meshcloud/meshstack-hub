run "building_block_stackit_storage_bucket_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "stackit storage-bucket hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["bucket_name"].value_string == "smoke-test-bucket-${var.test_context.name_suffix}"
    error_message = "stackit storage-bucket hub building block expected bucket_name to be 'smoke-test-bucket-${var.test_context.name_suffix}', got ${meshstack_building_block_v2.this.status.outputs["bucket_name"].value_string}"
  }

  assert {
    condition     = strcontains(meshstack_building_block_v2.this.status.outputs["bucket_url_path_style"].value_string, "smoke-test-bucket-${var.test_context.name_suffix}")
    error_message = "stackit storage-bucket hub building block expected bucket_url_path_style to contain bucket name, got ${meshstack_building_block_v2.this.status.outputs["bucket_url_path_style"].value_string}"
  }

  assert {
    condition     = strcontains(meshstack_building_block_v2.this.status.outputs["bucket_url_path_style"].value_string, "object.storage.eu01.onstackit.cloud")
    error_message = "stackit storage-bucket hub building block expected bucket_url_path_style to contain STACKIT domain, got ${meshstack_building_block_v2.this.status.outputs["bucket_url_path_style"].value_string}"
  }

  assert {
    condition     = length(meshstack_building_block_v2.this.status.outputs["s3_access_key"].value_string) > 0
    error_message = "stackit storage-bucket hub building block expected non-empty s3_access_key"
  }
}
