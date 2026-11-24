# The splats keep a null contact readable for tflint, which evaluates a disabled resource too.
resource "aws_account_alternate_contact" "operations" {
  lifecycle {
    enabled = var.operations_contact != null
  }

  alternate_contact_type = "OPERATIONS"

  name          = one(var.operations_contact[*].name)
  title         = one(var.operations_contact[*].title)
  email_address = one(var.operations_contact[*].email)
  phone_number  = one(var.operations_contact[*].phone)
}

resource "aws_account_alternate_contact" "billing" {
  lifecycle {
    enabled = var.billing_contact != null
  }

  alternate_contact_type = "BILLING"

  name          = one(var.billing_contact[*].name)
  title         = one(var.billing_contact[*].title)
  email_address = one(var.billing_contact[*].email)
  phone_number  = one(var.billing_contact[*].phone)
}

resource "aws_account_alternate_contact" "security" {
  lifecycle {
    enabled = var.security_contact != null
  }

  alternate_contact_type = "SECURITY"

  name          = one(var.security_contact[*].name)
  title         = one(var.security_contact[*].title)
  email_address = one(var.security_contact[*].email)
  phone_number  = one(var.security_contact[*].phone)
}
