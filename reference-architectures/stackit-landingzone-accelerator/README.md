---
name: STACKIT Landing Zone Accelerator
description: >
  Deploys the STACKIT Landing Zone Accelerator from a STACKIT Landing Zone Configurator export in
  one meshStack run, and turns its landing zone folders into a meshStack platform whose STACKIT
  Project building block application teams add from the marketplace.
cloudProviders:
  - stackit
buildingBlocks:
  - path: stackit/project
    role: Creates a tenant's STACKIT project in the accelerator folder of its landing zone, with its members' roles.
---

# STACKIT Landing Zone Accelerator

## Overview

The [STACKIT Landing Zone Accelerator](https://github.com/stackitcloud/stackit-landing-zone) builds
a STACKIT foundation: folders, a management project, optional connectivity, DevOps and landing zone
projects. The STACKIT Landing Zone Configurator designs it and exports a tfvars file for the
accelerator's `src/` root.

This reference architecture takes that export as a building block input and applies the
accelerator with exactly these values. On top of the foundation it registers a STACKIT platform in
meshStack with these landing zones:

- **Public** (`<platform identifier>-public`), when the export declares the folder
  `landing_zones_public`.
- **Corporate** (`<platform identifier>-corporate`), when the export declares the folder
  `landing_zones_corporate`.

Application teams add **STACKIT Project** from the marketplace to a tenant on one of them, and get a
project in that folder.

![STACKIT Landing Zone Accelerator](stackit-landingzone-accelerator.svg)

## How It Works

1. The run decodes the pasted export and calls the accelerator's `src/` at the commit given as
   **Accelerator Commit**. The run fails when the export's `Accelerator source` header names
   another commit.
2. The accelerator creates its resources in the organization the export names.
3. The run sources `modules/stackit`. It creates the project-creation service account in the
   accelerator's management project, grants it `resource-manager.admin` and `iam.member-admin` on
   the organization, and registers the platform, its landing zones and the STACKIT Project
   definition.

All of this happens in one apply. The run authenticates as the service account whose key is pasted
into **STACKIT Service Account Key**, which meshStack puts into the environment as
`STACKIT_SERVICE_ACCOUNT_KEY`.

The building block state holds the keys of the service accounts the accelerator creates, so restrict
access to it like a secret.

## Limitations

- Projects on the corporate landing zone are created in the corporate folder, but they are not
  attached to the accelerator's network area.
- The platform has one landing zone per folder, not one per target of the accelerator's
  `platform_contract`. The contract has a public target per region, and all targets of one kind
  share a folder.
- The export may not set firewall credentials, `vpn_pre_shared_keys` or `bucket_naming`. A firewall
  needs a second apply after its bootstrap, which this building block does not run.
- Deleting the building block destroys the whole foundation. Delete the tenant projects first.

## Getting Started

### Prerequisites

- A STACKIT organization and a service account that owns it, with a key in JSON format.
- A tfvars file exported from the STACKIT Landing Zone Configurator for that organization.

### Deploy

1. Register the definition from [`meshstack_integration.tf`](meshstack_integration.tf) in the
   workspace that will own the platform.
2. Order it in that workspace. Paste the export into **Landing Zone tfvars**, set **Accelerator
   Commit** to the commit in its `Accelerator source` line, paste the service account key and
   choose a platform identifier.
3. Once the run succeeds, application teams add **STACKIT Project** to their tenants on the new
   landing zones.

## Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Design the landing zone in the Configurator and paste the export | ✅ | ❌ |
| Provide the organization owner service account key | ✅ | ❌ |
| Deploy the accelerator foundation and the STACKIT platform | ✅ | ❌ |
| Add STACKIT Project from the marketplace to their tenants | ❌ | ✅ |
| Manage workloads inside the provisioned STACKIT projects | ❌ | ✅ |
