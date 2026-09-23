# Credentials come from the STACKIT_* environment inputs meshStack sets for workload identity federation.
provider "stackit" {
  default_region = var.stackit_region
}