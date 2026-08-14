# ─────────────────────────────────────────────────────────────────────────────
# STACKIT DNS zone — the provider-free core of this building block
#
# The module creates one DNS zone in a STACKIT project, the record sets inside it, and a service
# account key that lets a workload manage those records at runtime — the cert-manager DNS-01 solver
# and ExternalDNS both take that key. With `create_zone = false` it skips the zone and writes its
# record sets into a zone that already exists.
#
# The root above (`..`) is the same thing with a `provider "stackit"` attached, which is what
# meshStack runs when a team orders the building block. Callers that drive DNS from their own root
# configuration source *this* module instead — see versions.tf for why that distinction is forced.
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
# belongs to somebody else. Per-zone isolation needs a customer-owned domain. See ../README.md.
#
# ── The shared zone and the per-cluster label ────────────────────────────────
#
# STACKIT allows a record set with a deeper name inside an existing zone, so one platform-owned
# zone can carry many clusters. The platform team creates `likvid.stackit.run` with
# `create_zone = true`, and each cluster then runs this module again with `create_zone = false` and
# its own label:
#
#   cluster1 → wildcard = { label = "cluster1", address = <its load balancer> }
#              gives the record set `*.cluster1.likvid.stackit.run`
#   cluster2 → wildcard = { label = "cluster2", address = <its load balancer> }
#
# The label keeps each cluster's names apart, and it keeps each cluster's wildcard certificate down
# to `*.cluster1.likvid.stackit.run` instead of the whole domain. The credential stays zone-wide
# either way, so the label is a boundary this code draws and not one the permission system enforces.
#
# A cluster that leaves the label unset gets `*.likvid.stackit.run` at the zone apex instead, which
# is the shape the SKE foundations have today. Exactly one cluster per zone can have it. See
# ../README.md.
#
# ── Switching the module off ─────────────────────────────────────────────────
#
# A caller of *this* module puts `count = 0` on it, which is the whole point of the module carrying
# no provider configuration.
#
# `zone_name = null` is the same switch for callers that cannot. The root above configures its own
# STACKIT provider so that meshStack can run it as a building block, and Terraform refuses `count`,
# `for_each` and `depends_on` on such a module:
#
#   Module is incompatible with count, for_each, and depends_on: the module [...] contains its own
#   local provider configurations, and so calls to it may not use the count, for_each, enabled or
#   depends_on arguments.
#
# With a null zone name the module creates and reads nothing, so the root passes it straight
# through and a composition switches the whole thing off that way.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # Label(s) the zone sits at below the parent zone. Only used on the delegation path.
  delegation_label = var.delegation == null ? null : trimsuffix(var.zone_name, ".${var.delegation.parent_zone_name}")

  # VERIFIED: STACKIT caps a service account name at 20 characters, and the provider rejects a
  # longer one at plan time:
  #
  #   Error: Invalid Attribute Value Length
  #     with stackit_service_account.dns[0]
  #   Attribute name string length must be at most 20, got: 27
  #
  # So the zone name cannot simply be pasted in. `mesh-dns-likvid-stackit-run` is 27 characters, and
  # every zone under a free STACKIT suffix overruns the cap the same way — `mesh-dns-a-stackit-run`
  # is already 22. The default therefore carries the zone's first label, truncated to six
  # characters, plus four hex digits of the full zone name, which is what still keeps two zones in
  # the same project apart when their first labels agree. That is 20 characters at most.
  dns_service_account_suffix = var.zone_name == null ? null : format(
    "%s-%s",
    trimsuffix(substr(split(".", var.zone_name)[0], 0, 6), "-"),
    substr(md5(var.zone_name), 0, 4)
  )

  dns_service_account_name = var.zone_name == null ? null : coalesce(
    var.dns_service_account_name,
    "mesh-dns-${local.dns_service_account_suffix}"
  )

  # The zone this module writes into. It either creates the zone, takes the id the caller passed, or
  # looks the id up by the zone's DNS name. Null while the module is switched off.
  zone_id = (
    var.create_zone ? one(stackit_dns_zone.this[*].zone_id) :
    var.zone_id != null ? var.zone_id :
    one(data.stackit_dns_zone.existing[*].zone_id)
  )

  # Fully qualified name of the wildcard record set. `*.likvid.stackit.run` at the zone apex, or
  # `*.cluster1.likvid.stackit.run` below a label. The SKE foundations already carry their wildcard
  # under the fully qualified name, so writing the same form keeps their plan empty when they move
  # to this module.
  wildcard_name = var.wildcard == null ? null : (
    var.wildcard.label == null
    ? "*.${var.zone_name}"
    : "*.${var.wildcard.label}.${var.zone_name}"
  )

  # Domain the wildcard covers. This is the domain application hostnames live under, and the domain
  # a wildcard certificate has to be issued for.
  wildcard_domain = var.wildcard == null ? null : trimprefix(local.wildcard_name, "*.")
}

resource "stackit_dns_zone" "this" {
  count = var.create_zone ? 1 : 0

  project_id    = var.project_id
  name          = coalesce(var.zone_display_name, var.zone_name)
  dns_name      = var.zone_name
  type          = "primary"
  default_ttl   = var.zone_default_ttl
  contact_email = var.contact_email != "" ? var.contact_email : null
  description   = var.zone_description != "" ? var.zone_description : null
}

# Reads the zone the caller does not create and does not identify by id. `dns_name` is a lookup
# argument of the data source, so the caller gets by with the zone's name and never has to carry a
# UUID through its inputs.
data "stackit_dns_zone" "existing" {
  count = var.zone_name != null && !var.create_zone && var.zone_id == null ? 1 : 0

  project_id = var.project_id
  dns_name   = var.zone_name
}

# Every name below the zone is a record set here, because a free STACKIT subdomain admits no
# subzone. A cluster reachable at `cluster1.likvid.stackit.run` with a wildcard below it needs two
# entries: `cluster1` and `*.cluster1`.
resource "stackit_dns_record_set" "this" {
  for_each = var.records

  project_id = var.project_id
  zone_id    = local.zone_id
  name       = each.key
  type       = each.value.type
  ttl        = each.value.ttl
  records    = each.value.records
  comment    = each.value.comment
}

# The wildcard that sends every application hostname to the ingress controller. It sits at the zone
# apex when the caller sets no label, and below the label otherwise.
resource "stackit_dns_record_set" "wildcard" {
  count = var.wildcard == null ? 0 : 1

  project_id = var.project_id
  zone_id    = local.zone_id
  name       = local.wildcard_name
  type       = "A"
  ttl        = var.wildcard.ttl
  records    = [var.wildcard.address]
  comment    = var.wildcard.comment
}

# ── Delegation — customer-owned domains only ─────────────────────────────────
#
# The NS record goes into the parent zone, which lives in the platform team's own project, while
# the zone above lives in `var.project_id`. One identity writes into both, because STACKIT
# credentials identify a service account rather than a project and every resource names its own
# `project_id`. The backplane grants that identity `dns.admin` on every project it can name —
# `delegation.parent_zone_project_id` among them — and on the folder above them otherwise.
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
# It has to be a key rather than a federated identity. A workload identity token is federated into
# the Terraform run that creates the cluster, and a controller running inside that cluster
# afterwards holds no such token — so `../backplane` cannot supply this credential.
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

  # The key is handed to a workload the moment this module returns it, so the role has to be in
  # place before the key exists. Nothing in the arguments above orders the two.
  depends_on = [stackit_authorization_project_role_assignment.dns]
}
