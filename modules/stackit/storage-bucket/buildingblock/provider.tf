# Authentication comes entirely from the environment: STACKIT_SERVICE_ACCOUNT_EMAIL,
# STACKIT_USE_OIDC and STACKIT_FEDERATED_TOKEN_FILE are injected by meshStack.
provider "stackit" {}

provider "aws" {
  access_key = var.admin_s3_access_key
  secret_key = var.admin_s3_secret_access_key
  region     = "eu01"

  endpoints {
    s3 = "https://object.storage.eu01.onstackit.cloud"
  }

  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
}
