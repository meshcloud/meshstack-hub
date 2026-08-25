run "building_block_aws_s3_bucket_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "aws s3_bucket hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["bucket_name"].value) == "smoke-test-aws-bucket-${var.test_context.name_suffix}"
    error_message = "aws s3_bucket hub building block expected bucket_name to be 'smoke-test-aws-bucket-${var.test_context.name_suffix}', got ${jsondecode(meshstack_building_block.this.status.outputs["bucket_name"].value)}"
  }

  # The ARN is what proves the bucket was created by the federated backplane role rather than the
  # bucket name simply being echoed back.
  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["bucket_arn"].value) == "arn:aws:s3:::smoke-test-aws-bucket-${var.test_context.name_suffix}"
    error_message = "aws s3_bucket hub building block expected bucket_arn to be 'arn:aws:s3:::smoke-test-aws-bucket-${var.test_context.name_suffix}', got ${jsondecode(meshstack_building_block.this.status.outputs["bucket_arn"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["bucket_uri"].value) == "s3://smoke-test-aws-bucket-${var.test_context.name_suffix}"
    error_message = "aws s3_bucket hub building block expected bucket_uri to be the s3:// URI, got ${jsondecode(meshstack_building_block.this.status.outputs["bucket_uri"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["bucket_regional_domain_name"].value), var.test_context.fixtures.aws.region)
    error_message = "aws s3_bucket hub building block expected bucket_regional_domain_name to name the fixture region, got ${jsondecode(meshstack_building_block.this.status.outputs["bucket_regional_domain_name"].value)}"
  }
}
