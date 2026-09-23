locals {
  zone_name         = "${var.subdomain}.${var.parent_domain}"
  zone_display_name = "${var.subdomain}-zone"
}

resource "stackit_dns_zone" "this" {
  project_id    = var.stackit_project_id
  name          = local.zone_display_name
  dns_name      = local.zone_name
  contact_email = var.contact_email
  type          = "primary"
  default_ttl   = var.default_ttl
}

resource "stackit_dns_record_set" "wildcard" {
  lifecycle {
    enabled = var.wildcard_target_ip != null
  }

  project_id = var.stackit_project_id
  zone_id    = stackit_dns_zone.this.zone_id
  name       = "*.${local.zone_name}"
  type       = "A"
  records    = var.wildcard_target_ip == null ? [] : [var.wildcard_target_ip]
  comment    = "Wildcard record: every hostname in this zone resolves to the ingress load balancer."
}
