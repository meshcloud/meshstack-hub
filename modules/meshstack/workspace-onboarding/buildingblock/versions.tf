terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
      # 0.24.0 is where `meshstack_tenant` moved to the meshTenant v4 API, which is the shape this
      # module writes: `platform_ref` and `landing_zone_ref` instead of the identifier fields.
      version = ">= 0.24.0"
    }
  }
}
