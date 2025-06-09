# AWS Account Region resource to enable/disable opt-in regions
resource "aws_account_region" "region" {
  account_id  = var.account_id
  region_name = var.region_name
  enabled     = var.enabled
}
