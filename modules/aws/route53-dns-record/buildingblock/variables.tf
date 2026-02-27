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
}

variable "private_zone" {
  type        = bool
  default     = false
  description = "Set to true if the AWS Route 53 zone is a Private Hosted Zone."
}

variable "sub" {
  type        = string
  description = "DNS record name, excluding the `zone_name`. Leave empty to create apex records."
  nullable    = false

  # note: "CNAME records are illegal at apex, value must be a non-empty string."
  # terraform can't validate this right now

}

# Legal DNS record types. Consider shortening this list if you want to constain allowed records
# (e.g. SOA, NS) as they allow sub-delegation of DNS zones
# See https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ResourceRecordTypes.html
variable "type" {
  type        = string
  description = "DNS Record type"

  # unfortunately validation blocks in HCL don't support locals so we have to copy/paste literals here
  validation {
    condition = contains([
      "A",
      "AAAA",
      # "CAA",
      "CNAME",
      # "DS",
      "MX",
      # "NAPTR",
      # "NS",
      # "PTR",
      # "SOA",
      "SPF",
      "SRV",
      "TXT",
    ], var.type)
    error_message = "The type value must be one of ${join(", ", [for x in [
      "A",
      "AAAA",
      # "CAA",
      "CNAME",
      # "DS",
      "MX",
      # "NAPTR",
      # "NS",
      # "PTR",
      # "SOA",
      "SPF",
      "SRV",
      "TXT",
    ] : "'${x}'"])} but was '${var.type}'."
  }
}

variable "record" {
  type        = string
  description = "DNS record value"
  nullable    = false
}

variable "ttl" {
  type        = string
  default     = "300"
  description = "TTL of the record in seconds."
  validation {
    condition     = parseint(var.ttl, 10) > 0
    error_message = "The ttl value must be larger than 0 but was ${var.ttl}."
  }
}
