variable "url" {
  type        = string
  description = "Target of the link. Surfaced as the building block's resource URL."
}

variable "title" {
  type        = string
  description = "Human-readable name of the linked resource. Used in the generated summary."
}

variable "summary" {
  type        = string
  description = "Markdown rendered for the application team after deployment. Empty falls back to a generated one-liner pointing at the URL."
}
