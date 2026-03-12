data "http" "org_lookup" {
  url = "${var.forgejo_base_url}/api/v1/orgs/${var.forgejo_organization}"
  request_headers = {
    Authorization = "token ${var.forgejo_token}"
    Accept        = "application/json"
  }
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Forgejo organization '${var.forgejo_organization}' does not exist or token has insufficient permissions."
    }
  }
}
