terraform {
  required_version = ">= 1.3.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.21.0"
    }
    oci = {
      source  = "oracle/oci"
      version = ">= 7.32.0, < 8.0.0"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
}
