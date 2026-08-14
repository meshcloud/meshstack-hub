output "bucket_name" {
  value       = module.bucket.bucket_name
  description = "Name of the created Object Storage bucket."
}

output "region" {
  value       = module.bucket.region
  description = "STACKIT region the bucket lives in. S3 clients that require a region, among them the AWS SDK and the Langfuse S3 configuration, take this value."
}

output "endpoint" {
  value       = module.bucket.endpoint
  description = "Base URL of the STACKIT Object Storage S3 endpoint, without the bucket name. Use this for S3 clients that take an endpoint and a bucket separately."
}

output "bucket_url_path_style" {
  value       = module.bucket.bucket_url_path_style
  description = "Path-style URL of the bucket."
}

output "bucket_url_virtual_hosted_style" {
  value       = module.bucket.bucket_url_virtual_hosted_style
  description = "Virtual-hosted-style URL of the bucket."
}

output "s3_access_key" {
  value       = module.bucket.s3_access_key
  description = "S3-compatible access key for the bucket."
}

output "s3_secret_access_key" {
  value       = module.bucket.s3_secret_access_key
  description = "S3-compatible secret access key for the bucket."
  sensitive   = true
}

output "credentials_group_urn" {
  value       = module.bucket.credentials_group_urn
  description = "URN of the credentials group the bucket policy grants read and write access to. The access key belongs to this group."
}

output "summary" {
  value       = module.bucket.summary
  description = "Summary with bucket details and access credentials."
  sensitive   = true
}
