---
name: STACKIT Landing Zone
description: >
  Bootstraps a self-service-ready STACKIT platform: a dedicated STACKIT resourcemanager folder,
  a foundation project with a service account, and the STACKIT Project platform with a default
  landing zone. Three optional layers stack on top of it — hub-and-spoke networking, a Kubernetes
  platform whose landing zones promise namespaces and a working HTTPS hostname, and an AI platform
  installed into a cluster ordered through that Kubernetes layer.
cloudProviders:
  - stackit
buildingBlocks:
  - path: stackit/project
    role: Provisions a STACKIT Project with role assignments.
  - path: stackit/network-area
    role: (Optional) Provisions the hub network area with the shared IPv4 address plan.
  - path: stackit/network
    role: (Optional) Lets application teams self-service order routed spoke networks inside their projects.
  - path: stackit/dns
    role: (Optional) Holds the one DNS zone every ordered cluster shares, and the credential that writes records into it.
  - path: stackit/ske
    role: (Optional) Creates the SKE cluster an application team orders, via the stackit-kubernetes reference architecture.
  - path: kubernetes/ingress
    role: (Optional) Installs cert-manager, the HAProxy ingress controller and the cluster's wildcard certificate.
  - path: kubernetes/platform
    role: (Optional) Registers each ordered cluster in meshStack as a Kubernetes platform with namespace landing zones.
  - path: ai/litellm
    role: (Optional) The model gateway the AI layer installs, holding the virtual keys, the budgets and the model allow-lists.
  - path: ai/clickhouse
    role: (Optional) The shared trace storage the AI layer installs once into the cluster.
  - path: ai/model-access
    role: (Optional) The tenant-facing block the AI landing zones make mandatory, so model access arrives with the project.
---

# STACKIT Landing Zone

## Overview

The **STACKIT Landing Zone** reference architecture turns a bare STACKIT organization into a
self-service-ready meshStack platform in one step using its own Terraform code.

The **always-on** foundation is a sandbox landing zone: a dedicated STACKIT resourcemanager
folder, a foundation project hosting the project-creation service account, and the **STACKIT
Project** platform with its default landing zone. Application teams can immediately request
STACKIT projects against it.

Three **optional layers** stack on top of that foundation. Each is enabled by providing one JSON
object as an input of the same building block, and each builds on the one before it. Leaving all
three unset deploys only the sandbox foundation.

| Option | What it adds | Builds on |
|---|---|---|
| `network` | A shared network-area address plan (the hub) that all tenant projects draw from, and a self-service routed-network building block (the spoke) application teams order inside their own projects | the sandbox foundation |
| `kubernetes` | The one DNS zone every cluster shares, and the **STACKIT Kubernetes Cluster** building block an application team orders on its own STACKIT project to get a cluster, an HTTPS ingress and a Kubernetes platform with namespace landing zones | the sandbox foundation |
| `ai` | The **AI Platform** — the LiteLLM gateway, the shared trace storage, the `AI-MODEL` platform type and the AI landing zones — installed into a cluster ordered through the `kubernetes` option | `kubernetes` |

The `kubernetes` and `ai` options are the point at which this architecture stops composing *modules*
and starts composing *architectures*: they source
[`stackit-kubernetes`](../stackit-kubernetes) and [`ai-platform`](../ai-platform) — their
`meshstack_integration.tf` files — as Terraform modules, the same way the `network` option already
sources `modules/stackit/network-area`. `ai-platform` is the first reference architecture in this
repository consumed as a component by another one.

**Target audience:**

- **Platform engineers** onboarding a new STACKIT organization into meshStack who want a sandbox
  environment application teams can request projects from immediately — optionally with network
  segmentation, self-service Kubernetes and governed model access from day one, without hand-wiring
  a network area, a DNS zone or a gateway separately.
- **Application teams** who need a dedicated IPv4 subnet inside their STACKIT project without
  manually coordinating CIDR ranges with the platform team (when networking is enabled), a
  Kubernetes cluster of their own with working HTTPS (when the Kubernetes option is enabled), or a
  governed model endpoint that arrives with the project (when the AI option is enabled).

## Architecture Diagram

The left half of the diagram is the **STACKIT resource hierarchy** — the organization, the
resourcemanager folder tenant projects land in, the foundation project holding the project-creation
service account, and the org-level network area. The right half is **meshStack**: the platform, its
landing zones and the building block **definitions** (BBDs). Dotted edges across the boundary show
how each meshStack construct maps onto a STACKIT one. Definitions (blue) are registered once;
**instances** (green) are ordered against them — the hub network area and the AI platform are single
instances the platform team orders, while STACKIT projects, spoke networks and clusters are ordered
`N` times by application teams. Each node is labelled with the option that brings it.

![STACKIT Landing Zone reference architecture](stackit-landingzone.svg)

When networking is enabled, application teams order a routed network into their own project via the
self-service `stackit/network` building block; each order draws its subnet from the hub's address
plan, so no two spokes can accidentally collide on CIDR ranges.

## How It Works

Running this reference architecture always:

1. Creates a **STACKIT resourcemanager folder** under the given organization — new STACKIT
   projects are created inside this folder.
2. Creates a **STACKIT foundation project** directly under the organization to host the
   project-creation service account and other landing-zone core assets.
3. Sources the [`modules/stackit`](../../modules/stackit) platform integration to register the
   **STACKIT Project** platform and its default landing zone in meshStack, wired to the foundation
   service account.

When a **network** configuration is provided, it additionally:

4. Registers the [`stackit/network-area`](../../modules/stackit/network-area) building block
   definition and immediately orders **one instance** of it in the platform team's own workspace —
   this is the hub's IPv4 address plan.
5. Registers the [`stackit/network`](../../modules/stackit/network) building block definition
   (`TENANT_LEVEL`) so application teams can self-service order routed networks (spokes) inside
   their STACKIT projects, drawing from the hub's address plan.
6. Provisions an additional **networked project definition and landing zone**. The networked
   `STACKIT Project` building block definition carries the hub's network area ID as a static
   `networkArea` label, so new STACKIT projects created against that landing zone are placed in the
   hub's network area.

When a **kubernetes** configuration is provided, it additionally:

7. Creates **the one DNS zone** every ordered cluster shares, in the foundation project, together
   with a service account holding `dns.admin` on that project and a key for it. See
   [The shared DNS zone](#the-shared-dns-zone) below for why the zone is created here and never by
   an ordered cluster.
8. Sources [`stackit-kubernetes`](../stackit-kubernetes) — the reference architecture, not a module —
   and registers its `TENANT_LEVEL` **STACKIT Kubernetes Cluster** building block definition. The
   zone's name, the project that owns it and the DNS key go in as **static** inputs, exactly as the
   hub network area's id does on the network path. An application team then orders a cluster on one
   of its STACKIT projects and receives an SKE cluster, an HTTPS ingress and a Kubernetes platform
   whose landing zones hand out namespaces.

When an **ai** configuration is provided, it additionally:

9. Sources [`ai-platform`](../ai-platform), registering the `AI-MODEL` platform type and the
   **AI Platform** building block definition with the whole configuration as static inputs, and
   **orders it once** in this workspace — the same register-then-order handoff the hub network area
   uses. That order installs the LiteLLM gateway and the shared ClickHouse into the named cluster,
   registers the gateway as a meshStack platform and creates the AI landing zones, each with
   `ai/model-access` in `mandatory_building_block_refs`.

### The shared DNS zone

A landing zone that promises namespaces is not enough; the promise is a namespace **and a working
HTTPS hostname**. That needs DNS, and DNS on STACKIT constrains the design:

- **A free STACKIT subdomain is one label deep.** `stackit.run`, `runs.onstackit.cloud`,
  `stackit.rocks`, `stackit.gg` and `stackit.zone` all admit exactly one label. Creating
  `cluster1.likvid.stackit.run` as a zone fails against the live API with *"subdomain should only
  have one level"* — in every project, and even with a correct NS delegation already in place. A
  delegated subzone per cluster was tested and rejected.
- **So there is one zone, and it is created once.** The `kubernetes` option creates it, in the
  foundation project, and passes its name, its project and the DNS credential into the cluster
  building block definition as static inputs. **The ordered cluster never creates a zone.** The zone
  and its credential come from [`modules/stackit/dns/buildingblock/zone`](../../modules/stackit/dns),
  the provider-free submodule of the DNS building block — this architecture holds a service account
  key rather than a workload identity token, so it configures the STACKIT provider itself and calls
  the submodule that declares none.
- **Each cluster takes a label inside it.** `dns_cluster_label_enabled` is on by default, so cluster
  `cluster1` writes the record set `*.cluster1` into the shared zone and holds a wildcard certificate
  for `*.cluster1.<zone>`. Turning it off puts a cluster's wildcard at the zone apex, which only one
  cluster per zone can hold.

The residual trade-off is documented rather than hidden: **the DNS credential is zone-wide.**
`dns.admin` is a project role and cannot be narrowed to one zone, let alone to one label, so a
cluster *could* write records outside its own label. What keeps clusters inside their label is the
building block code, not the credential — a code-enforced boundary, not a permission boundary.

### The identity provider is passed through

The AI platform's identity provider stays **generic**. `ai-platform` takes the issuer, the client id,
the client secret and the claim mapping as plain inputs and names no provider, and this option
forwards them unchanged rather than naming one, because nothing in this repository names a concrete
IdP to name.

One accepted risk travels with them and is worth reading before filling the fields in:
`ai/model-access` takes `oidc` as a single static input, so every tenant's Langfuse instance trusts
the *same* client while `langfuse_default_org_role` defaults to `MEMBER`. With
`LANGFUSE_DEFAULT_ORG_ID` set, anyone the provider authenticates becomes a member of whichever
instance they open. Register one OIDC client per tenant, or set `langfuse_default_org_role` to
`NONE`, if that is not wanted.

## Getting Started

### Prerequisites

| Requirement          | Description                                                                       |
|----------------------|-----------------------------------------------------------------------------------|
| STACKIT organization | With a service account key that has `resource-manager.admin` on the organization. With the Kubernetes option it also creates a DNS zone, a service account and a key in the foundation project — which it created itself. |
| CIDR plan            | *(Only when enabling networking)* A non-overlapping IPv4 address plan chosen up front for the hub network ranges and transfer network. |
| DNS zone name        | *(Only when enabling Kubernetes)* A free STACKIT subdomain the platform team owns, for example `likvid.stackit.run`, one label deep. |
| Model backends       | *(Only when enabling AI)* STACKIT AI Model Serving, Azure OpenAI or any OpenAI-compatible endpoint, with a credential for each. |
| Shared AI backends   | *(Only when enabling AI)* A PostgreSQL Flex instance, a Valkey instance and an object storage admin credential. The architecture creates databases and buckets inside them and never the instances. |
| Identity provider    | *(Only when enabling AI)* An OIDC client — issuer, client id and client secret. Every tenant's tracing instance has a callback URL of its own, so the client needs each as a redirect URI or a wildcard. |

### Deployment Order

1. Order the **STACKIT Landing Zone** building block once per workspace. Without any option it
   creates the platform and default landing zone; application teams can request STACKIT projects
   immediately.
2. *(Optional)* Add a **network** configuration. The same apply creates the hub network area
   instance, the networked project definition and landing zone, and registers the spoke
   `stackit/network` building block application teams order inside their own projects.
3. *(Optional)* Add a **kubernetes** configuration naming the shared DNS zone. The same apply creates
   the zone and its credential and registers the **STACKIT Kubernetes Cluster** building block.
4. *(Only for the AI option)* Order one cluster through that building block — the platform team's
   own — and note its name and its `kubeconfig` output.
5. *(Optional)* Add an **ai** configuration carrying that cluster's name and kubeconfig, the model
   backends, the shared Postgres, Valkey and object storage credentials and the OIDC client. The same
   apply registers the AI Platform and orders it, and publishing the AI landing zones is the last
   step.

## Shared Responsibilities

| Responsibility                                                                | Platform Team | Application Team |
|-------------------------------------------------------------------------------|:---:|:---:|
| Provision the STACKIT platform and default landing zone                       | ✅ | ❌ |
| *(Optional)* Provision the hub network area and choose its address plan       | ✅ | ❌ |
| *(Optional)* Register the spoke `stackit/network` building block              | ✅ | ❌ |
| *(Optional)* Own the shared DNS zone and the key its records are written with | ✅ | ❌ |
| *(Optional)* Register the `STACKIT Kubernetes Cluster` building block         | ✅ | ❌ |
| *(Optional)* Provide the model backends, their credentials and the identity provider | ✅ | ❌ |
| *(Optional)* Provide the shared Postgres, Valkey and object storage the AI platform uses | ✅ | ❌ |
| *(Optional)* Define the AI landing zones: allowed models, budget and budget period | ✅ | ❌ |
| Request STACKIT projects through the landing zone                             | ❌ | ✅ |
| *(Optional)* Order spoke networks inside their STACKIT projects               | ❌ | ✅ |
| *(Optional)* Order a cluster and choose its name and ingress exposure         | ❌ | ✅ |
| *(Optional)* Order namespaces on the resulting Kubernetes platform            | ❌ | ✅ |
| *(Optional)* Order projects in an AI landing zone and stay within the budget  | ❌ | ✅ |
| Use the assigned subnet and manage workloads inside their projects            | ❌ | ✅ |
