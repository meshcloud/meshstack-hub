terraform {
  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    oci = {
      source = "oracle/oci"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
}
