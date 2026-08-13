# The tenant's bucket, its own Object Storage credentials group and the credential inside that group.
# `modules/stackit/storage-bucket/buildingblock/bucket` is provider-free for the same reason the
# Postgres submodule is, and it needs both providers this module configures: the `stackit` provider
# for the credentials group and the credential, and the `aws` provider for the bucket and its policy.
#
# The bucket is created with the `aws` provider used as a generic S3 client, because the stackit
# provider has no permission to create one. That is a property of the submodule, not a choice made
# here, and it is the reason this module configures an `aws` provider at all.
#
# The credential the tenant's Langfuse instance uses comes out of this call rather than in as an
# input. The bucket policy the submodule writes denies every principal outside the tenant's own
# credentials group and the administrative group, so the credential Langfuse receives reaches this
# bucket and no other tenant's.
module "bucket" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/storage-bucket/buildingblock/bucket?ref=${var.hub.git_ref}"

  project_id  = var.stackit_project_id
  bucket_name = local.langfuse_bucket

  admin_credentials_group_urn = var.stackit_s3_admin_credentials_group_urn
}
