# ─────────────────────────────────────────────────────────────────────────────
# The shared DNS zone of the Kubernetes option
#
# The landing zone owns one zone, and every cluster ordered against it shares that zone. This file
# creates the zone and the credential that writes into it; `kubernetes.tf` hands both to the cluster
# building block definition as static inputs. **The ordered cluster never creates a zone.**
#
# That division of labour is not a preference, it is what STACKIT allows. A free STACKIT subdomain —
# `stackit.run`, `runs.onstackit.cloud`, `stackit.rocks`, `stackit.gg`, `stackit.zone` — admits
# exactly one label, and the API rejects a deeper zone before any delegation or project logic is
# reached:
#
#   zone dns name sub.aipoc-c6a37f.stackit.run has one error
#   subdomain 'sub.aipoc-c6a37f' should only have one level
#
# That error is byte-for-byte identical with a correct NS delegation already in place and identical
# again in a freshly created second project, so a subzone per cluster is impossible. Everything below
# the one zone is a record set, in one project, written with one credential.
#
# A record set *is* allowed to be deeper than the zone, and that is what each cluster gets: with
# `dns_cluster_label_enabled` (the default), cluster `cluster1` writes `*.cluster1` into the zone and
# holds a wildcard certificate for `*.cluster1.<zone>`, so it takes a label of its own inside the
# shared zone.
#
# ── The credential is zone-wide; the label is not a permission boundary ──────
#
# `dns.admin` is a project role. It cannot be narrowed to one zone, let alone to one label, so a
# cluster *could* write records outside its own label. What keeps clusters inside their label is the
# building block code, not the credential. It is a code-enforced boundary and not a permission
# boundary, and it stays documented rather than hidden — see the architecture README.
#
# ── Why `zone` and not the building block root above it ──────────────────────
#
# `modules/stackit/dns/buildingblock` is a meshStack root module: it carries its own
# `provider "stackit"` with `use_oidc = true`, which is right for the workload-identity runs it is
# ordered in and wrong for this one. This building block authenticates with
# `var.stackit_service_account_key`, and a caller cannot override a provider that a child module
# configures itself — nor call such a module with `count`. Its `zone` submodule declares no provider
# for exactly that reason, so this file calls that and supplies the provider from provider.tf.
#
# `modules/stackit/dns/backplane` is no substitute: it federates an OIDC identity and issues no
# static key, and a static key is what a controller inside the ordered cluster needs.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # The zone lives in the foundation project, next to the landing zone's other core assets.
  dns_zone_project_id = stackit_resourcemanager_project.foundation.project_id
}

# The zone, the DNS service account, its `dns.admin` assignment on the foundation project and its
# key. The key is the credential cert-manager's DNS-01 solver authenticates with inside the ordered
# cluster. It has to be a key: the cluster's own identity federates a workload identity token into
# the meshStack run, and a controller running in the cluster afterwards has no such token.
#
# No records are created here. Each ordered cluster adds its own, through the same module called
# with `create_zone = false` from `reference-architectures/stackit-kubernetes`.
module "dns_zone" {
  count  = local.kubernetes_enabled ? 1 : 0
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/dns/buildingblock/zone?ref=${var.hub.git_ref}"

  project_id  = local.dns_zone_project_id
  zone_name   = var.kubernetes.dns_zone_name
  create_zone = true

  zone_default_ttl = var.kubernetes.dns_zone_default_ttl
  zone_description = "Shared zone of the ${var.platform_identifier} landing zone. Every ordered cluster writes its own label into it."
}
