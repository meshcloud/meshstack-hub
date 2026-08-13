variables {
  project_id                  = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_account_email       = "mesh-storage-bucket@sa.stackit.cloud"
  admin_s3_access_key         = "AKIAEXAMPLEKEY"
  admin_s3_secret_access_key  = "examplesecret"
  admin_credentials_group_urn = "urn:sgws:identity::12345678901234567890:group/abcdef01-2345-6789-abcd-ef0123456789"
  bucket_name                 = "smoke-test-bucket-1234"
}

mock_provider "stackit" {
  mock_resource "stackit_objectstorage_credentials_group" {
    defaults = {
      credentials_group_id = "11111111-2222-3333-4444-555555555555"
      urn                  = "urn:sgws:identity::12345678901234567890:group/11111111-2222-3333-4444-555555555555"
    }
  }
  mock_resource "stackit_objectstorage_credential" {
    defaults = {
      access_key        = "AKIAMOCKACCESSKEY"
      secret_access_key = "mock-secret-access-key"
    }
  }
}

mock_provider "aws" {}

run "ordered_path_still_returns_every_output" {
  command = plan

  assert {
    condition     = output.bucket_name == "smoke-test-bucket-1234"
    error_message = "bucket_name must pass through"
  }
  assert {
    condition     = output.region == "eu01"
    error_message = "region must pass through"
  }
  assert {
    condition     = output.endpoint == "https://object.storage.eu01.onstackit.cloud"
    error_message = "endpoint must pass through"
  }
  assert {
    condition     = output.bucket_url_path_style == "https://object.storage.eu01.onstackit.cloud/smoke-test-bucket-1234"
    error_message = "path-style URL must pass through"
  }
  assert {
    condition     = output.bucket_url_virtual_hosted_style == "https://smoke-test-bucket-1234.object.storage.eu01.onstackit.cloud"
    error_message = "virtual-hosted URL must pass through"
  }
  assert {
    condition     = output.s3_access_key == "AKIAMOCKACCESSKEY"
    error_message = "access key must pass through"
  }
  assert {
    condition     = output.s3_secret_access_key == "mock-secret-access-key"
    error_message = "secret access key must pass through"
  }
  assert {
    condition     = output.credentials_group_urn == "urn:sgws:identity::12345678901234567890:group/11111111-2222-3333-4444-555555555555"
    error_message = "credentials group URN must pass through"
  }
  assert {
    condition     = strcontains(output.summary, "smoke-test-bucket-1234")
    error_message = "summary must pass through"
  }
}
