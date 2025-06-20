locals {
  resource_group_name = var.spoke_rg_name
}

resource "terraform_data" "reset_test_env" {
  provisioner "local-exec" {
    command = <<EOF
# Check if the resource group exists
group_exists=$(az group exists --subscription "${var.subscription_id}" --name "${local.resource_group_name}")

# If the resource group exists, delete it
if [ "$group_exists" = "true" ]; then
  az group delete --subscription "${var.subscription_id}" --name "${local.resource_group_name}" --yes
else
  echo "Resource group '${local.resource_group_name}' does not exist, nothing to clean up."
fi
    EOF
  }
}

# note: we declare these variables inline and they follow the same name as the bb module variables

variable "spoke_rg_name" {
  type = string
}

variable "subscription_id" {
  type = string
}