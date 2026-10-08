---
name: T Cloud Public Landing Zone
supportedPlatforms:
  - otc
description: Onboards a T Cloud Public (Open Telekom Cloud) domain into meshStack — backplane IAM user, the T Cloud Public Project platform with its default landing zone, a management project, and optionally federated sign-in.
---

This building block bootstraps a T Cloud Public platform integration inside a meshStack workspace.
It creates a meshStack location and sources the [`modules/otc`](../../../modules/otc) integration,
which creates the backplane IAM user, optionally federates the company identity provider, and
registers the T Cloud Public Project platform with its default landing zone. It then creates the
management meshProject and its tenant on that platform, and, with an identity provider, orders the
[`modules/otc/federation-mapping`](../../../modules/otc/federation-mapping) building block on it.

It authenticates to T Cloud Public with an access key and secret key you paste as secret inputs.
Their IAM user needs to be in the domain's `admin` group. The nested integration is pinned to the
same `git_ref` as this building block's implementation.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

Its variables are declared in [`variables.tf`](variables.tf).
