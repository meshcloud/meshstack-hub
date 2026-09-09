# meshStack sends nothing for a tag that holds no value, so every TAG input defaults to the empty
# list rather than being nullable — the test never distinguishes "unset" from "empty".

variable "project_tag" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "Values of the meshProject tag, resolved by meshStack."
}

variable "payment_method_tag" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "Values of the meshPaymentMethod tag on the project's payment method."
}

variable "landing_zone_tag" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "Values of the meshLandingZone tag on the tenant's landing zone."
}

variable "run_marker" {
  type        = number
  nullable    = false
  description = "Bumped by the test to make the provider issue an update and await a run. See resolved_tags."
}
