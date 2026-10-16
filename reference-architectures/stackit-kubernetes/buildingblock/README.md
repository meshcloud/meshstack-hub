# STACKIT Kubernetes Platform — Building Block

Terraform for the outer run of the importable **STACKIT Kubernetes Platform** reference
architecture. It holds no STACKIT credential and declares no `stackit` provider. It creates:

- the meshProject and its tenant, which is the platform's STACKIT project, with the owners and
  managers of the workspace as Project Admins,
- the **Automation Identity**, from the landing zone's STACKIT Service Account definition,
- the **Bootstrap Identity Federation**, its child, trusting only the nested **STACKIT Kubernetes
  Platform Services** definition,
- one **Platform Services** building block from that definition. Its run is in
  [`../platform/buildingblock`](../platform/buildingblock/README.md).

`imports.project` takes over the existing meshProject and its tenant. The architecture and adoption
are in the [reference architecture README](../README.md), the internals in
[`../IMPLEMENTATION_DETAILS.md`](../IMPLEMENTATION_DETAILS.md), the registration in
[`../meshstack_integration.tf`](../meshstack_integration.tf), and the variables in
[`variables.tf`](variables.tf).
