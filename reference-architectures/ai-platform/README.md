---
name: AI Platform
description: >
  An opinionated, one-click AI platform: the LiteLLM gateway and a shared ClickHouse deployed into a
  Kubernetes cluster, with LiteLLM registered as a meshStack platform so a project that lands in an
  AI landing zone receives a governed model endpoint, a budget and a tracing instance of its own
  without ordering anything. The cluster comes from the stackit-kubernetes reference architecture;
  the model backends are whatever the platform team registers behind the gateway.
cloudProviders:
  - stackit
  - azure
buildingBlocks:
  - path: ai/litellm
    role: The gateway, deployed once. It holds the virtual keys, the budgets and the model allow-lists, and it hides the shape of the model backends from every tenant.
  - path: ai/clickhouse
    role: The shared trace storage, deployed once per cluster. Every tenant gets a database and a user of its own inside it.
  - path: ai/langfuse
    role: One tracing instance per tenant, deployed by the model access block when a tenant is created.
  - path: ai/model-access
    role: The one tenant-facing block. The AI landing zone makes it mandatory, so it creates the team, the virtual key, the per-tenant backends and the tracing instance without asking the application team anything.
  - path: stackit/postgresflex
    role: The shared PostgreSQL Flex instance behind the gateway and every tracing instance. The architecture creates databases inside it and never the instance.
  - path: stackit/model-serving
    role: Issues the STACKIT AI Model Serving token the platform team registers as a model backend on the gateway.
  - path: ai/azure-openai
    role: Registers an Azure OpenAI deployment as a model backend, the Azure counterpart to stackit/model-serving.
---

# AI Platform

## Overview

Three questions hold back enterprise AI adoption, and a raw model endpoint answers none of them:
*who may call which model*, *what did it cost*, and *what exactly was sent and returned*. This
reference architecture answers them with opinionated defaults rather than a toolkit: one order
installs the gateway and the shared trace storage and turns model access into a property of a
landing zone.

The architecture consumes a Kubernetes cluster and does not provision one. The cluster, its ingress
with TLS and the namespace landing zone come from [`stackit-kubernetes`](../stackit-kubernetes).

**Target audience:**

- **Platform engineers** who want to offer LLM access as a governed product — per-team keys, budgets
  and model allow-lists — instead of giving out one shared credential.
- **Application teams** who need a stable, governed OpenAI-compatible endpoint to build on — chat
  interfaces, agents, assistants — without operating model infrastructure.

## Architecture Diagram

The diagram shows the STACKIT implementation, the sovereign reference. Every call goes through
**LiteLLM**, which enforces virtual keys, budgets and model allow-lists and routes inference to
**STACKIT AI Model Serving**, while each tenant's own **Langfuse** instance traces its calls. The
SKE platform and its landing zone come from [`stackit-kubernetes`](../stackit-kubernetes); the
greyed-out nodes are optional.

![AI Platform reference architecture](ai-platform.svg)

## The gateway is the architecture

LiteLLM and its virtual keys are the central component that manages model access. **The gateway is
what hides the shape of the backends.** Behind it, Azure is a single OpenAI instance the platform
engineers provisioned, and STACKIT is one or more Model Serving deployments — tenants never see
either. Because the gateway sits in between, the AI platform can offer several landing zones that
resolve to different backend models, or to load-balanced pools across them.

So a shared upstream credential is not a compromise in the design; it is the point of putting a
gateway there. What a tenant holds is a virtual key with a budget and an allow-list, and what the
platform team holds is the credential of the provider.

## How It Works

The architecture is opinionated so it is ready to go rather than assembled. It splits into one
platform-team order and one landing zone on the cluster `stackit-kubernetes` provides.

![One-click delivery model](ai-platform-oneclick.svg)

### 1. The platform team installs the gateway and the shared trace storage

The platform team orders the **AI Platform** building block once, in its own workspace. It installs
LiteLLM and a shared ClickHouse cluster by Helm, creates the gateway's own database inside the
shared PostgreSQL Flex instance, and publishes the gateway on one hostname of the cluster's domain.
Every input of the definition is a static input, the kubeconfig among them, so one building block
definition targets one cluster and ordering it is one click.

### 2. LiteLLM is registered as a meshStack platform

The same order registers LiteLLM as a meshStack platform of a custom platform type, because its
native concepts already form a tenancy model that meshStack maps onto. The landing zone carries the
policy, so "small budget, open models" and "approved models only" are ordinary landing zones.

| meshStack | LiteLLM |
|-----------|---------|
| Project | Team |
| Landing zone | Allowed models, budget and budget period |
| Tenant credential | Virtual key |
| Project roles | Team membership |

### 3. The landing zone provisions model access — nobody orders it

The same order creates one **AI landing zone** per policy and, for each of them, one `ai/model-access`
building block definition listed in that zone's `mandatory_building_block_refs`. A project that
lands in the zone therefore receives everything without ordering anything:

- a team on the gateway and a virtual key with the budget and the allow-list of the zone,
- a Kubernetes Secret in its namespace carrying `OPENAI_API_KEY` and `OPENAI_BASE_URL`,
- a Langfuse instance of its own, with its own database, its own trace database and its own bucket.

Every input of that definition is static or assigned from tenant context. That is what makes it
work: a mandatory block that stops to ask a human defeats its own purpose, and API-driven tenant
creation only succeeds when every input is defaulted or static.

### 4. Two replaceable layers

The runtime and the model backend are independent, which is why this is one reference architecture
rather than a STACKIT fork and an Azure fork: SKE calling Azure OpenAI is as valid as AKS calling
STACKIT.

| Layer | Contract | Chosen by | Implementations |
|-------|----------|-----------|-----------------|
| **Runtime** — where the components run | A cluster that provides namespaces and a working HTTPS hostname; the blocks declare `supportedPlatforms: kubernetes` and never name a cloud | The kubeconfig the platform team hands the architecture | STACKIT SKE via `stackit-kubernetes`, Azure AKS, any conformant cluster |
| **Model** — where inference happens | An OpenAI-compatible endpoint plus credential, registered as a LiteLLM `model_list` entry | The platform team, once, in the model backend list | `stackit/model-serving`, `ai/azure-openai`, self-hosted vLLM |

Adding a cloud means adding one entry to the model backend list, not changing the architecture.

## Deployment vs Tenancy

| Component | Deployments | Tenancy unit | Provisioned by |
|-----------|-------------|--------------|----------------|
| LiteLLM | one, shared | Team + virtual key | `ai/model-access` |
| Langfuse | **one per tenant** | The instance itself — organisation, project and API keypair inside it | `ai/model-access` |
| ClickHouse | one, shared | Database + scoped user | `ai/model-access` |
| PostgreSQL Flex | one, shared | Database + owner user | `ai/model-access` |
| Object storage | one bucket per tenant | Bucket + scoped credential | `ai/model-access` |
| Valkey | one, shared | Database index + key prefix | separation derived by `ai/model-access` |
| STACKIT AI Model Serving | managed service | none — the gateway is the tenancy boundary | the platform team, once |

The gateway is deployed once and is internally multi-tenant. **Tracing is not**: every tenant gets a
Langfuse instance of its own, so an application team's traces, evaluations and stored credentials
never share a process with another team's. Those instances share four backends — Postgres,
ClickHouse, Valkey and object storage — and each tenant is separated inside them by a database, a
user, a bucket, a key prefix and a database index that `ai/model-access` derives from the workspace
and the project.

## Governance and Observability

| Concern | Where it is enforced |
|---------|----------------------|
| Which models a team may call | LiteLLM model allow-list on the team, set by the landing zone |
| Spend per team | LiteLLM budget on the team; project budget in meshStack |
| Rate limiting and shared-capacity contention | LiteLLM per-key rate limits |
| Prompt and response audit | The tenant's own Langfuse traces |
| Quality regression tracking | Langfuse evaluations |
| Cost attribution and chargeback | Langfuse usage → meshStack project cost tags |
| Credential rotation | Re-applying the building block; the virtual key never leaves the run that minted it |

## Authentication

Every service in the architecture trusts **the same identity provider**, natively, with no
oauth2-proxy in front of anything. The provider is an input and never an assumption: the issuer, the
client id, the client secret and the claim mapping are configured on the building block definition.

The gateway's admin console **holds at most five users**. Native single sign-on is free in the
open-source proxy up to that number, and the sixth login locks out everyone. The cap is accepted
here: it bounds the platform team's console access and nothing an application team does. The
tenants' Langfuse instances have no such limit.

## Getting Started

### Prerequisites

| Requirement | Description |
|----------------------|--------------------------------------------------------------------|
| meshStack instance | With Terraform/OpenTofu IaC runtime configured. |
| `stackit-kubernetes` | Deployed, providing the cluster, its HTTPS ingress with cert-manager, a Kubernetes platform with a namespace landing zone, and the `apps_domain` and `kubeconfig` outputs this architecture takes as inputs. |
| Model backend | STACKIT AI Model Serving enabled, or an equivalent OpenAI-compatible endpoint such as Azure OpenAI, with a credential for each. |
| Shared PostgreSQL Flex instance | The gateway's database and every tenant's tracing database are created inside it. |
| Shared Valkey instance | The queue backend, cache and rate limit store of the tracing instances. The hub has no Valkey module yet, so the platform team runs it. |
| Object storage admin credential | A STACKIT Object Storage credentials group and its credential, which every tenant's bucket is created with. |

### Deployment Order

1. Deploy [`stackit-kubernetes`](../stackit-kubernetes). It provisions the cluster with its ingress
   and TLS, and registers a Kubernetes platform with a namespace landing zone.
2. Provision the shared prerequisites: the PostgreSQL Flex instance, the Valkey instance and the
   object storage admin credential.
3. Register the model backends: a STACKIT AI Model Serving token, an Azure OpenAI deployment, or
   both, and note the base URL and credential of each.
4. Apply [`meshstack_integration.tf`](meshstack_integration.tf). It creates the platform type and
   the **AI Platform** building block definition, with the whole configuration as static inputs.
5. Order the **AI Platform** building block once in the platform team's own workspace. It installs
   the gateway and the shared ClickHouse, registers the gateway as a meshStack platform, and creates
   the AI landing zones together with the mandatory `ai/model-access` definition of each.
6. Publish the AI landing zones. Application teams then order projects on them, and model access
   arrives with the project.

## Shared Responsibilities

| Responsibility                                              | Platform Team | Application Team |
|-------------------------------------------------------------|:---:|:---:|
| Operate the Kubernetes cluster hosting the platform          | ✅ | ❌ |
| Provide the shared Postgres, Valkey and object storage       | ✅ | ❌ |
| Install and upgrade the gateway and the shared trace storage | ✅ | ❌ |
| Decide which models are offered and to whom                  | ✅ | ❌ |
| Define landing zones: allowed models, budgets, rate limits   | ✅ | ❌ |
| Register and maintain building block definitions             | ✅ | ❌ |
| Upgrade the tenants' tracing instances                       | ✅ | ❌ |
| Order a project in an AI landing zone                        | ❌ | ✅ |
| Mount the delivered Secret and keep the credential out of source control | ❌ | ✅ |
| Stay within the granted budget and model allow-list          | ❌ | ✅ |
| Review own traces and evaluations in their own Langfuse instance | ❌ | ✅ |
| Build and operate the AI application or assistant            | ❌ | ✅ |
