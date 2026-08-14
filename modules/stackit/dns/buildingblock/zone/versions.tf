# This module declares no `provider` block on purpose. A module that carries one is a legacy
# module, and OpenTofu rejects count, for_each and depends_on on every call to it. It also fixes
# how the module authenticates: the root above configures `use_oidc = true` for the workload
# identity federation meshStack runs it with, and a caller that holds a service account key instead
# cannot override a provider its child module configures itself.
#
# Both callers exist. The `stackit-landingzone` reference architecture creates the shared zone under
# `count` and authenticates with a service account key, so it configures the provider itself and
# this module inherits it.
terraform {
  # 1.11.0, not the repo baseline of 1.12.0, because the tier above this one sources it and declares
  # the same floor, and the building block definition tells the meshStack runner to use 1.11.0. A
  # higher floor here would fail at run time. The sibling submodules `storage-bucket/.../bucket` and
  # `postgresflex/.../database` say 1.11.0 for the same reason.
  required_version = ">= 1.11.0"

  required_providers {
    stackit = {
      source = "stackitcloud/stackit"
      # 0.110.0 is the version this module was written against. It carries the DNS zone data source
      # with lookup by `dns_name` and the `iam` experiment that gates
      # `stackit_authorization_project_role_assignment`.
      version = ">= 0.110.0"
    }
  }
}
