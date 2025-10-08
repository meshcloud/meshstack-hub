output "datacenter_id" {
  description = "ID of the created IONOS datacenter"
  value       = ionoscloud_datacenter.main.id
}

output "datacenter_name" {
  description = "Name of the created IONOS datacenter"
  value       = ionoscloud_datacenter.main.name
}

output "datacenter_location" {
  description = "Location of the created IONOS datacenter"
  value       = ionoscloud_datacenter.main.location
}

output "dcd_url" {
  description = "Direct URL to access the IONOS DCD datacenter"
  value       = "https://dcd.ionos.com/latest/datacenter/${ionoscloud_datacenter.main.id}"
}

output "user_assignments" {
  description = "Map of users and their assigned roles"
  value = {
    readers = [
      for i, user in local.readers : {
        email   = user.email
        name    = "${user.firstName} ${user.lastName}"
        user_id = ionoscloud_user.readers[i].id
        roles   = user.roles
      }
    ]
    users = [
      for i, user in local.users : {
        email   = user.email
        name    = "${user.firstName} ${user.lastName}"
        user_id = ionoscloud_user.users[i].id
        roles   = user.roles
      }
    ]
    administrators = [
      for i, user in local.administrators : {
        email   = user.email
        name    = "${user.firstName} ${user.lastName}"
        user_id = ionoscloud_user.administrators[i].id
        roles   = user.roles
      }
    ]
  }
}

output "group_memberships" {
  description = "Information about group memberships"
  value = {
    readers_group_id        = length(local.readers) > 0 ? ionoscloud_group.readers[0].id : null
    users_group_id          = length(local.users) > 0 ? ionoscloud_group.users[0].id : null
    administrators_group_id = length(local.administrators) > 0 ? ionoscloud_group.administrators[0].id : null
  }
}