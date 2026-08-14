---
name: STACKIT Kubernetes Cluster
supportedPlatforms:
  - stackit
description: Creates an SKE cluster in a tenant's STACKIT project, installs cert-manager and the HAProxy ingress controller on it, and registers it in meshStack as a Kubernetes platform with namespace landing zones.
---

This building block composes four Hub modules into one orderable unit:

- [`modules/stackit/ske`](../../../modules/stackit/ske) creates the SKE cluster and its kubeconfig.
- [`modules/kubernetes/platform`](../../../modules/kubernetes/platform) registers the cluster in
  meshStack as a platform of type `kubernetes` and creates the namespace landing zones.
- [`modules/kubernetes/ingress`](../../../modules/kubernetes/ingress) installs cert-manager, the
  HAProxy ingress controller and a Let's Encrypt ClusterIssuer, and issues the wildcard certificate
  for the cluster's own domain inside the shared DNS zone.
- [`modules/stackit/dns`](../../../modules/stackit/dns) writes the cluster's wildcard record set
  into that zone.

The four modules are sourced by Git URL and pinned with `?ref=${var.hub.git_ref}`, so one variable
moves the whole composition to another Hub release.

It is a `TENANT_LEVEL` building block ordered against the STACKIT Project platform, so the cluster
lands in the meshTenant's own STACKIT project. The application team decides two things, the cluster
name and the ingress exposure. Everything else — the Let's Encrypt endpoint, the chart versions, the
issuer name and the ingress class — is a landing-zone concern and arrives as a static input or stays
at the module default.

The four modules run as **one** STACKIT service account, which
[`../meshstack_integration.tf`](../meshstack_integration.tf) creates by calling
[`modules/stackit/ske/backplane`](../../../modules/stackit/ske/backplane). That backplane grants
`ske.admin` on the tenant folder and `dns.admin` on the shared zone's project, which is the whole
set of permissions this composition needs.

The ACME account is registered without a contact address. `acme_email` is passed as `""` in
[`main.tf`](main.tf) and is not an input of this building block — see the architecture README for
why.

[`dns.tf`](dns.tf) holds the whole DNS design: one zone the platform team owns and every cluster
shares, one label per cluster inside it, and the inputs that drive both. Read that file before you
change anything about hostnames or certificates.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

There is no generated terraform-docs section here. terraform-docs cannot parse a module whose
`source` interpolates a variable, and every sibling module is sourced with `?ref=${var.hub.git_ref}`.
Read [`variables.tf`](variables.tf) and [`outputs.tf`](outputs.tf) directly.
