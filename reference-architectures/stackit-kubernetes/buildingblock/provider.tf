# The meshstack provider is configured by the meshStack runtime at order time (mesh http backend), so
# it is intentionally not declared here.
#
# This architecture creates no STACKIT resources of its own — the cluster, the in-cluster services
# and the Git instance are all provisioned by child building blocks that authenticate via WIF. It does
# deploy the backplanes of the two definitions it registers, though, and those create service
# accounts and role assignments in the landing zone's STACKIT organization. That work runs as the
# landing zone's bootstrap identity, read from its building block outputs.
#
# The credential comes from a data source because that value is known at plan time and survives a
# destroy cleanly. OpenTofu does plan an unknown provider configuration — a provider whose host
# comes from a resource created in the same run plans fine and is resolved at apply — but a
# provider configured from a managed resource is a known-awkward pattern: on destroy and on
# replacement the configuration it needs is the thing being torn down.
provider "stackit" {
  experiments         = ["iam"] # Required for authorization resources
  service_account_key = local.landingzone_service_account_key
}
