terraform {
  required_version = ">= 1.12.0"
  backend "local" {
    
  }

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.28.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.0, < 1.0.0"
    }
  }
}

provider "meshstack" {
  profile = "devops-platform-yhk-pe-key"
  workspace = "devops-platform"
}
