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
  description = "Project Admin bindings by username."
}
