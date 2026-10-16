locals {
  zone_name         = "${var.subdomain}.${var.parent_domain}"
  zone_display_name = "${var.subdomain}-zone"
}

module "zone" {
  source = "./modules/zone"

  release_on_destroy = var.release_on_destroy
  project_id         = var.stackit_project_id
  name               = local.zone_display_name
  dns_name           = local.zone_name
  contact_email      = var.contact_email
  default_ttl        = var.default_ttl
}

moved {
  from = stackit_dns_zone.this
  to   = module.zone.stackit_dns_zone.this
}

import {
  for_each = var.imports != null && !var.release_on_destroy ? toset([var.imports.zone_id]) : toset([])
  to       = module.zone.stackit_dns_zone.this
  id       = "${var.stackit_project_id},${each.value}"
}

import {
  for_each = var.imports != null && var.release_on_destroy ? toset([var.imports.zone_id]) : toset([])
  to       = module.zone.stackit_dns_zone.released
  id       = "${var.stackit_project_id},${each.value}"
}

module "wildcard" {
  source = "./modules/record-set"

  lifecycle {
    enabled = var.wildcard_target_ip != null
  }

  release_on_destroy = var.release_on_destroy
  project_id         = var.stackit_project_id
  zone_id            = module.zone.zone.zone_id
  name               = "*.${local.zone_name}"
  records            = var.wildcard_target_ip == null ? [] : [var.wildcard_target_ip]
  comment            = "Wildcard record: every hostname in this zone resolves to the ingress load balancer."
}

moved {
  from = stackit_dns_record_set.wildcard
  to   = module.wildcard.stackit_dns_record_set.this
}

import {
  for_each = var.imports != null && !var.release_on_destroy ? toset([var.imports.record_set_id]) : toset([])
  to       = module.wildcard.stackit_dns_record_set.this
  id       = "${var.stackit_project_id},${var.imports.zone_id},${each.value}"
}

import {
  for_each = var.imports != null && var.release_on_destroy ? toset([var.imports.record_set_id]) : toset([])
  to       = module.wildcard.stackit_dns_record_set.released
  id       = "${var.stackit_project_id},${var.imports.zone_id},${each.value}"
}
