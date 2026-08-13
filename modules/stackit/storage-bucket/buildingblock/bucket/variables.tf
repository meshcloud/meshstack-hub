variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID the bucket and its credentials group are created in."
}

variable "bucket_name" {
  type        = string
  nullable    = false
  description = "Name of the Object Storage bucket. Must be DNS-conformant. The credentials group created for the bucket carries the same name, so the name must be unique within the project."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, start and end with a lowercase letter or digit, and contain only lowercase letters, digits, hyphens, and dots."
  }
}

variable "admin_credentials_group_urn" {
  type        = string
  nullable    = false
  description = "URN of the admin credentials group the bucket policy keeps access for (e.g. urn:sgws:identity::<account_id>:group/<group_id>). The S3 credentials the `aws` provider is configured with must belong to this group, otherwise the policy locks the module out of the bucket it just created."
}
