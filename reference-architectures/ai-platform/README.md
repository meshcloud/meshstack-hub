---
name: AI Platform
description: >
  An opinionated, one-click AI platform: LiteLLM and Langfuse deployed into a Kubernetes namespace,
  with LiteLLM registered as a meshStack platform so application teams order governed model access —
  budget, allowed models and tracing included — as a self-service item. The cluster comes from the
  stackit-kubernetes reference architecture; the model layer defaults to STACKIT AI Model Serving.
cloudProviders:
  - stackit
  - azure
buildingBlocks:
  - path: ai/litellm
    role: Deploys the LiteLLM gateway by Helm and registers it as a meshStack platform with its AI landing zones.
  - path: ai/langfuse
    role: Deploys Langfuse by Helm for tracing, evaluation and usage attribution, and wires LiteLLM to it.
  - path: ai/litellm-team
    role: Creates the LiteLLM team and virtual key an application team orders, with the models and budget its landing zone allows.
  - path: stackit/model-serving
    role: Issues the STACKIT AI Model Serving token that LiteLLM routes sovereign inference through.
  - path: ai/azure-openai
    role: Registers an Azure OpenAI deployment as a model backend, the Azure counterpart to stackit/model-serving.
---

# AI Platform

## Overview

Three questions hold back enterprise AI adoption, and a raw model endpoint answers none of them:
*who may call which model*, *what did it cost*, and *what exactly was sent and returned*. This
reference architecture answers them with opinionated defaults rather than a toolkit: one order
installs the gateway and the observability stack, a second turns model access into a catalog item.

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
**STACKIT AI Model Serving**, while **Langfuse** traces every call. The SKE platform and its landing
zone come from [`stackit-kubernetes`](../stackit-kubernetes); the greyed-out nodes are optional.

![AI Platform reference architecture](ai-platform.svg)

## How It Works

The architecture is opinionated so it is ready to go rather than assembled. It splits into one
platform-team order and one application-team order on the cluster `stackit-kubernetes` provides.

![One-click delivery model](ai-platform-oneclick.svg)

### 1. The platform team installs LiteLLM and Langfuse

The platform team orders the **AI Platform** building block once, in its own workspace. It deploys
both components by Helm into a namespace of the Kubernetes landing zone and wires them together:
LiteLLM points at Langfuse for tracing, and the model backends come from the credentials it was
given. The kubeconfig is an encrypted static input, so one building block definition targets one
cluster.

### 2. LiteLLM is registered as a meshStack platform

The same order registers LiteLLM as a meshStack platform of a custom platform type, because its
native concepts already form a tenancy model that meshStack maps onto. The landing zone carries the
policy, so "small budget, open models" and "approved models only" are ordinary landing zones.

| meshStack | LiteLLM |
|-----------|---------|
| Project | Team |
| Landing zone | Allowed models, budget and rate-limit tier |
| Tenant credential | Virtual key |
| Project roles | Team membership |

### 3. Application teams order model access

Ordering model access is a normal self-service action per project. The `ai/litellm-team` building
block issues a STACKIT AI Model Serving token in the tenant's **own** STACKIT project — one model
credential per tenant, not a shared one — and registers the matching deployment, team and virtual
key in LiteLLM. The team receives an endpoint, a key and a Langfuse project.

### 4. Two replaceable layers

The runtime and the model backend are independent, which is why this is one reference architecture
rather than a STACKIT fork and an Azure fork: SKE calling Azure OpenAI is as valid as AKS calling
STACKIT.

| Layer | Contract | Chosen by | Implementations |
|-------|----------|-----------|-----------------|
| **Runtime** — where the components run | A landing zone that provides Kubernetes namespaces; the blocks declare `supportedPlatforms: kubernetes` and never name a cloud | The landing zone the platform team orders into | STACKIT SKE via `stackit-kubernetes`, Azure AKS, any conformant cluster |
| **Model** — where inference happens | An OpenAI-compatible endpoint plus credential, registered as a LiteLLM `model_list` entry | LiteLLM routing policy, supplied by one model-access block per provider | `stackit/model-serving`, `ai/azure-openai`, self-hosted vLLM |

Adding a cloud means adding one small model-access module with the same output shape, not changing
the architecture. The runtime layer needs no per-cloud work at all: the precedent is
[`kubernetes/manifest`](../../modules/kubernetes/manifest), a Helm building block that takes a
kubeconfig and names no cloud.

## Deployment vs Tenancy

| Component | Deployments | Tenancy unit | Provisioned by |
|-----------|-------------|--------------|----------------|
| LiteLLM | one, shared | Team + virtual key | `ai/litellm-team` |
| Langfuse | one, shared | Organization/project + scoped API key | `ai/litellm-team` |
| STACKIT AI Model Serving | managed service | Token in the tenant's own STACKIT project | `stackit/model-serving` |

The platform components are deployed once and are internally multi-tenant; nothing is deployed per
application team. Isolation rests on LiteLLM's team boundary and Langfuse's project boundary.

## Governance and Observability

| Concern | Where it is enforced |
|---------|----------------------|
| Which models a team may call | LiteLLM model allow-list, bound to the virtual key |
| Spend per team | LiteLLM budget on the virtual key; project budget in meshStack |
| Rate limiting and shared-capacity contention | LiteLLM per-key rate limits |
| Prompt and response audit | Langfuse traces |
| Quality regression tracking | Langfuse evaluations |
| Cost attribution and chargeback | Langfuse usage → meshStack project cost tags |
| Credential rotation | Building block re-order / token TTL |

## Getting Started

### Prerequisites

| Requirement | Description |
|----------------------|--------------------------------------------------------------------|
| meshStack instance | With Terraform/OpenTofu IaC runtime configured. |
| `stackit-kubernetes` | Deployed, providing the SKE cluster, its HTTPS ingress with cert-manager, and a Kubernetes platform with a namespace landing zone. |
| Model backend | STACKIT AI Model Serving enabled, or an equivalent OpenAI-compatible endpoint such as Azure OpenAI. |
| DNS zone | A hostname for the LiteLLM gateway and the Langfuse UI, resolvable to the cluster's load balancer. |

### Deployment Order

1. Deploy [`stackit-kubernetes`](../stackit-kubernetes). It provisions the SKE cluster with its
   ingress and TLS, and registers a Kubernetes platform with a namespace landing zone.
2. Enable the model backend: STACKIT AI Model Serving, or an Azure OpenAI deployment.
3. Order the **AI Platform** building block once in the platform team's own workspace. It installs
   LiteLLM and Langfuse into a namespace of that landing zone, registers LiteLLM as a meshStack
   platform, and creates the AI landing zones and the tenant-facing `ai/litellm-team` definition.
4. Publish the AI landing zones, setting the budget and model allow-list each one grants.
5. Application teams order model access in their own projects.

## Shared Responsibilities

| Responsibility                                              | Platform Team | Application Team |
|-------------------------------------------------------------|:---:|:---:|
| Operate the Kubernetes cluster hosting the platform          | ✅ | ❌ |
| Install and upgrade LiteLLM and Langfuse                     | ✅ | ❌ |
| Decide which models are offered and to whom                  | ✅ | ❌ |
| Define landing zones: allowed models, budgets, rate limits   | ✅ | ❌ |
| Register and maintain building block definitions             | ✅ | ❌ |
| Order model access from the self-service catalog             | ❌ | ✅ |
| Stay within the granted budget and model allow-list          | ❌ | ✅ |
| Review own traces and evaluations in their Langfuse project   | ❌ | ✅ |
| Build and operate the AI application or assistant            | ❌ | ✅ |
