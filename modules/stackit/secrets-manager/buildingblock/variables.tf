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
  description = "Existing Secrets Manager instance to take over, renamed to `instance_name` and with its access control list cleared; null creates one."
}

variable "release_on_destroy" {
  type        = bool
  nullable    = false
  default     = false
  description = "Leave the instance in place on destroy. Cannot change once the instance is managed."
}
