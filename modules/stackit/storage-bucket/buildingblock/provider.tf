provider "stackit" {
  service_account_key = var.service_account_key_json
}

provider "aws" {
  access_key = var.admin_s3_access_key
  secret_key = var.admin_s3_secret_access_key
  # Not actually relevant
  region = "us-east-1"

  endpoints {
    s3 = "https://object.storage.eu01.onstackit.cloud"
  }

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
}
