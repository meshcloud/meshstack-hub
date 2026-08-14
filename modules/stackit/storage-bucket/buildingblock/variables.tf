# ── Backplane inputs (static, set once per building block definition) ──────────

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the bucket will be created."
}

variable "service_account_email" {
  type        = string
  nullable    = false
  description = "Email of the STACKIT service account for WIF-based authentication."
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
  description = "Name of the Object Storage bucket. Must be DNS-conformant: 3 to 63 characters, lowercase letters, digits, hyphens and dots, starting and ending with a letter or a digit. The credentials group created for the bucket carries the same name, so the name must be unique within the project. `./bucket` validates the value."
}
