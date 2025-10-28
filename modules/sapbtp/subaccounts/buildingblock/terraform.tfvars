parent_id            = "99f8ad5f-255e-46a5-a72d-f6d652c90525"
globalaccount        = "meshcloudgmbh"
workspace_identifier = "sapbtp"
project_identifier   = "testsubaccount"
subfolder            = "test"
users = [
  {
    meshIdentifier = "identifier1"
    username       = "testuser1@likvid.io"
    firstName      = "test"
    lastName       = "user"
    email          = "testuser1@likvid.io"
    euid           = "testuser1@likvid.io"
    roles          = ["admin", "user"]
  },

  {
    meshIdentifier = "identifier2"
    username       = "testuser2@likvid.io"
    firstName      = "test"
    lastName       = "user"
    email          = "testuser2@likvid.io"
    euid           = "testuser2@likvid.io"
    roles          = ["admin"]
  }
]
cloudfoundry_instance = {
  name      = "cf-dev"
  plan_name = "standard"
}
entitlements = [
  {
    service_name = "build-code"
    plan_name    = "free"
  }
]

subscriptions = [
  {
    app_name   = "build-code"
    plan_name  = "free"
    parameters = {}
  }
]
