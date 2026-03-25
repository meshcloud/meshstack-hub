terraform {
  required_version = ">= 1.4.0"

  required_providers {
    restapi = {
      source                = "Mastercard/restapi"
      version               = "~> 3.0.0"
      configuration_aliases = [restapi.with_returned_object, restapi.without_returned_object]
    }
  }
}
