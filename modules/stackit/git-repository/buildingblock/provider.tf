provider "restapi" {
  uri                  = var.forgejo_base_url
  write_returns_object = true

  headers = {
    Authorization = "token ${var.forgejo_token}"
    Content-Type  = "application/json"
  }
}
