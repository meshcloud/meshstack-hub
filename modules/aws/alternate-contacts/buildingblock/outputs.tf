output "operations_contacts" {
  description = "Map of configured alternate contact types to their email addresses"
  value = {
    "operations" = aws_account_alternate_contact.operations.email_address
    "billing"    = aws_account_alternate_contact.billing.email_address
    "security"   = aws_account_alternate_contact.security.email_address
  }
}
