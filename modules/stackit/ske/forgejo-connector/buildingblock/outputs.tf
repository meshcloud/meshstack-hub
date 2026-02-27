output "summary" {
  description = "Summary of the Forgejo Actions connector setup."
  sensitive   = true
  value       = <<-EOT
# ✅ Forgejo Actions Connector Configured

**${var.repository_name}** is now connected to SKE namespace **${var.namespace}**.

## What was set up

- Kubernetes service account `forgejo-actions` in namespace `${var.namespace}`
- Role binding granting `edit` permissions in the namespace
- `KUBECONFIG` secret stored in the Forgejo repository for use in Actions workflows
${var.harbor != null ? "- `HARBOR_URL`, `HARBOR_USERNAME`, `HARBOR_TOKEN` secrets stored in the Forgejo repository\n- `harbor-pull-secret` created in namespace `${var.namespace}` for image pulls" : ""}

## Next Steps

1. Create a `.forgejo/workflows/deploy.yml` in your repository
2. Use the `KUBECONFIG` secret to authenticate with the SKE cluster:
   ```yaml
   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - name: Deploy to SKE
           env:
             KUBECONFIG_DATA: $${secrets.KUBECONFIG}
           run: |
             echo "$KUBECONFIG_DATA" > /tmp/kubeconfig
             kubectl --kubeconfig /tmp/kubeconfig apply -f k8s/
   ```
${var.harbor != null ? "3. Use Harbor secrets to push container images:\n   ```yaml\n   - name: Push to Harbor\n     run: |\n       echo \"$${secrets.HARBOR_TOKEN}\" | docker login $${secrets.HARBOR_URL} -u \"$${secrets.HARBOR_USERNAME}\" --password-stdin\n       docker push $${secrets.HARBOR_URL}/registry/$${your-app}:latest\n   ```" : ""}
EOT
}
