# STACKIT Kubernetes Platform — Building Block

Terraform for the importable **STACKIT Kubernetes Platform** reference architecture. Ordered on top
of a deployed STACKIT Landing Zone, it bootstraps the whole platform: a self-hosted STACKIT project
and its service account, an SKE cluster, in-cluster ingress (cert-manager, HAProxy and a Let's
Encrypt ClusterIssuer), the meshStack replicator and metering identities, a DNS zone, a STACKIT Model
Serving token, a STACKIT Git instance, a container registry, and the meshStack SKE platform with one
landing zone per stage.

Ingress and the meshStack identities come from `modules/kubernetes/*` and know nothing about SKE.

It also **registers building block definitions of its own** — `ske/cluster`, `stackit/git`,
`stackit/container-registry`, `stackit/dns`, `stackit/ai-llm`, `kubernetes/ingress` and `kubernetes`
on every run, and `stackit/git-repository`, `ske/forgejo-connector` and `ske/ske-starterkit` once
`harbor_username` names the Harbor bootstrap robot. It orders the landing zone's STACKIT Service
Account definition, named in the `landingzone` input, and then the landing zone's STACKIT Service
Account Federation definition as its child, listing its STACKIT definitions in `federated_building_block_definitions`.
Their runs act as that account through workload identity federation.

The architecture itself (overview, diagram, the order and its one update, shared responsibilities)
lives in the [reference architecture README](../README.md). Registration into meshStack is in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

Its variables are declared in [`variables.tf`](variables.tf).
