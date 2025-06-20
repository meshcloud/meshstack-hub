variable "aws_s3_iam_user" {
  description = "The IAM user to use for the S3 bucket"
  default     = "buildingblock-s3-user"
  type        = string
}

variable "location" {
  description = "The location of the S3 bucket"
  type        = string
}
