variable "region" {
  type        = string
  default     = "eu-de"
  nullable    = false
  description = "T Cloud Public region the bucket and its KMS key are created in."
}

variable "project_id" {
  type        = string
  nullable    = false
  description = "ID of the application project this building block is ordered on. Its name seeds the default bucket name."
}

variable "bucket_name" {
  type        = string
  default     = null
  description = "Bucket name, unique across all of T Cloud Public. Null derives one from the project name and a random suffix."

  # The access user is named after the bucket plus `-user`, and IAM user names are at most 32
  # characters long.
  validation {
    condition     = var.bucket_name == null || can(regex("^[a-z0-9][a-z0-9-]{1,25}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-27 characters of lowercase letters, digits and hyphens, starting and ending with a letter or digit."
  }
}

variable "enable_versioning" {
  type        = bool
  default     = true
  nullable    = false
  description = "Keep previous versions of overwritten and deleted objects."
}

variable "force_destroy" {
  type        = bool
  default     = false
  nullable    = false
  description = "Delete all objects with the bucket when the building block is deleted. Without it, deleting a non-empty bucket fails."
}
