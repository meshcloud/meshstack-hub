provider "stackit" {
  service_account_email = var.service_account_email
  use_oidc              = true
}

provider "aws" {
  access_key = var.admin_s3_access_key
  secret_key = var.admin_s3_secret_access_key
  # STACKIT StorageGRID requires LocationConstraint="eu01" in CreateBucket; AWS provider v5+ sends the
  # region as LocationConstraint. skip_region_validation lets us use "eu01" (not a real AWS region).
  region = "eu01"

  endpoints {
    s3 = "https://object.storage.eu01.onstackit.cloud"
  }

  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  s3_use_path_style           = true
}
