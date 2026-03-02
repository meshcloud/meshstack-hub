# harbor project
resource "harbor_project" "harbor_project" {
  name                        = var.harbor_project_id
  public                      = false
  vulnerability_scanning      = true
  enable_content_trust        = true
  enable_content_trust_cosign = false
  auto_sbom_generation        = true
}

# robot account for forgejo
resource "harbor_robot_account" "forgejo_robot" {
  name  = "forgejo_robot-${harbor_project.harbor_project.name}"
  level = "project"
  permissions {
    access {
      action   = "pull"
      resource = "repository"
    }
    access {
      action   = "push"
      resource = "repository"
    }
    kind      = "project"
    namespace = harbor_project.harbor_project.name
  }
}

# robot account for k8s
resource "harbor_robot_account" "k8s_image_pull_robot" {
  name  = "k8s_image_pull_robot-${harbor_project.harbor_project.name}"
  level = "project"
  permissions {
    access {
      action   = "pull"
      resource = "repository"
    }
    kind      = "project"
    namespace = harbor_project.harbor_project.name
  }
}

# k8s service account for forgejo action
module "k8s_service_account" {
  source                 = "github.com/meshcloud/meshstack-hub//modules/kubernetes/service-account?ref=main"
  name                   = var.sa_name
  namespace              = var.namespace
  cluster_role           = var.sa_cluster_role
  cluster_ca_certificate = var.cluster_ca_certificate
  cluster_endpoint       = var.cluster_endpoint
  token                  = var.token
  context                = var.context
}