variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string
    meshstack = object({
      tag_schema = object({
        mandatory = object({
          payment_method = map(list(string))
        })
      })
    })
  })
  nullable = false

  # Hub mode only, hence no `bbd_version_ref`: this test owns the platform, landing zone, payment
  # methods and project its tenant lives on, because retagging them is the thing under test. A
  # foundation's equivalents are not ours to retag.
}

variable "scenario" {
  type    = string
  default = "initial"

  validation {
    condition = contains(["initial", "changed_values", "reassigned_payment_method"], var.scenario)
    # OpenTofu requires this argument, so it cannot be dropped in favour of the condition alone.
    error_message = "Unknown scenario."
  }

  description = <<-EOT
  Which tag state to apply. The test file drives this from one `run` block to the next, so the three
  scenarios share state and each one is a change to the previous — which is the whole point: a tag
  input can only be seen to follow a tag if the tag changes under a building block that already exists.
  EOT
}

variable "tag_settle_duration" {
  type     = string
  nullable = false

  description = <<-EOT
  How long to wait after writing the tags before touching the building block. meshStack starts a run
  of its own when a tag a building block reads changes, and that run competes with the one this test
  triggers: it can reach a terminal state first and have its outputs read instead, and meshStack
  rejects an update while a run is in flight. Set `"0s"` where no building block exists yet to re-run.
  EOT
}
