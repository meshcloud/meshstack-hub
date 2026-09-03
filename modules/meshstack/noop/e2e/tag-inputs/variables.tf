variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string
  })
  nullable = false

  # No `bbd_version_ref`: this test owns the platform, landing zone, payment methods and project its
  # tenant lives on, and the invocation protocol has no way to hand it a foundation's equivalents. So
  # only build-from-source mode is supported.
}

variable "scenario" {
  type    = string
  default = "initial"

  validation {
    condition     = contains(["initial", "changed_values", "reassigned_payment_method"], var.scenario)
    error_message = "scenario must be one of initial, changed_values or reassigned_payment_method."
  }

  description = <<-EOT
  Which tag state to apply. The test file drives this from one `run` block to the next, so the three
  scenarios share state and each one is a change to the previous — which is the whole point: a tag
  input can only be seen to follow a tag if the tag changes under a building block that already exists.
  EOT
}

variable "tag_settle_duration" {
  type    = string
  default = "0s"

  description = <<-EOT
  How long to wait after writing the tags before touching the building block. meshStack starts a run
  of its own when a tag a building block reads changes, and that run competes with the one this test
  triggers: it can reach a terminal state first and have its outputs read instead, and meshStack
  rejects an update while a run is in flight. Zero on the first apply, where no building block exists
  yet to re-run.
  EOT
}
