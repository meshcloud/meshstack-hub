terraform {
  required_version = ">= 1.12.0" # const variables require OpenTofu >= 1.12 / Terraform >= 1.15

  required_providers {
    helm = {
      source = "hashicorp/helm"
      # The helm provider takes its cluster credentials as the `kubernetes = {}` attribute
      # starting with 3.0.0. Earlier versions expect a `kubernetes {}` block instead.
      version = ">= 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38"
    }
    meshstack = {
      source = "meshcloud/meshstack"
      # 0.24.0 carries `meshstack_platform.spec.config.custom` and
      # `meshstack_landingzone.spec.platform_properties.custom`, which is what registers the gateway
      # as a platform of a custom type.
      version = ">= 0.24.0"
    }
    stackit = {
      source = "stackitcloud/stackit"
      # The floor of modules/stackit/postgresflex/buildingblock/database, which this module sources
      # to create the gateway's own database inside the shared instance.
      version = ">= 0.110.0"
    }
    random = {
      source = "hashicorp/random"
      # random_password marks its result sensitive, so the generated master key and the ClickHouse
      # administrative password stay out of the plan.
      version = ">= 3.5.0"
    }
  }
}
