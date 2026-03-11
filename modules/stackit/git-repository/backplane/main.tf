# Validate that the API token is operational by checking the STACKIT Git API
resource "null_resource" "validate_token" {
  triggers = {
    base_url = var.forgejo_base_url
    token    = sha256(var.forgejo_token)
  }

  provisioner "local-exec" {
    command = <<-EOT
      response=$(curl -s -o /dev/null -w "%\{http_code\}" \
        -H "Authorization: token ${var.forgejo_token}" \
        "${var.forgejo_base_url}/api/v1/user")

      if [ "$response" -ne 200 ]; then
        echo "ERROR: STACKIT Git API token validation failed (HTTP $response)"
        echo "Please verify the token has the required scopes: read:user, write:repository, write:organization"
        exit 1
      fi

      echo "STACKIT Git API token validated successfully"
    EOT
  }
}
