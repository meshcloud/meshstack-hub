variable "project" {
  type = object({
    name               = string
    owned_by_workspace = string
  })
  nullable = false
}

variable "bindings" {
  type = map(object({
    name               = string
    release_on_destroy = bool
  }))
  nullable    = false
  description = "Project Admin bindings by username. With `release_on_destroy`, a binding is left in place when it is destroyed, and only dropped from the state."
}
