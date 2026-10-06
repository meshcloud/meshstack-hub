terraform {
  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 3.0.0, < 4.0.0"
      # Forgejo answers the membership PUT with 204 No Content.
      configuration_aliases = [restapi.without_returned_object]
    }
  }
}
