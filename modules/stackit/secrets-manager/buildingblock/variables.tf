# ── Backplane inputs (static, set once per building block definition) ──────────

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where the Secrets Manager instance will be created."
}

# ── User inputs (set per building block instance) ─────────────────────────────

variable "instance_name" {
  type        = string
  nullable    = false
  description = "Name of the Secrets Manager instance."
}
