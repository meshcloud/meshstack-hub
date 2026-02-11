output "dev_project_name" {
  description = "Name of the development project"
  value       = meshstack_project.dev.metadata.name
}

output "prod_project_name" {
  description = "Name of the production project"
  value       = meshstack_project.prod.metadata.name
}

output "dev_subaccount_id" {
  description = "Platform tenant ID of the dev subaccount"
  value       = meshstack_tenant_v4.dev.spec.platform_tenant_id
}

output "prod_subaccount_id" {
  description = "Platform tenant ID of the prod subaccount"
  value       = meshstack_tenant_v4.prod.spec.platform_tenant_id
}

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value       = <<-EOT
# SAP BTP Starterkit

✅ **Your SAP BTP environment is ready!**

This starter kit has set up the following resources in workspace `${var.workspace_identifier}`:

## Projects and Subaccounts

**Development Environment:**
@project[${meshstack_project.dev.metadata.owned_by_workspace}.${meshstack_project.dev.metadata.name}]
  └─ @tenant[${meshstack_tenant_v4.dev.metadata.uuid}]
      ├─ @buildingblock[${meshstack_building_block_v2.entitlements_dev.metadata.uuid}]${var.enable_cloudfoundry ? "\n      └─ @buildingblock[${meshstack_building_block_v2.cloudfoundry_dev[0].metadata.uuid}]" : ""}

**Production Environment:**
@project[${meshstack_project.prod.metadata.owned_by_workspace}.${meshstack_project.prod.metadata.name}]
  └─ @tenant[${meshstack_tenant_v4.prod.metadata.uuid}]
      ├─ @buildingblock[${meshstack_building_block_v2.entitlements_prod.metadata.uuid}]${var.enable_cloudfoundry ? "\n      └─ @buildingblock[${meshstack_building_block_v2.cloudfoundry_prod[0].metadata.uuid}]" : ""}

---

## What's Included

### Entitlements
${var.entitlements}

${var.enable_cloudfoundry ? "### Cloud Foundry\n- Plan: ${var.cloudfoundry_plan}\n- Dev Services: ${var.cf_services_dev != "" ? var.cf_services_dev : "None"}\n- Prod Services: ${var.cf_services_prod != "" ? var.cf_services_prod : "None"}" : ""}

---

## Access Your Subaccounts

- **Dev Subaccount**: View in meshStack tenant overview
- **Prod Subaccount**: View in meshStack tenant overview

You can access the SAP BTP Cockpit directly from the tenant details page.

---

## Next Steps

### 1. Deploy Applications
${var.enable_cloudfoundry ? "- Use `cf push` to deploy applications to Cloud Foundry\n- Configure services and bindings in the BTP Cockpit" : "- Configure your application services in the BTP Cockpit\n- Set up subscriptions if needed"}

### 2. Manage Access
Invite team members via meshStack:
- [Dev Access](#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/access-management/role-mapping/overview)
- [Prod Access](#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/access-management/role-mapping/overview)

### 3. Monitor Resources
- View entitlements and usage in BTP Cockpit
- Check building block status in meshStack
- Monitor costs per project in meshStack

---

🎉 Happy developing on SAP BTP!
EOT
}
