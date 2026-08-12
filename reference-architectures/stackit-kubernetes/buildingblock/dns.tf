# ─────────────────────────────────────────────────────────────────────────────
# Delegated DNS subzone
#
# This file holds the whole DNS design of the architecture. Everything the cluster and the ingress
# controller know about DNS comes from the two locals at the bottom, so the design can be replaced
# here without touching the rest of the composition.
#
# The landing zone owns one parent zone, for example `likvid.stackit.run`, in the platform team's
# own STACKIT project. This building block never creates that zone. Each ordered cluster instead
# gets a delegated subzone named after the cluster, for example `cluster1.likvid.stackit.run`, and
# that subzone lives in the tenant's own STACKIT project. Four steps make the delegation work:
#
#   1. An NS record for the cluster's label is created in the parent zone, pointing at
#      `ns1.stackit.cloud` and `ns2.stackit.zone`.
#   2. A zone with the delegated name is created in the tenant's STACKIT project.
#   3. The SKE managed ExternalDNS extension is enabled on the cluster with the delegated name as
#      its zone filter, so the control plane writes the records instead of Terraform.
#   4. The cert-manager DNS-01 solver receives a STACKIT service account key scoped to the tenant's
#      own project, so no cross-project credential exists anywhere.
#
# The shape follows from STACKIT DNS being project-scoped end to end: `stackit_dns_record_set`
# carries its own `project_id` and that project must own the `zone_id`, and the SKE
# `extensions.dns` block has no field for a foreign project or a foreign credential.
#
# ── UNVERIFIED ASSUMPTION ────────────────────────────────────────────────────
#
# STACKIT documents free `stackit.run` subdomains as one label deep, and it separately documents
# creating a subzone in a different project through NS delegation. Whether delegation bypasses the
# one-label rule *under `stackit.run`* is not confirmed. It is being tested separately. If it turns
# out that it does not, the fallback is a platform-owned zone: the parent zone stays in the platform
# team's project, each cluster gets records in it rather than a subzone of its own, and the DNS-01
# credential becomes a cross-project one. That fallback changes this file and nothing else.
#
# ── GAP: steps 1 and 2 are not implemented ───────────────────────────────────
#
# A reference architecture composes hub modules and never declares cloud provider resources
# directly, and the hub has no STACKIT DNS module today. `modules/stackit/dns` is a required new
# module. It has to create the delegated zone in the tenant's project, the NS record in the parent
# zone, and the service account key the DNS-01 solver uses. Until that module exists, a platform
# team that wants the wildcard certificate creates the zone and the key by hand and passes the key
# in through `dns_service_account_key`.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # Empty parent zone means the architecture runs without DNS: no ExternalDNS extension, no
  # wildcard certificate, and cert-manager falls back to per-hostname HTTP-01 issuance.
  dns_enabled = var.dns_parent_zone_name != ""

  dns_delegated_zone_name = local.dns_enabled ? "${var.cluster_name}.${var.dns_parent_zone_name}" : null

  # Step 3 — the SKE control plane writes records into the delegated subzone.
  ske_dns_extension = local.dns_enabled ? {
    enabled = true
    zones   = [local.dns_delegated_zone_name]
  } : null

  # Step 4 — cert-manager solves the ACME challenge in the tenant's own STACKIT project and gets
  # one wildcard certificate for the whole delegated subzone.
  ingress_dns01 = local.dns_enabled && var.dns_service_account_key != "" ? {
    zone_name = local.dns_delegated_zone_name
    stackit = {
      project_id          = var.stackit_project_id
      service_account_key = var.dns_service_account_key
    }
  } : null
}
