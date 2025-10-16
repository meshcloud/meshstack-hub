run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "verify" {
  variables {
    bucket_name = "test-s3-bucket-bb-${run.setup.random_suffix}"
    tags        = ["env:test", "team:platform"]
  }

  assert {
    condition     = aws_s3_bucket.main.bucket == var.bucket_name
    error_message = "did not produce the correct bucket name"
  }

  assert {
    condition     = aws_s3_bucket.main.tags["env"] == "test"
    error_message = "incorrect tag value for 'env'"
  }

  assert {
    condition     = aws_s3_bucket.main.tags["team"] == "platform"
    error_message = "incorrect tag value for 'team'"
  }
}
