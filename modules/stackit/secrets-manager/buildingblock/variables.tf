# ── Platform inputs (resolved by meshStack from the target tenant) ────────────

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID of the tenant the Secrets Manager instance is created in."
}

# ── User inputs (set per building block instance) ─────────────────────────────

variable "instance_name" {
  type        = string
  nullable    = false
  description = "Name of the Secrets Manager instance."
}

variable "imports" {
  type = object({
    instance_id = string
  })
  default     = null
  description = "Existing Secrets Manager instance this building block takes over instead of creating one. It is renamed to `instance_name` in place, and its access control list is cleared. Null creates a new instance."
}

variable "release_on_destroy" {
  type        = bool
  nullable    = false
  default     = false
  description = "Leave the instance in place when this building block is destroyed. Cannot change once the instance is managed."
}
