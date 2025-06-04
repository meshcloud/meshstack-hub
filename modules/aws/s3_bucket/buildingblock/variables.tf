variable "region" {
  description = "The AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "tags" {
  description = "List of tags to apply to the resource"
  type        = list(string)
  default     = ["env:dev", "team:backend", "project:myapp"]
}
