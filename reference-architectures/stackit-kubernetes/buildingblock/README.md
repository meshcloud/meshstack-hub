# STACKIT Kubernetes Platform — Building Block

Terraform for the importable **STACKIT Kubernetes Platform** reference architecture. Ordered on top
of a deployed STACKIT Landing Zone, it bootstraps what the rest of the platform needs to run as one
STACKIT identity, and then orders the rest as one nested building block.

This outer run holds no STACKIT credential and declares no `stackit` provider. It creates:

- the meshProject and a self-hosted meshStack tenant, which is the STACKIT project the platform runs
  in, with the owners and managers of the workspace as Project Admins,
- the **Automation Identity**, ordered from the landing zone's STACKIT Service Account definition,
- the **Bootstrap Identity Federation**, ordered from the landing zone's STACKIT Service Account
  Federation definition as its child. It trusts only the one definition this run registers, the
  nested **STACKIT Kubernetes Platform Services** definition,
- one **Platform Services** building block, ordered from that definition. Its run is in
  [`../platform/buildingblock`](../platform/buildingblock/README.md) and creates everything else,
  the platform's Secrets Manager included.

Its summary is the summary of the Platform Services building block.

The architecture itself (overview, diagrams, the order and its one update, shared responsibilities)
lives in the [reference architecture README](../README.md). Registration into meshStack is in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

Its variables are declared in [`variables.tf`](variables.tf).
