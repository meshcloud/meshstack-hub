output "bucket_name" {
  value       = module.bucket.bucket_name
  description = "Name of the bucket."
}

output "obs_endpoint" {
  value       = "https://obs.${var.region}.otc.t-systems.com"
  description = "S3-compatible endpoint to reach the bucket at."
}

output "access_key" {
  value       = module.bucket.bucket_access_key
  sensitive   = true
  description = "Access key of the user that may only use this bucket and its KMS key."
}

output "secret_key" {
  value       = module.bucket.bucket_secret_key
  sensitive   = true
  description = "Secret key belonging to `access_key`."
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # OBS bucket

    The bucket `${module.bucket.bucket_name}` is ready at `https://obs.${var.region}.otc.t-systems.com`.
    It is private, encrypted with its own KMS key${var.enable_versioning ? ", and keeps previous object versions" : ""}.

    ## Access

    The outputs **Access Key** and **Secret Key** belong to a user that may use only this bucket and
    its key. Give them to your application as its S3 credentials, together with the endpoint above.
    With the AWS CLI, for example:

    ```
    aws s3 ls s3://${module.bucket.bucket_name} --endpoint-url https://obs.${var.region}.otc.t-systems.com
    ```

    The members of the project open the bucket in the [OBS console](https://console.otc.t-systems.com/obs/)
    after their next sign-in: ${join(", ", [for role, access in var.group_access : "${role}s ${access == "write" ? "read and write" : "read"}"])} its objects.

    ${var.force_destroy ? "Deleting this building block deletes the bucket **with all its objects**." : "Empty the bucket before deleting this building block; a bucket with objects in it is kept."}
  EOT
}
