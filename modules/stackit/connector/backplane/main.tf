# BB creates
# - service account with permissions to
#   - manage a "github-image-pull-secret"
#   - manage pods and deployments
#
# BB puts kubeconfig for this SA into Forgejo
#
# Forgejo action workflow uses this SA to
# - update image pull secret
# - deployment
#


# SPN for Terraform state
# TODO

# Container registry
# We're using a shared container registry for all consumers of this building block.
# We have a predefined harbor instance in stackit for it


# The ClusterIssuer is needed so that SSL certificates can be issued for projects using the GitHub Actions Connector.
resource "kubernetes_cluster_role" "clusterissuer_reader" {
  metadata {
    name = "clusterissuer-reader"
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["clusterissuers"]
    verbs      = ["get"]
  }
}