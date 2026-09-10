variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    run_id      = string
  })
  nullable = false
}
