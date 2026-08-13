# The bucket, its credentials group and its bucket policy live in `./bucket`, a module that declares
# no provider configuration. This root supplies the two providers `./bucket` needs and is what
# meshStack runs when an application team orders the building block.
#
# A composition that creates one bucket per tenant sources `./bucket` instead, configures the
# `stackit` and the `aws` provider itself and calls the module with for_each. It cannot call this
# root that way, because a module carrying its own provider configuration is a legacy module and
# OpenTofu rejects count, for_each and depends_on on every call to it.
module "bucket" {
  source = "./bucket"

  project_id                  = var.project_id
  bucket_name                 = var.bucket_name
  admin_credentials_group_urn = var.admin_credentials_group_urn
}
