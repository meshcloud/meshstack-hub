provider "stackit" {
  service_account_email = var.service_account_email
  use_oidc              = true
}

provider "aws" {
  access_key = var.admin_s3_access_key
  secret_key = var.admin_s3_secret_access_key
  # us-east-1 causes AWS SDK Go v1 (provider ~> 4.0) to omit LocationConstraint in CreateBucket,
  # which is what STACKIT StorageGRID requires (it rejects any LocationConstraint value).
  region = "us-east-1"

  endpoints {
    s3 = "https://object.storage.eu01.onstackit.cloud"
  }

  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
}
