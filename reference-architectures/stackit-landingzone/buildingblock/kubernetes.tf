# ─────────────────────────────────────────────────────────────────────────────
# The Kubernetes option
#
# Registers the `stackit-kubernetes` reference architecture as a `TENANT_LEVEL` building block
# definition, so an application team orders a cluster into its own STACKIT project — the project the
# `STACKIT Project` platform above handed it — and gets back a meshStack Kubernetes platform whose
# landing zones promise namespaces *and a working HTTPS hostname*.
#
# That architecture composes `modules/stackit/ske`, `modules/kubernetes/ingress`,
# `modules/kubernetes/platform` and `modules/stackit/dns` in one run, and it calls
# `modules/stackit/ske/backplane` from the integration file below to mint the single STACKIT identity
# the whole run authenticates as.
#
# Everything the platform team decides once is passed in here as a static input of that definition:
# the shared DNS zone, the project that owns it and the credential that writes into it (all three
# from dns.tf), the folder the tenant projects live under, the meshStack location, and the ACME and
# ingress settings. What the ordering team decides is the cluster's name and its exposure.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  kubernetes_enabled = var.kubernetes != null
}

module "kubernetes_integration" {
  count  = local.kubernetes_enabled ? 1 : 0
  source = "github.com/meshcloud/meshstack-hub//reference-architectures/stackit-kubernetes?ref=${var.hub.git_ref}"

  # The backplane service account lives in the foundation project and holds `ske.admin` on the
  # landing-zone folder, because the cluster lands in whichever tenant project places the order and
  # no project can be named here. `stackit_folder_id` takes the folder's UUID, not its container id.
  stackit_backplane_project_id = stackit_resourcemanager_project.foundation.project_id
  stackit_folder_id            = stackit_resourcemanager_folder.this.folder_id
  stackit_service_account_name = var.kubernetes.stackit_service_account_name
  stackit_region               = var.kubernetes.stackit_region

  # The zone this building block created, its project, and the key that writes into it. The cluster
  # only ever adds `*.<cluster name>` to it — see dns.tf for why that division of labour is forced.
  # `module.dns_zone.zone_name` is read off the zone resource rather than off the variable, and that
  # is what orders the two: the definition cannot name a zone that does not exist yet. The key
  # already depends on its role assignment, so no `depends_on` is needed — and one would defer this
  # module's `meshstack_integrations` data source to apply time for nothing.
  stackit_dns_parent_zone_name      = module.dns_zone[0].zone_name
  stackit_dns_zone_project_id       = local.dns_zone_project_id
  stackit_dns_cluster_label_enabled = var.kubernetes.dns_cluster_label_enabled
  stackit_dns_service_account_key   = module.dns_zone[0].dns_service_account_key

  location_identifier = local.location_identifier
  acme_server         = var.kubernetes.acme_server
  cluster_issuer_name = var.kubernetes.cluster_issuer_name
  ingress_class_name  = var.kubernetes.ingress_class_name

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}
