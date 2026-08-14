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
