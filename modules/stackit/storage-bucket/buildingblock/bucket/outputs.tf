locals {
  # STACKIT serves Object Storage from one endpoint per region. The region is fixed to eu01 here,
  # the same value the caller configures for the S3 provider.
  region   = "eu01"
  endpoint = "https://object.storage.${local.region}.onstackit.cloud"
}

output "bucket_name" {
  value       = aws_s3_bucket.this.bucket
  description = "Name of the created Object Storage bucket."
}

output "region" {
  value       = local.region
  description = "STACKIT region the bucket lives in. S3 clients that require a region, among them the AWS SDK and the Langfuse S3 configuration, take this value."
}

output "endpoint" {
  value       = local.endpoint
  description = "Base URL of the STACKIT Object Storage S3 endpoint, without the bucket name. Use this for S3 clients that take an endpoint and a bucket separately."
}

output "bucket_url_path_style" {
  value       = "${local.endpoint}/${aws_s3_bucket.this.bucket}"
  description = "Path-style URL of the bucket."
}

output "bucket_url_virtual_hosted_style" {
  value       = "https://${aws_s3_bucket.this.bucket}.object.storage.${local.region}.onstackit.cloud"
  description = "Virtual-hosted-style URL of the bucket."
}

output "s3_access_key" {
  value       = stackit_objectstorage_credential.this.access_key
  description = "S3-compatible access key for the bucket."
}

output "s3_secret_access_key" {
  value       = stackit_objectstorage_credential.this.secret_access_key
  description = "S3-compatible secret access key for the bucket."
  sensitive   = true
}

output "credentials_group_urn" {
  value       = stackit_objectstorage_credentials_group.this.urn
  description = "URN of the credentials group the bucket policy grants read and write access to. The access key belongs to this group."
}

output "summary" {
  description = "Summary with bucket details and access credentials."
  sensitive   = true
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    bucket_name               = aws_s3_bucket.this.bucket
    endpoint                  = local.endpoint
    region                    = local.region
    bucket_url_path_style     = "${local.endpoint}/${aws_s3_bucket.this.bucket}"
    bucket_url_virtual_hosted = "https://${aws_s3_bucket.this.bucket}.object.storage.${local.region}.onstackit.cloud"
    access_key                = stackit_objectstorage_credential.this.access_key
    secret_access_key         = stackit_objectstorage_credential.this.secret_access_key
  })
}
