# wave 0 — no dependencies on other hub modules
variable "hub" {
  type = object({
    git_ref = string
  })
}
