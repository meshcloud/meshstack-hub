# Credentials come from `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET` and `OVH_CONSUMER_KEY`, which
# the meshStack integration sets.
provider "ovh" {
  endpoint = var.endpoint
}
