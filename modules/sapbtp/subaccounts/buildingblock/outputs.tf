output "btp_subaccount_id" {
  value = btp_subaccount.subaccount.id
}

output "btp_subaccount_region" {
  value = btp_subaccount.subaccount.region
}

output "btp_subaccount_name" {
  value = btp_subaccount.subaccount.name
}

output "btp_subaccount_login_link" {
  value = "https://emea.cockpit.btp.cloud.sap/cockpit#/globalaccount/${btp_subaccount.subaccount.parent_id}/subaccount/${btp_subaccount.subaccount.id}"
}
