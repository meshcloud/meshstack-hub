variable "stackit_backplane_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the backplane creates its service account in. This is the platform team's own project. It is deliberately not called `stackit_project_id`: the building block definition already carries an input of that name, which meshStack fills from the ordering tenant's STACKIT project."
}

variable "stackit_folder_id" {
  type        = string
  nullable    = false
  description = "STACKIT folder the tenant projects live under. The backplane grants the service account `ske.admin` here, which covers every project below it. The cluster lands in whichever tenant project places the order, so no single project can be named, and STACKIT offers no ske role at organization scope."
}

variable "stackit_service_account_name" {
  type        = string
  nullable    = true
  default     = null
  description = "Name of the backplane service account. Defaults to `mesh-ske`. Override when deploying several instances of this architecture into the same STACKIT project."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the clusters are created in."
}

variable "stackit_dns_parent_zone_name" {
  type        = string
  nullable    = false
  default     = ""
  description = "DNS zone the platform team owns and every ordered cluster shares, for example `likvid.stackit.run`. Each cluster writes the record set `*.<cluster name>` into it and creates no zone of its own. Leave empty to run without DNS, in which case cert-manager issues per-hostname certificates over HTTP-01."
}

variable "stackit_dns_zone_project_id" {
  type     = string
  nullable = false
  default  = ""

  description = <<-EOT
  STACKIT project UUID that owns `stackit_dns_parent_zone_name`, which is usually the platform
  team's own project. The backplane grants the service account `dns.admin` on exactly this project.

  Leave empty when the zone lives in the tenant's own STACKIT project, because the cluster then
  defaults to the project it is created in. That project is unknowable here, so the backplane can
  grant nothing for it — add `dns.admin` on `stackit_folder_id` yourself if you run DNS that way.
  EOT
}

variable "stackit_dns_cluster_label_enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "Give each cluster its own label inside the shared zone, so its hostnames are `<app>.<cluster name>.<parent zone>`. Set it to false to put the cluster's wildcard at the zone apex instead, which gives the flat hostnames `<app>.<parent zone>`. Only one cluster per zone can hold the apex."
}

variable "stackit_dns_service_account_key" {
  type        = string
  nullable    = false
  default     = ""
  sensitive   = true
  description = "STACKIT service account key JSON that the cert-manager DNS-01 solver authenticates with. It needs `dns.admin` on the project that owns the shared zone, and it can write every record in that zone. Required for the wildcard certificate."
}

variable "location_identifier" {
  type        = string
  nullable    = false
  default     = "global"
  description = "Identifier of the meshStack location the Kubernetes platforms are registered in."
}

variable "acme_server" {
  type        = string
  nullable    = false
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  description = "ACME directory URL. Point this at the Let's Encrypt staging endpoint while you test, because the production endpoint has strict rate limits."
}

variable "cluster_issuer_name" {
  type        = string
  nullable    = false
  default     = "letsencrypt-prod"
  description = "Name of the ClusterIssuer application teams reference from the `cert-manager.io/cluster-issuer` annotation on their Ingress."
}

variable "ingress_class_name" {
  type        = string
  nullable    = false
  default     = "haproxy"
  description = "Name of the IngressClass the ingress controller serves."
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
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

data "meshstack_integrations" "integrations" {}

# One backplane, one service account, one identity the whole composition runs as. The building block
# creates the cluster and writes the cluster's wildcard record into the shared DNS zone in the same
# Terraform run, so both modules authenticate as this account.
#
# The two roles sit at different scopes, and the reason is worth keeping in view: scope follows what
# can be named here.
#
#   - `ske.admin` covers a folder. The cluster is created in the STACKIT project of whichever
#     meshTenant places the order — that is the `stackit_project_id` building block definition input
#     below, which meshStack fills from `PLATFORM_TENANT_ID` — and the platform team registers this
#     definition long before it knows which projects those will be.
#   - `dns.admin` covers one project. The shared zone's project is `stackit_dns_zone_project_id`, a
#     static input the platform team fills in right here, so naming it costs nothing and keeps the
#     identity off every other project. Without this grant the DNS module fails with a 403 the
#     moment a tenant orders a cluster.
#
# The caller's STACKIT provider needs `experiments = ["iam"]` — the role assignment resources sit
# behind that provider experiment.
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/ske/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_backplane_project_id
  folder_id            = var.stackit_folder_id
  service_account_name = coalesce(var.stackit_service_account_name, "mesh-ske")

  additional_roles_project_id = var.stackit_dns_zone_project_id
  additional_project_roles    = var.stackit_dns_zone_project_id == "" ? [] : ["dns.admin"]

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = "STACKIT Kubernetes Cluster"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-kubernetes/buildingblock/logo.png"
    description         = "Creates an SKE cluster in the tenant's own STACKIT project, installs cert-manager and the HAProxy ingress controller on it, and registers it in meshStack as a Kubernetes platform with namespace landing zones."
    support_url         = "https://portal.stackit.cloud"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = "STACKIT" }]

    readme = chomp(<<-EOT
    This building block creates a **STACKIT Kubernetes Engine cluster** inside your own STACKIT
    project and turns it into a platform your teams can order namespaces on. One order gives you
    the cluster, an ingress controller with Let's Encrypt certificates, and a Kubernetes platform
    in meshStack with a development and a production namespace landing zone.

    An application that runs in one of those namespaces reaches the internet over a hostname in the
    cluster's own domain, and the certificate for that hostname already exists. You do not request
    a certificate, and you do not create a DNS record.

    ## 🎯 When to use it

    Use this building block when you:
    - need a Kubernetes cluster of your own on STACKIT rather than a namespace on a shared cluster.
    - want your teams to order namespaces from the meshStack catalog instead of asking you for them.
    - want every application to get an HTTPS hostname without a certificate request.

    ## 💡 Usage examples

    **Example 1: A team platform**
    A team orders the cluster in its STACKIT project and names it `team-a`. meshStack registers the
    cluster as a platform with a `team-a-dev` and a `team-a-prod` landing zone, and the team's
    projects get namespaces on it with the quotas the landing zone grants.

    **Example 2: A cluster that stays inside the network**
    A team runs an internal application and sets **Ingress Exposure** to `internal`. The load
    balancer in front of the ingress controller receives a private address, so the application is
    reachable from inside the STACKIT network only, while certificates are still issued and renewed
    automatically.

    ## 🌐 Hostnames and certificates

    The platform team owns one DNS zone that every cluster shares, and each cluster gets its own
    label inside it, named after the cluster. Your applications live under
    `<app>.team-a.likvid.stackit.run`, one record set points that whole label at your ingress load
    balancer, and cert-manager holds one wildcard certificate for it. Adding an Ingress with a
    hostname under the cluster's domain is all an application needs.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the STACKIT identity the building block runs as | ✅ | ❌ |
    | Own the shared DNS zone and the key its records are written with | ✅ | ❌ |
    | Register and maintain this building block definition | ✅ | ❌ |
    | Choose the cluster name and the ingress exposure | ❌ | ✅ |
    | Order namespaces on the resulting Kubernetes platform | ❌ | ✅ |
    | Deploy, expose and operate the applications in those namespaces | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # Ephemeral API key permissions for the meshStack platform and landing zones the composed
    # `modules/kubernetes/platform` module registers.
    permissions = [
      "LANDINGZONE_LIST",
      "LANDINGZONE_SAVE",
      "LANDINGZONE_DELETE",
      "PLATFORMINSTANCE_LIST",
      "PLATFORMINSTANCE_SAVE",
      "PLATFORMINSTANCE_DELETE"
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/stackit-kubernetes/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── Tenant context and STACKIT authentication ──

      stackit_project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project of the meshTenant the cluster is created in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      stackit_service_account_email = {
        display_name    = "Service Account Email"
        description     = "Email of the STACKIT service account for WIF-based authentication."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.service_account_email)
      }

      STACKIT_USE_OIDC = {
        display_name    = "STACKIT Use OIDC"
        description     = "Enables OIDC-based WIF for the STACKIT provider."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("1")
      }

      STACKIT_FEDERATED_TOKEN_FILE = {
        display_name    = "STACKIT Federated Token File"
        description     = "Path to the WIF token file injected by meshStack."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }

      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "STACKIT region the cluster is created in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_region)
      }

      hub = {
        display_name    = "Hub"
        description     = "JSON object with `git_ref`, the meshstack-hub reference used to source the SKE, Kubernetes platform and ingress modules."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }

      # ── What the application team decides ──

      cluster_name = {
        display_name                   = "Cluster Name"
        description                    = "Name of the cluster. It also names the meshStack platform and the cluster's label in the shared DNS zone. STACKIT limits SKE cluster names to 11 characters."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([a-z0-9-]{0,9}[a-z0-9])?$"
        validation_regex_error_message = "Cluster name may contain up to 11 lowercase letters, digits and hyphens, and must start and end with a letter or a digit."
      }

      expose = {
        display_name                   = "Ingress Exposure"
        description                    = "`public` puts the ingress controller behind a public load balancer, `internal` keeps the load balancer inside the STACKIT network, and `none` installs no ingress controller."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        updateable_by_consumer         = true
        default_value                  = jsonencode("public")
        value_validation_regex         = "^(public|internal|none)$"
        validation_regex_error_message = "Ingress exposure must be public, internal or none."
      }

      # ── meshStack platform registration ──

      owning_workspace_identifier = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that owns the Kubernetes platform and its namespace landing zones."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      location_identifier = {
        display_name    = "Location Identifier"
        description     = "meshStack location the Kubernetes platform is registered in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.location_identifier)
      }

      # ── Ingress and certificates, set once by the platform team ──

      # No `acme_email` input. Let's Encrypt accepts an account without a contact address, and
      # cert-manager reports a failed renewal inside the cluster, so the address is a backstop
      # rather than a requirement. Exposing it is a later feature — see README.md.

      acme_server = {
        display_name    = "ACME Directory URL"
        description     = "ACME directory URL. Point this at the Let's Encrypt staging endpoint while you test."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.acme_server)
      }

      cluster_issuer_name = {
        display_name    = "Cluster Issuer Name"
        description     = "Name of the ClusterIssuer applications reference from their Ingress."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.cluster_issuer_name)
      }

      ingress_class_name = {
        display_name    = "Ingress Class Name"
        description     = "Name of the IngressClass the controller serves."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.ingress_class_name)
      }

      # ── DNS ──

      dns_parent_zone_name = {
        display_name    = "DNS Parent Zone"
        description     = "Zone the platform team owns and every cluster shares. Each cluster writes the record set `*.<cluster name>` into it. Leave empty to run without DNS."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_dns_parent_zone_name)
      }

      # The shared zone lives in the platform team's project, not in the tenant's own project the
      # cluster is created in. Without this input the cluster looks the zone up in its own project
      # and finds nothing.
      dns_zone_project_id = {
        display_name    = "DNS Zone Project ID"
        description     = "STACKIT project that owns the shared DNS zone. Leave empty when the zone lives in the tenant's own project."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_dns_zone_project_id)
      }

      dns_cluster_label_enabled = {
        display_name    = "DNS Label per Cluster"
        description     = "Give each cluster its own label inside the shared zone, so its hostnames are `<app>.<cluster name>.<parent zone>`. Turn it off to put the cluster's wildcard at the zone apex, which only one cluster per zone can hold."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_dns_cluster_label_enabled)
      }

      dns_service_account_key = {
        display_name    = "DNS Service Account Key"
        description     = "STACKIT service account key JSON the cert-manager DNS-01 solver authenticates with. It needs `dns.admin` on the project that owns the shared zone."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value = var.stackit_dns_service_account_key
          }
        }
      }
    }

    outputs = {
      cluster_name = {
        display_name    = "Cluster Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      cluster_url = {
        display_name    = "Open STACKIT Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      platform_identifier = {
        display_name    = "Kubernetes Platform"
        type            = "STRING"
        assignment_type = "NONE"
      }

      landing_zones = {
        display_name    = "Namespace Landing Zones"
        type            = "STRING"
        assignment_type = "NONE"
      }

      apps_domain = {
        display_name    = "Application Domain"
        type            = "STRING"
        assignment_type = "NONE"
      }

      ingress_ip = {
        display_name    = "Ingress Address"
        type            = "STRING"
        assignment_type = "NONE"
      }

      ingress_class_name = {
        display_name    = "Ingress Class"
        type            = "STRING"
        assignment_type = "NONE"
      }

      cluster_issuer_name = {
        display_name    = "Cluster Issuer"
        type            = "STRING"
        assignment_type = "NONE"
      }

      kubeconfig = {
        display_name    = "Kubeconfig"
        type            = "STRING"
        assignment_type = "NONE"
        is_sensitive    = true
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.110.0"
    }
  }
}
