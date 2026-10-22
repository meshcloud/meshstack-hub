variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the objects in place on destroy."
}

variable "name" {
  type        = string
  nullable    = false
  description = "Name of the ServiceAccount, its ClusterRole and its ClusterRoleBinding, and prefix of its token Secrets."
}

variable "namespace" {
  type     = string
  nullable = false
}

variable "annotations" {
  type     = map(string)
  nullable = false
}

variable "rules" {
  type = list(object({
    api_groups        = list(string)
    resources         = list(string)
    verbs             = list(string)
    resource_names    = optional(list(string))
    non_resource_urls = optional(list(string))
  }))
  nullable = false
}

variable "token_generations" {
  type        = set(string)
  nullable    = false
  description = "Generations to keep a token Secret for."
}

variable "current_token_generation" {
  type        = string
  nullable    = false
  description = "Generation of the token the module returns."
}
