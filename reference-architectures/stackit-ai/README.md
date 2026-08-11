---
name: STACKIT AI
description: >
  A governed, observable AI platform on sovereign infrastructure: OpenWebUI as the user-facing
  interface, LiteLLM as the model gateway enforcing per-tenant virtual keys and budgets, Langfuse
  for tracing and evaluation, and STACKIT AI Model Serving as the sovereign model backend — ordered
  per team as a meshStack building block.
cloudProviders:
  - stackit
buildingBlocks:
  - path: stackit/model-serving
    role: Issues the per-tenant STACKIT AI Model Serving token and the matching LiteLLM virtual key.
---

# STACKIT AI

## Overview

<!-- TODO: sharpen after the talk. -->

Enterprise AI adoption stalls on three questions that a raw model endpoint does not answer: *who may
call which model*, *what did it cost*, and *what exactly was sent and returned*. This reference
architecture puts a governed gateway and an observability layer in front of sovereign model serving,
and makes tenant access a self-service building block instead of a shared API key passed around.

**Target audience:**

- **Platform engineers** who want to offer LLM access as a governed product — per-team keys, budgets
  and model allow-lists — rather than handing out one shared credential.
- **Application teams** who need a stable, OpenAI-compatible endpoint and a chat UI without
  operating model infrastructure.

## Architecture Diagram

The **AI platform** runs on SKE inside STACKIT. **OpenWebUI** is what users see; every call goes
through **LiteLLM**, the single choke point where virtual keys, budgets and model allow-lists are
enforced, and which routes inference to **STACKIT AI Model Serving**. **Langfuse** traces every call
for evaluation and usage attribution. Self-hosted **vLLM** is shown muted — it is an optional
backend, not required when the managed sovereign API is used. On the right, **meshStack** turns model
access into a catalog item: ordering the building block issues the tenant's key and ties usage back
to a project that carries budget and cost tags.

![STACKIT AI reference architecture](stackit-ai.svg)

## Governance and Observability

<!-- TODO: talking points — confirm which of these the demo actually showed. -->

| Concern | Where it is enforced |
|---------|----------------------|
| Which models a team may call | LiteLLM model allow-list, bound to the virtual key |
| Spend per team | LiteLLM budget on the virtual key; project budget in meshStack |
| Rate limiting / noisy neighbours | LiteLLM per-key rate limits |
| Prompt and response audit | Langfuse traces |
| Quality regression tracking | Langfuse evaluations |
| Cost attribution and chargeback | Langfuse usage → meshStack project cost tags |
| Credential rotation | Building block re-order / token TTL |

## Open Question: STACKIT-Specific or Pluggable Models?

<!-- Decision to make in the session. -->

The demo stack was deliberately built so the infrastructure and model-serving layers are
**replaceable** — it ran on Scaleway, and STACKIT AI Model Serving can drop into the model layer.
That raises a scoping question for this reference architecture:

**Option A — STACKIT AI (as drawn above).** One sovereign backend, the simplest story, fits the
`stackit/*` module namespace and the existing STACKIT reference architectures.

**Option B — AI Platform with pluggable models (bring your own model).** LiteLLM already is the
abstraction layer, so the same architecture generalises: sovereign backends (STACKIT AI Model
Serving, self-hosted vLLM on SKE) alongside external ones (Azure OpenAI, any OpenAI-compatible API),
with routing policy deciding which tenant may reach outside the sovereign boundary.

![Pluggable model backends variant](stackit-ai-pluggable.svg)

Option B is the stronger platform story and makes the sovereignty boundary explicit rather than
implicit, but it widens the scope beyond a STACKIT reference architecture and needs a home outside
`modules/stackit/`.

## How It Works

<!-- TODO: fill in after the talk; confirm how the components are deployed (Helm charts? which
     building blocks own them?) and whether tenants get one shared OpenWebUI or one per team. -->

1. The platform team deploys the AI platform components (OpenWebUI, LiteLLM, Langfuse) onto SKE.
2. LiteLLM is configured with STACKIT AI Model Serving as a backend and Langfuse as its trace sink.
3. The platform team registers the model-access building block against the AI-enabled landing zone.
4. An application team orders it in their project; the block issues a STACKIT Model Serving token and
   a LiteLLM virtual key carrying that team's budget and model allow-list.
5. The team's users chat through OpenWebUI; every call is authorised at the gateway, traced in
   Langfuse, and attributed back to the meshStack project.

## Getting Started

### Prerequisites

| Requirement          | Description                                                                 |
|----------------------|-----------------------------------------------------------------------------|
| STACKIT organization | With AI Model Serving enabled and a service account permitted to issue tokens. |
| SKE cluster          | A running STACKIT Kubernetes Engine cluster to host the platform components. |
| meshStack instance   | With Terraform/OpenTofu IaC runtime configured.                             |

### Deployment Order

<!-- TODO -->

## Shared Responsibilities

| Responsibility                                              | Platform Team | Application Team |
|-------------------------------------------------------------|:---:|:---:|
| Operate the SKE cluster and the AI platform components       | ✅ | ❌ |
| Decide which models are offered and to whom                  | ✅ | ❌ |
| Configure gateway budgets, rate limits and allow-lists       | ✅ | ❌ |
| Register and maintain building block definitions             | ✅ | ❌ |
| Order model access from the self-service catalog             | ❌ | ✅ |
| Stay within the granted budget and model allow-list          | ❌ | ✅ |
| Review own traces and evaluations in Langfuse                | ❌ | ✅ |
| Build and operate the AI application or assistant            | ❌ | ✅ |

## Notes for the Session

<!-- Scratch space — remove before merging. -->

- Demo components in scope here: OpenWebUI, LiteLLM, Langfuse, STACKIT AI Model Serving.
- Dropped from the original demo for focus: FlowiseAI (agent/workflow builder), RAGFlow (RAG and data
  layer). Worth deciding whether these return as a follow-up reference architecture.
- Original demo ran on Scaleway; only the model-serving and infrastructure layers need swapping.
- Hub modules still missing for the platform components themselves — only `stackit/model-serving` is
  scaffolded so far.
