locals {
  contacts = {
    for type, contact in {
      "BILLING"    = var.billing_contact
      "OPERATIONS" = var.operations_contact
      "SECURITY"   = var.security_contact
    } : type => contact if contact != null
  }
}

resource "aws_account_alternate_contact" "this" {
  for_each = local.contacts

  alternate_contact_type = each.key

  name          = each.value.name
  title         = each.value.title
  email_address = each.value.email
  phone_number  = each.value.phone
}
