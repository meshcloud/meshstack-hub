output "subaccount_id" {
  description = "The ID of the created subaccount"
  value       = btp_subaccount.subaccount.id
}

output "subaccount_region" {
  description = "The region of the subaccount"
  value       = btp_subaccount.subaccount.region
}

output "subaccount_name" {
  description = "The name of the subaccount"
  value       = btp_subaccount.subaccount.name
}

output "subaccount_subdomain" {
  description = "The subdomain of the subaccount"
  value       = btp_subaccount.subaccount.subdomain
}

output "subaccount_login_link" {
  description = "Link to the subaccount in the SAP BTP cockpit"
  value       = "https://emea.cockpit.btp.cloud.sap/cockpit#/globalaccount/${btp_subaccount.subaccount.parent_id}/subaccount/${btp_subaccount.subaccount.id}"
}
