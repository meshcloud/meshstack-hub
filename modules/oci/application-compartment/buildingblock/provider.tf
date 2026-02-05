terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "0.17.3"

    }
    oci = {
      source  = "oracle/oci"
      version = "7.32.0"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
}
