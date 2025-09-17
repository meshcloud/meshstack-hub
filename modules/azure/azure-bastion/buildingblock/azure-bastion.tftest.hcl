run "valid_bastion_configuration" {
  variables {
    name                     = "test-bastion"
    location                 = "West Europe"
    resource_group_name      = "rg-test"
    vnet_name                = "vnet-test"
    vnet_resource_group_name = "rg-test"
    bastion_subnet_cidr      = "10.0.1.0/27"
    bastion_sku              = "Basic"
    enable_resource_locks    = false
    enable_observability     = true

    tags = {
      Environment = "Test"
      Purpose     = "Bastion Testing"
    }
  }
}

run "invalid_bastion_subnet_cidr" {
  command = plan

  variables {
    name                     = "test-bastion"
    location                 = "West Europe"
    resource_group_name      = "rg-test"
    vnet_name                = "vnet-test"
    vnet_resource_group_name = "rg-test"
    bastion_subnet_cidr      = "invalid-cidr"
    bastion_sku              = "Basic"
  }

  expect_failures = [
    var.bastion_subnet_cidr,
  ]
}

run "invalid_bastion_sku" {
  command = plan

  variables {
    name                     = "test-bastion"
    location                 = "West Europe"
    resource_group_name      = "rg-test"
    vnet_name                = "vnet-test"
    vnet_resource_group_name = "rg-test"
    bastion_subnet_cidr      = "10.0.1.0/27"
    bastion_sku              = "Premium"
  }

  expect_failures = [
    var.bastion_sku,
  ]
}

run "standard_sku_configuration" {
  command = plan

  variables {
    name                     = "test-bastion-standard"
    location                 = "West Europe"
    resource_group_name      = "rg-test"
    vnet_name                = "vnet-test"
    vnet_resource_group_name = "rg-test"
    bastion_subnet_cidr      = "10.0.1.0/27"
    bastion_sku              = "Standard"
    enable_resource_locks    = false
    enable_observability     = false
  }
}
