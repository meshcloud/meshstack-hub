# ─────────────────────────────────────────────────────────────────────────────
# DNS: one shared zone, one label per cluster
#
# This file holds the whole DNS design of the architecture, together with the inputs that drive it.
# Everything the cluster and the ingress controller know about DNS comes from the locals below, so
# the design can be replaced here without touching the rest of the composition.
#
# The platform team owns one zone, for example `likvid.stackit.run`, in its own STACKIT project.
# This building block never creates that zone. It is a free STACKIT subdomain, and such a subdomain
# admits exactly one label: the API rejects `cluster1.likvid.stackit.run` as a zone with
# *"subdomain should only have one level"*, in every project and even with a correct NS delegation
# already in place. A subzone per cluster is therefore impossible.
#
# A record set with that depth inside the existing zone is allowed, and that is what each cluster
# gets:
#
#   1. The cluster writes the record set `*.<cluster_name>` into the shared zone, pointing at its
#      own HAProxy load balancer. Every application hostname below
#      `<app>.<cluster_name>.likvid.stackit.run` resolves to that address.
#   2. cert-manager solves the ACME DNS-01 challenge against the shared zone and issues one wildcard
#      certificate for `*.<cluster_name>.likvid.stackit.run`, which HAProxy serves for every
#      application on the cluster.
#
# `cluster_name` is the single identifier behind all of this: it names the SKE cluster, the
# meshStack platform and the DNS label, and it is validated to 11 lowercase characters.
#
# ── The credential is zone-wide, the label is not a permission boundary ──────
#
# The DNS-01 solver authenticates with a STACKIT service account key that carries `dns.admin` on the
# zone's project. That role cannot be narrowed to one zone, let alone to one label, so a cluster
# could write records outside its own label. This composition is what keeps each cluster inside its
# label — the permission system does not enforce it. Treat the key as a credential for the whole
# domain and hand it only to clusters you trust with it.
#
# ── No ExternalDNS ───────────────────────────────────────────────────────────
#
# The SKE managed ExternalDNS extension writes only into zones of the cluster's own STACKIT project,
# and the shared zone lives in the platform team's project. The wildcard record makes the extension
# unnecessary anyway: every hostname below the cluster's label already resolves, so an application
# team adds an Ingress and needs no record of its own.
# ─────────────────────────────────────────────────────────────────────────────

variable "dns_parent_zone_name" {
  type        = string
  nullable    = false
  default     = ""
  description = "DNS zone the platform team owns and every cluster shares, for example `likvid.stackit.run`. The cluster adds the record set `*.<cluster_name>` to it and never creates a zone. Leave empty to run without DNS, in which case cert-manager issues per-hostname certificates over HTTP-01. See dns.tf."
}

variable "dns_zone_project_id" {
  type        = string
  nullable    = false
  default     = ""
  description = "STACKIT project UUID that owns `dns_parent_zone_name`, which is usually the platform team's own project. Leave empty when the zone lives in the tenant's own STACKIT project. See dns.tf."
}

variable "dns_cluster_label_enabled" {
  type     = bool
  nullable = false
  default  = true

  description = <<-EOT
  Give the cluster its own label inside the shared zone, so its hostnames are
  `<app>.<cluster_name>.<dns_parent_zone_name>` and its certificate covers
  `*.<cluster_name>.<dns_parent_zone_name>`.

  Set it to `false` to put the cluster's wildcard at the zone apex instead, which gives the flat
  hostnames `<app>.<dns_parent_zone_name>`. Only one cluster per zone can hold the apex, so every
  further cluster ordered into the same zone needs a label of its own. Moving a cluster from the
  apex to a label renames every hostname it serves. See dns.tf.
  EOT
}

variable "dns_service_account_key" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "STACKIT service account key JSON that the cert-manager DNS-01 solver authenticates with. It needs `dns.admin` on the project that owns the shared zone, and it can write every record in that zone. Required for the wildcard certificate. See dns.tf."
}

locals {
  # An empty zone name means the architecture runs without DNS: no wildcard record, no wildcard
  # certificate, and cert-manager falls back to per-hostname HTTP-01 issuance. With `expose = none`
  # there is no load balancer to point a record at either.
  dns_enabled = var.dns_parent_zone_name != "" && var.expose != "none"

  dns_zone_project_id = var.dns_zone_project_id != "" ? var.dns_zone_project_id : var.stackit_project_id

  dns_cluster_label = local.dns_enabled && var.dns_cluster_label_enabled ? var.cluster_name : null

  # Domain the cluster's application hostnames live under, and the domain its wildcard certificate
  # covers. The shared zone itself when the cluster sits at the apex.
  dns_apps_domain = !local.dns_enabled ? null : (
    local.dns_cluster_label == null
    ? var.dns_parent_zone_name
    : "${local.dns_cluster_label}.${var.dns_parent_zone_name}"
  )

  # The SKE managed ExternalDNS extension stays off. It reaches only zones in the cluster's own
  # STACKIT project, and the shared zone lives in the platform team's project.
  ske_dns_extension = null

  # cert-manager solves the challenge against the whole shared zone, because that is what the
  # service account key is authorised for, and issues a certificate for the cluster's domain alone.
  # The `dnsZones` selector of the solver matches every name below the zone, so it also answers for
  # the narrower certificate.
  ingress_dns01 = local.dns_enabled && var.dns_service_account_key != "" ? {
    zone_name          = var.dns_parent_zone_name
    certificate_domain = local.dns_apps_domain
    stackit = {
      project_id          = local.dns_zone_project_id
      service_account_key = var.dns_service_account_key
    }
  } : null
}

# Writes the cluster's wildcard record into the shared zone. The module is called with
# `zone_name = null` while DNS is off, because it configures its own STACKIT provider and Terraform
# refuses `count` on such a module. With a null zone name it creates and reads nothing.
module "dns" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/dns/buildingblock?ref=${var.hub.git_ref}"

  project_id            = local.dns_zone_project_id
  service_account_email = var.stackit_service_account_email
  stackit_region        = var.stackit_region

  # The platform team owns the zone. This building block only adds record sets to it.
  zone_name   = local.dns_enabled ? var.dns_parent_zone_name : null
  create_zone = false

  # The runtime credential is a static input of the composition, so the cluster creates no service
  # account of its own in the platform team's project.
  dns_service_account_enabled = false

  wildcard = local.dns_enabled ? {
    label   = local.dns_cluster_label
    address = one(module.ingress[*].haproxy_lb_ip)
  } : null
}
