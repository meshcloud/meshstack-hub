# ─────────────────────────────────────────────────────────────────────────────
# STACKIT DNS zone
#
# The module creates one DNS zone in a STACKIT project, the record sets inside it, and a service
# account key that lets a workload manage those records at runtime — the cert-manager DNS-01 solver
# and ExternalDNS both take that key.
#
# STACKIT DNS is project-scoped end to end: `stackit_dns_record_set` carries its own `project_id`
# and that project must own the `zone_id`, and the SKE `extensions.dns` block has no field for a
# foreign project or a foreign credential. So the zone, its records and the credential that writes
# them all belong to one project.
#
# ── VERIFIED: no subzones under stackit.run ──────────────────────────────────
#
# A free STACKIT subdomain gives you exactly one zone at exactly one label. A two-label zone under
# `stackit.run` is rejected by the API before any delegation or project logic is reached:
#
#   stackit dns zone create --project-id <p> --name aipoc-c6a37f-sub \
#     --dns-name sub.aipoc-c6a37f.stackit.run
#   Error: create DNS zone: 400 Bad Request, status code 400, Body:
#   {"message":"zone dns name sub.aipoc-c6a37f.stackit.run has one error",
#    "error":"subdomain 'sub.aipoc-c6a37f' should only have one level"}
#
# The error is byte-for-byte identical with a correct NS delegation already in place in the parent
# zone, and identical again in a freshly created second project. The project makes no difference.
# `var.zone_name` carries a validation that rejects this shape at plan time rather than at apply.
#
# The same name under a customer-owned domain fails differently — "collides with a parent zone in a
# different project and has no delegation" — so the cross-project delegation machinery does exist
# and is project-aware. It simply never gets reached for `stackit.run`, because the name check fires
# first. That is why `var.delegation` is available for customer-owned domains and refuses free
# STACKIT suffixes.
#
# ── Consequence: one zone is shared ──────────────────────────────────────────
#
# With a free STACKIT subdomain, every cluster and every application under `likvid.stackit.run` is
# a record set inside that single zone, in a single project, written with a single credential. The
# key this module returns can therefore write any record in the zone, including over a record that
# belongs to somebody else. Per-zone isolation needs a customer-owned domain. See README.md.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # Label(s) the zone sits at below the parent zone. Only used on the delegation path.
  delegation_label = var.delegation == null ? null : trimsuffix(var.zone_name, ".${var.delegation.parent_zone_name}")

  dns_service_account_name = coalesce(
    var.dns_service_account_name,
    "mesh-dns-${replace(var.zone_name, ".", "-")}"
  )
}

resource "stackit_dns_zone" "this" {
  project_id    = var.project_id
  name          = var.zone_name
  dns_name      = var.zone_name
  type          = "primary"
  default_ttl   = var.zone_default_ttl
  contact_email = var.contact_email != "" ? var.contact_email : null
  description   = var.zone_description != "" ? var.zone_description : null
}

# Every name below the zone is a record set here, because a free STACKIT subdomain admits no
# subzone. A cluster reachable at `cluster1.likvid.stackit.run` with a wildcard below it needs two
# entries: `cluster1` and `*.cluster1`.
resource "stackit_dns_record_set" "this" {
  for_each = var.records

  project_id = var.project_id
  zone_id    = stackit_dns_zone.this.zone_id
  name       = each.key
  type       = each.value.type
  ttl        = each.value.ttl
  records    = each.value.records
  comment    = each.value.comment
}

# ── Delegation — customer-owned domains only ─────────────────────────────────
#
# The NS record goes into the parent zone, which lives in the platform team's own project, while
# the zone above lives in `var.project_id`. One identity writes into both, because STACKIT
# credentials identify a service account rather than a project and every resource names its own
# `project_id`. The backplane grants that identity `dns.admin` at organization scope.
#
# Two traps this code guards against, both seen in the proof-of-concept:
#
#   - Record values are relativised against the zone unless they end in a dot. `ns1.stackit.cloud`
#     was stored as `ns1.stackit.cloud.aipoc-c6a37f.stackit.run.`, so the default carries the
#     trailing dot and `var.delegation.nameservers` is documented to require it.
#   - An orphaned NS record fails silently. The delegation is accepted and published, a direct
#     query returns NOERROR with an empty answer and a referral, and a recursive resolver returns
#     SERVFAIL. Nothing errors at apply time. `depends_on` therefore creates the zone first, and
#     the precondition below refuses to write a record that points at a name this module is not
#     creating.

data "stackit_dns_zone" "parent" {
  count = var.delegation == null ? 0 : 1

  project_id = var.delegation.parent_zone_project_id
  dns_name   = var.delegation.parent_zone_name
}

resource "stackit_dns_record_set" "delegation" {
  count = var.delegation == null ? 0 : 1

  project_id = var.delegation.parent_zone_project_id
  zone_id    = data.stackit_dns_zone.parent[0].zone_id
  name       = local.delegation_label
  type       = "NS"
  ttl        = var.delegation.ttl
  records    = var.delegation.nameservers
  comment    = "Delegates ${var.zone_name} to the STACKIT project that owns it."

  depends_on = [stackit_dns_zone.this]

  lifecycle {
    precondition {
      condition     = endswith(var.zone_name, ".${var.delegation.parent_zone_name}")
      error_message = "zone_name (${var.zone_name}) must sit below delegation.parent_zone_name (${var.delegation.parent_zone_name}), otherwise the NS record delegates a name this module does not create and the name resolves to SERVFAIL with no error at apply time."
    }

    precondition {
      condition     = alltrue([for ns in var.delegation.nameservers : endswith(ns, ".")])
      error_message = "Every entry of delegation.nameservers must end in a dot. STACKIT relativises a value without one against the zone, so ns1.stackit.cloud is stored as ns1.stackit.cloud.<zone>. and the delegation points nowhere."
    }
  }
}

# ── DNS credential ───────────────────────────────────────────────────────────
#
# A service account holding `dns.admin` on the zone's project. cert-manager solves the ACME DNS-01
# challenge with its key, and ExternalDNS writes the workload's records with it.
#
# `dns.admin` is a project role, so the key reaches every zone in `var.project_id` and every record
# in them. It cannot be narrowed to a single zone or a single name.

resource "stackit_service_account" "dns" {
  count = var.dns_service_account_enabled ? 1 : 0

  project_id = var.project_id
  name       = local.dns_service_account_name
}

resource "stackit_authorization_project_role_assignment" "dns" {
  count = var.dns_service_account_enabled ? 1 : 0

  resource_id = var.project_id
  role        = "dns.admin"
  subject     = stackit_service_account.dns[0].email
}

resource "stackit_service_account_key" "dns" {
  count = var.dns_service_account_enabled ? 1 : 0

  project_id            = var.project_id
  service_account_email = stackit_service_account.dns[0].email
  ttl_days              = var.dns_service_account_key_ttl_days
}
