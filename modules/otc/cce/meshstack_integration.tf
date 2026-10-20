variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

variable "otc_domain_name" {
  type        = string
  description = "T Cloud Public domain (account) name, e.g. `OTC-EU-DE-00000000001000000000`."
}

variable "otc_region" {
  type        = string
  default     = "eu-de"
  description = "T Cloud Public region the clusters are created in. Its availability zones are offered as `<region>-01` to `-03`."
}

variable "otc_auth_url" {
  type        = string
  default     = "https://iam.eu-de.otc.t-systems.com/v3"
  description = "IAM endpoint the building block authenticates against."
}

variable "workload_identity_name" {
  type        = string
  default     = "meshstack-cce"
  description = "Name of the identity provider and IAM group the building block signs in through. Unique across the domain."
}

variable "otc_platform_type" {
  type        = string
  default     = "OTC"
  description = "Name of the custom meshStack platform type the projects' tenants live on."
}

variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Runs this building block on the given meshStack building block runner instead of the shared one meshStack hosts."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "main"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

# Runs sign in through workload identity federation, so the definition carries no access key. This
# module's own provider credentials only set up the identity provider and its group.
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/otc/cce/backplane?ref=${var.hub.git_ref}"

  name = var.workload_identity_name
  workload_identity_federation = {
    issuer   = meshstack_building_block_definition.this.version_latest.workload_identity_federation.issuer
    subject  = meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject
    audience = meshstack_building_block_definition.this.version_latest.workload_identity_federation.gcp.audience
  }
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

locals {
  availability_zones = [for zone in ["01", "02", "03"] : "${var.otc_region}-${zone}"]
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "T Cloud Public CCE Cluster")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/otc/cce/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Provisions a Cloud Container Engine (CCE) Kubernetes cluster in your project's network and hands you an admin kubeconfig.")
    support_url         = "https://console.otc.t-systems.com/cce2.0/"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = var.otc_platform_type }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    This building block creates a Cloud Container Engine (CCE) Kubernetes cluster in your T Cloud
    Public project, with worker nodes in the availability zones you choose, and gives you a
    cluster-admin kubeconfig as an output.

    ## 🎯 When to use it

    Use this building block when you:
    - want to run containerized workloads on a managed Kubernetes control plane
    - need a cluster in the same network as your databases and other project resources

    Order the **T Cloud Public Network** building block on the project first. The cluster joins its
    VPC and subnet, and its worker nodes reach the internet through the network's SNAT gateway, so
    keep SNAT enabled there. Creating a cluster takes about 15 to 30 minutes.

    ## 💡 Usage examples

    **Example 1: A first cluster for a team**
    A team orders a cluster with two nodes in one availability zone, copies the kubeconfig output
    and deploys its services with kubectl or Helm.

    **Example 2: A cluster that survives a zone outage**
    A team picks all three availability zones, so each zone gets its own node pool and workloads
    keep running when one zone fails.

    ## 📦 Resources created

    - **CCE cluster** in the project's VPC, with its Kubernetes API on an elastic IP unless you turn
      public API access off.
    - **One node pool per availability zone**, each with the chosen number of nodes and flavor.
    - **A key pair** for the worker nodes.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the project, its network and credentials for the cluster | ✅ | ❌ |
    | Create the cluster and its node pools | ✅ | ❌ |
    | Keep the kubeconfig secret | ❌ | ✅ |
    | Deploy, secure and monitor workloads on the cluster | ❌ | ✅ |
    | Upgrade Kubernetes and resize node pools | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"
    runner_ref = var.building_block_runner_uuid == null ? null : {
      kind = "meshBuildingBlockRunner"
      uuid = var.building_block_runner_uuid
    }

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/otc/cce/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
        pre_run_script                 = file("${path.module}/../workload-identity/prerun.sh")
      }
    }

    inputs = {
      project_id = {
        display_name    = "Project ID"
        description     = "T Cloud Public project the cluster is created in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      region = {
        display_name    = "Region"
        description     = "T Cloud Public region of the project."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.otc_region)
      }

      name = {
        display_name                   = "Cluster Name"
        description                    = "Name of the cluster: 4-52 lowercase letters, digits and dashes, starting with a letter."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z][a-z0-9-]{2,50}[a-z0-9]$"
        validation_regex_error_message = "Use 4-52 lowercase letters, digits and dashes; start with a letter and do not end with a dash."
        display_order                  = 10
      }

      availability_zones = {
        display_name      = "Availability Zones"
        description       = "Zones the worker nodes run in. Each zone gets its own node pool."
        type              = "MULTI_SELECT"
        assignment_type   = "USER_INPUT"
        selectable_values = local.availability_zones
        default_value     = jsonencode([local.availability_zones[0]])
        display_order     = 20
      }

      # The upstream module ignores later changes to a node pool's initial node count, so a changed
      # value would do nothing.
      node_count = {
        display_name    = "Nodes per Zone"
        description     = "Number of worker nodes in each availability zone."
        type            = "INTEGER"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(2)
        display_order   = 30
      }

      node_flavor = {
        display_name    = "Node Flavor"
        description     = "ECS flavor of the worker nodes, e.g. s3.xlarge.4 (4 vCPUs, 16 GiB)."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("s3.xlarge.4")
        display_order   = 40
      }

      public_api = {
        display_name           = "Public Kubernetes API"
        description            = "Reach the Kubernetes API from the internet. Off, it is reachable only from inside the VPC."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(true)
        updateable_by_consumer = true
        display_order          = 50
      }

      network_name = {
        display_name    = "Network Name"
        description     = "Name of the VPC and subnet the T Cloud Public Network building block created. Keep the default unless you renamed it there."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("app")
        display_order   = 60
      }

      OS_AUTH_URL = {
        display_name    = "OTC Auth URL"
        description     = "IAM endpoint the provider authenticates against."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_auth_url)
      }

      OS_DOMAIN_NAME = {
        display_name    = "OTC Domain Name"
        description     = "T Cloud Public domain the building block acts in."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_domain_name)
      }

      OTC_IDENTITY_PROVIDER = {
        display_name    = "OTC Identity Provider"
        description     = "Identity provider the pre-run script exchanges the run token at."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.workload_identity_name)
      }
    }

    outputs = {
      cluster_id = {
        display_name    = "Cluster ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      cluster_name = {
        display_name    = "Cluster Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      api_endpoint = {
        display_name    = "Kubernetes API"
        type            = "STRING"
        assignment_type = "NONE"
      }

      # Carries a cluster-admin certificate; the members of the project own the cluster and need it.
      kubeconfig = {
        display_name    = "Kubeconfig"
        type            = "STRING"
        assignment_type = "NONE"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.26.2"
    }
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = ">= 1.37.0, < 2.0.0"
    }
  }
}
