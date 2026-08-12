---
name: STACKIT Kubernetes Cluster
supportedPlatforms:
  - stackit
description: Creates an SKE cluster in a tenant's STACKIT project, installs cert-manager and the HAProxy ingress controller on it, and registers it in meshStack as a Kubernetes platform with namespace landing zones.
---

This building block composes three Hub modules into one orderable unit:

- [`modules/stackit/ske`](../../../modules/stackit/ske) creates the SKE cluster and its kubeconfig.
- [`modules/kubernetes/platform`](../../../modules/kubernetes/platform) registers the cluster in
  meshStack as a platform of type `kubernetes` and creates the namespace landing zones.
- [`modules/kubernetes/ingress`](../../../modules/kubernetes/ingress) installs cert-manager, the
  HAProxy ingress controller and a Let's Encrypt ClusterIssuer, and issues the wildcard certificate
  when a DNS subzone is delegated to the cluster.

The three modules are sourced by Git URL and pinned with `?ref=${var.hub.git_ref}`, so one variable
moves the whole composition to another Hub release.

It is a `TENANT_LEVEL` building block ordered against the STACKIT Project platform, so the cluster
lands in the meshTenant's own STACKIT project. The application team decides two things, the cluster
name and the ingress exposure. Everything else — the ACME contact, the Let's Encrypt endpoint, the
chart versions, the issuer name and the ingress class — is a landing-zone concern and arrives as a
static input or stays at the module default.

DNS is the one part that is not complete. [`dns.tf`](dns.tf) holds the whole delegated-subzone
design, including the assumption it rests on and the `modules/stackit/dns` module it still needs.
Read that file before you change anything about hostnames or certificates.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

There is no generated terraform-docs section here. terraform-docs cannot parse a module whose
`source` interpolates a variable, and every sibling module is sourced with `?ref=${var.hub.git_ref}`.
Read [`variables.tf`](variables.tf) and [`outputs.tf`](outputs.tf) directly.
