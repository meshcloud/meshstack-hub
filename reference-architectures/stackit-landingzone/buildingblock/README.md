---
name: STACKIT Landing Zone
supportedPlatforms:
  - stackit
description: Onboards a STACKIT sandbox platform into meshStack (location, resourcemanager folder and STACKIT Project platform with its default landing zone), and optionally layers on a hub-and-spoke network topology.
---

This building block bootstraps a complete STACKIT sandbox platform integration inside a meshStack
workspace. It creates a meshStack location, a dedicated STACKIT resourcemanager folder and a
foundation project hosting the landing-zone core assets, then sources the
[`modules/stackit`](../../../modules/stackit) project integration to provision the STACKIT Project
platform together with its default landing zone.

When a `network` object is supplied, it additionally composes two more Hub modules into the same
offering: it registers [`modules/stackit/network-area`](../../../modules/stackit/network-area) and
immediately orders one instance of it as the hub address plan, and registers
[`modules/stackit/network`](../../../modules/stackit/network) so application teams can self-service
order routed spoke networks inside their STACKIT projects. New STACKIT projects are then placed in
the hub's network area through an additional `networked` project definition and landing zone, which
set the network area as a static label on the project. Leaving `network` unset (`null`) deploys only
the sandbox landing zone.

It always registers [`modules/stackit/stackit-project-starterkit`](../../../modules/stackit/stackit-project-starterkit),
[`modules/stackit/service-account`](../../../modules/stackit/service-account) and
[`modules/stackit/service-account-federation`](../../../modules/stackit/service-account-federation).
The summary shows the platform ref, the landing zone refs and the version refs of the two service
account definitions as a code block. You paste it into a composing architecture such as the STACKIT
Kubernetes Platform, so that architecture can build on this one without reading this building block.

It authenticates to STACKIT with a service account key you paste as a secret input. You also
provide the STACKIT organization UUID, owner email, nested integration tags and default role mapping
as user inputs. The service account needs `resource-manager.admin` on the organization. The nested
integrations are pinned to the same `git_ref` as this building block's implementation.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

Its variables are declared in [`variables.tf`](variables.tf).
