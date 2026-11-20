variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project whose DNS zones the solver writes challenge records into."
}

variable "cert_manager_namespace" {
  type        = string
  nullable    = false
  description = "Namespace cert-manager runs in. The webhook and its key secret go there."
}


variable "zone_name" {
  type        = string
  nullable    = false
  description = "DNS name of the zone. Destroy cleans up only the Challenges for names in it."
}
