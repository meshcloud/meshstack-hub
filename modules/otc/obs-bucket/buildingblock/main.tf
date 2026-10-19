data "opentelekomcloud_identity_project_v3" "tenant" {
  id = var.project_id
}

# Bucket names are unique across all of T Cloud Public, so a derived name needs a suffix. It is
# created even for a chosen name, so that switching between the two never errors on a missing one.
resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  # Project names look like `eu-de_my-app`; bucket names allow no underscores. The prefix leaves room
  # for the suffix within the 27 characters the access user's name allows.
  name_prefix = replace(substr(replace(lower(data.opentelekomcloud_identity_project_v3.tenant.name), "/[^a-z0-9-]/", "-"), 0, 20), "/-+$/", "")
  bucket_name = coalesce(var.bucket_name, "${local.name_prefix}-${random_string.bucket_suffix.result}")
}

module "bucket" {
  source = "git::https://github.com/iits-consulting/terraform-opentelekomcloud-obs-restricted.git?ref=v7.6.2"

  bucket_name       = local.bucket_name
  enable_sse        = true
  enable_versioning = var.enable_versioning
  force_destroy     = var.force_destroy
}
