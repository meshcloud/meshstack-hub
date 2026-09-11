resource "stackit_dns_zone" "this" {
  project_id    = local.stackit_project_id
  name          = "${var.dns_name}-ske-starterkit"
  dns_name      = "${var.dns_name}.stackit.run"
  contact_email = var.dns_contact_email
  type          = "primary"
  default_ttl   = 300
}

# Wildcard record so every application hostname under the zone resolves to the ingress load balancer.
resource "stackit_dns_record_set" "wildcard_a" {
  project_id = local.stackit_project_id
  zone_id    = stackit_dns_zone.this.zone_id
  name       = "*.${var.dns_name}.stackit.run"
  type       = "A"
  records    = [local.haproxy_lb_ip]
  comment    = "Wildcard app routing to HAProxy ingress load balancer"
}
