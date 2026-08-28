terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
      # 0.24.0 is the floor the recent meshStack-native modules pin; the `meshstack_api_key`
      # resource (preview) is available on current releases above it.
      version = ">= 0.24.0"
    }
  }
}
