variable "region" {
  description = "The AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "allowed_account_ids" {
  description = "List of allowed AWS account IDs to prevent operations on the wrong account"
  type        = list(string)
  default     = null
}

variable "zone_name" {
  type        = string
  description = "AWS Route53 zone name in which the record should be created."
  nullable    = false
}

variable "private_zone" {
  type        = bool
  default     = false
  description = "Set to true if the AWS Route 53 zone is a Private Hosted Zone."
}

variable "sub" {
  type        = string
  description = "DNS record name, excluding the `zone_name`. Use the value '@' to create an apex record."
  nullable    = false
}

variable "type" {
  type     = string
  nullable = false
  # unfortunately validation blocks in HCL don't support locals...
  validation {
    condition = contains([
      "A",
      "AAAA"
    ], var.type)
    error_message = "The type value must be one of ${join(", ", [for x in [
      "A",
      "AAAA",
    ] : "'${x}'"])} but was '${var.type}'."
  }
}

variable "alias_name" {
  type        = string
  description = "Alias target DNS name."
  nullable    = false
}

variable "alias_zone_id" {
  type        = string
  description = "AWS Route53 hosted zone id for the alias target. Note: These can be magic constants, see https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-route53-aliastarget.html"
  nullable    = false
}

variable "alias_evaluate_target_health" {
  type        = bool
  nullable    = false
  description = "When set to true, an alias resource record set inherits the health of the referenced AWS resource, such as an ELB load balancer or another resource record set in the hosted zone."
  default     = false
}
