terraform {
  required_version = ">= 1.12.0"

  required_providers {
    stackit = {
      source = "stackitcloud/stackit"
      # 0.88.0 is the first release that carries `network.id` for STACKIT Network Area
      # placement and `network.control_plane.access_scope` for the control plane scope.
      version = ">= 0.88.0"
    }
  }
}
