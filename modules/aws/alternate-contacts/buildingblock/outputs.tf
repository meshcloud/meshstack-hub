output "operations_contacts" {
  description = "Map of configured alternate contact types to their email addresses"
  value = {
    for type, contact in {
      operations = aws_account_alternate_contact.operations
      billing    = aws_account_alternate_contact.billing
      security   = aws_account_alternate_contact.security
    } : type => contact.email_address if contact != null
  }
}
