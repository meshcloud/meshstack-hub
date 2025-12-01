resource "meshstack_payment_method" "payment_method" {
  metadata = {
    name = var.payment_method_name
    owned_by_workspace = var.workspace_id 
  }
  spec = {
    display_name = var.payment_method_name
    amount       = var.amount
    expiration_date = var.expiration_date
    tags = var.tags
  }
}
