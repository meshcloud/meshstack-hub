# The hub website at hub.meshcloud.io. The build itself is defined by amplify.yml at the repository
# root, which Amplify prefers over the app's own build spec.

import {
  to = aws_amplify_app.hub
  id = "d1o16zfeoh2slu"
}

import {
  to = aws_amplify_branch.main
  id = "d1o16zfeoh2slu/main"
}

import {
  to = aws_amplify_domain_association.hub
  id = "d1o16zfeoh2slu/hub.meshcloud.io"
}

resource "aws_amplify_app" "hub" {
  name       = "meshstack-hub"
  repository = "https://github.com/meshcloud/meshstack-hub"
  platform   = "WEB"

  enable_auto_branch_creation = false
  enable_branch_auto_build    = false
  enable_branch_auto_deletion = false

  environment_variables = {
    AMPLIFY_ENV   = "dev"
    _LIVE_UPDATES = jsonencode([{ name = "Node.js version", pkg = "node", type = "nvm", version = "22" }])
  }

  # The website is a single-page app; every unknown path is a client-side route.
  custom_rule {
    source = "/<*>"
    target = "/index.csr.html"
    status = "404-200"
  }

  cache_config {
    type = "AMPLIFY_MANAGED"
  }
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.hub.id
  branch_name = "main"
  stage       = "PRODUCTION"
  framework   = "Web"

  enable_auto_build           = true
  enable_pull_request_preview = true

  environment_variables = {
    AMPLIFY_ENV = "prod"
  }
}

resource "aws_amplify_domain_association" "hub" {
  app_id                = aws_amplify_app.hub.id
  domain_name           = "hub.meshcloud.io"
  wait_for_verification = false

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = ""
  }
}
