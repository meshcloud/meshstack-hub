variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "location" {
  description = "The GCP location/region"
  type        = string
  default     = "europe-west1"
}

variable "bucket_name" {
  description = "The name of the storage bucket"
  type        = string
}

variable "labels" {
  description = "List of labels to apply to the resource"
  type        = list(string)
  default     = ["env:dev", "team:backend", "project:myapp"]
}
