run "building_block_stackit_storage_bucket_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "stackit storage-bucket hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["bucket_name"].value) == "smoke-test-bucket-${var.test_context.name_suffix}"
    error_message = "stackit storage-bucket hub building block expected bucket_name to be 'smoke-test-bucket-${var.test_context.name_suffix}', got ${jsondecode(meshstack_building_block.this.status.outputs["bucket_name"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["bucket_url_path_style"].value), "smoke-test-bucket-${var.test_context.name_suffix}")
    error_message = "stackit storage-bucket hub building block expected bucket_url_path_style to contain bucket name, got ${jsondecode(meshstack_building_block.this.status.outputs["bucket_url_path_style"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["bucket_url_path_style"].value), "object.storage.eu01.onstackit.cloud")
    error_message = "stackit storage-bucket hub building block expected bucket_url_path_style to contain STACKIT domain, got ${jsondecode(meshstack_building_block.this.status.outputs["bucket_url_path_style"].value)}"
  }

  assert {
    condition     = length(jsondecode(meshstack_building_block.this.status.outputs["s3_access_key"].value)) > 0
    error_message = "stackit storage-bucket hub building block expected non-empty s3_access_key"
  }
}
