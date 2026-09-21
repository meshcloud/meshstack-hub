# The meshstack provider is configured by the meshStack runtime at order time (mesh http backend), so
# it is intentionally not declared here.
#
# This architecture creates no STACKIT resources of its own — the cluster, the platform services and
# the Git instance are all provisioned by child building blocks that authenticate via WIF. It does
# deploy the backplanes of the two definitions it registers, though, and those create service
# accounts and role assignments in the landing zone's STACKIT organization. That work runs as the
# landing zone's bootstrap identity, read from its building block outputs.
#
# A provider configuration may depend on a data source (those resolve at plan time) but not on a
# managed resource created in the same apply, which is why this reads the landing zone data source
# and not anything this run creates.
provider "stackit" {
  experiments         = ["iam"] # Required for authorization resources
  service_account_key = local.landingzone_service_account_key
}
