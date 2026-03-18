# ── Backplane inputs (static, set once per building block definition) ──────────

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the bucket will be created."
}

variable "service_account_key_json" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Service account key JSON for authenticating the STACKIT provider."
}

variable "admin_s3_access_key" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "S3 access key for the admin credentials group used to apply bucket policies."
}

variable "admin_s3_secret_access_key" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "S3 secret access key for the admin credentials group used to apply bucket policies."
}

variable "admin_credentials_group_urn" {
  type        = string
  nullable    = false
  description = "URN of the admin credentials group used to apply bucket policies (e.g. urn:sgws:identity::<account_id>:group/<group_id>)."
}

# ── User inputs (set per building block instance) ─────────────────────────────

variable "bucket_name" {
  type        = string
  nullable    = false
  description = "Name of the Object Storage bucket. Must be DNS-conformant."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, start and end with a lowercase letter or digit, and contain only lowercase letters, digits, hyphens, and dots."
  }
}
