# This building block provisions nothing. Its whole job is to turn a URL the platform team cares
# about into a first-class marketplace entry: something an application team can order, find again
# in meshPanel, and read a proper description of — rather than a link buried in a wiki.
resource "terraform_data" "link" {
  # Re-runs whenever the platform team points the building block somewhere else.
  input = var.url
}

locals {
  default_summary = chomp(<<-EOT
    # ${var.title}

    [Open ${var.title}](${var.url})
  EOT
  )
}
