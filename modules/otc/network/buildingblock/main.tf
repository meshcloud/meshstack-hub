module "vpc" {
  source = "git::https://github.com/iits-consulting/terraform-opentelekomcloud-vpc.git?ref=v7.4.2"

  name       = var.name
  cidr_block = var.cidr_block
  subnets    = { (var.name) = var.subnet_cidr }
}

locals {
  subnet = module.vpc.subnets[var.name]
}

module "snat" {
  lifecycle {
    enabled = var.snat_enabled
  }

  source = "git::https://github.com/iits-consulting/terraform-opentelekomcloud-snat.git?ref=v7.4.2"

  name_prefix = var.name
  vpc_id      = module.vpc.vpc.id
  subnet_id   = local.subnet.id
}
