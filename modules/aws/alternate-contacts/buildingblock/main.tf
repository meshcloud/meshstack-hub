resource "aws_account_alternate_contact" "operations" {
  alternate_contact_type = "OPERATIONS"

  name          = var.operations_contact.name
  title         = var.operations_contact.title
  email_address = var.operations_contact.email
  phone_number  = var.operations_contact.phone
}

resource "aws_account_alternate_contact" "billing" {
  alternate_contact_type = "BILLING"

  name          = var.billing_contact.name
  title         = var.billing_contact.title
  email_address = var.billing_contact.email
  phone_number  = var.billing_contact.phone
}

resource "aws_account_alternate_contact" "security" {
  alternate_contact_type = "SECURITY"

  name          = var.security_contact.name
  title         = var.security_contact.title
  email_address = var.security_contact.email
  phone_number  = var.security_contact.phone
}
