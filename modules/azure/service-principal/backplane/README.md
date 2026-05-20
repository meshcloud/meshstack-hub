# Azure Service Principal Building Block — Backplane

This documentation is intended as a reference for platform engineers deploying the Service Principal Building Block backplane.

## Overview

The backplane provisions the automation identity and permissions required to deploy Azure AD service principals on behalf of application teams.

It creates:
- A custom Azure RBAC role definition with the minimum permissions required to deploy service principal building blocks
- Role assignments for the automation identity (service principal or existing principals)
- Microsoft Graph API application permission grant (`Application.ReadWrite.OwnedBy`) — requires admin consent in Azure AD

## Required Permissions

### Azure RBAC Role

The backplane creates a custom role definition and assigns it to the automation principal. The role grants permissions to manage Azure resources (e.g. resource group and role assignment operations) needed during building block deployment.

### Microsoft Graph API Permissions

The automation principal requires the following Microsoft Graph API application permission:

| Permission | Description |
|------------|-------------|
| `Application.ReadWrite.OwnedBy` | Allows the app to create other applications and service principals, and fully manage those applications (read, update, delete). It cannot update applications it does not own. |

> **Note:** `Application.ReadWrite.OwnedBy` requires admin consent in Azure AD before the backplane can function.

## Operational Notes

- The backplane must be deployed once per platform team before any building block instances can be created.
- Admin consent for the Graph API permission must be granted manually in the Azure portal or via the Azure CLI.
- The automation principal identity output (`identity`) is consumed by `meshstack_integration.tf` to wire the building block definition.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
