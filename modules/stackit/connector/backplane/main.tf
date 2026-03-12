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