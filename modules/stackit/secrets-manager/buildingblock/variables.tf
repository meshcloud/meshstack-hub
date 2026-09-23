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
