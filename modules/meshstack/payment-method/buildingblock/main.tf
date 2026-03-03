resource "meshstack_payment_method" "payment_method" {
  lifecycle {
    precondition {
      condition = var.approval == true
      error_message = "Your payment method request was rejected."
    }
  }
  # count = var.approval ? 1 : 0
  metadata = {
    name               = var.payment_method_name
    owned_by_workspace = var.workspace_id
  }
  spec = {
    display_name    = var.payment_method_name
    amount          = var.amount
    expiration_date = var.expiration_date
    tags            = var.tags
  }
}