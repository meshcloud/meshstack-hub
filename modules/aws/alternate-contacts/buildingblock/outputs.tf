output "contacts" {
  description = "Map of configured alternate contact types to their email addresses"
  value = {
    for type, contact in aws_account_alternate_contact.this : type => contact.email_address
  }
}
