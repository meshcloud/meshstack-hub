# Auth flows in through the STACKIT_SERVICE_ACCOUNT_KEY environment variable (a service account key
# JSON), which meshStack injects as a static environment input. Nothing here reads a cloud-side WIF
# federation, so the module needs no backplane.
provider "stackit" {
  default_region = var.stackit_region
}
