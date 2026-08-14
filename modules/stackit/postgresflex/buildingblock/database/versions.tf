# This module declares no `provider` block on purpose. A module that carries one is a legacy
# module, and OpenTofu rejects count, for_each and depends_on on every call to it. A composition
# that creates one database per tenant needs for_each, so the caller configures the provider and
# this module inherits it.
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    stackit = {
      source = "stackitcloud/stackit"
      # 0.110.0 is the version this module was written against. Earlier versions do not carry the
      # v3 PostgreSQL Flex schema with `flavor_id`, `network.acl` and `retention_days`.
      version = ">= 0.110.0"
    }
  }
}
