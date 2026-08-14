---
name: AI Platform
supportedPlatforms:
  - kubernetes
  - stackit
description: Installs the LiteLLM gateway and the shared ClickHouse cluster into a Kubernetes cluster, registers the gateway in meshStack as a platform of a custom type, and creates the AI landing zones that make model access mandatory for every project landing in them.
---

This building block composes four Hub modules into one orderable unit:

- [`modules/ai/litellm`](../../../modules/ai/litellm) installs the gateway — **sourced once**, one
  installation for the whole platform.
- [`modules/ai/clickhouse`](../../../modules/ai/clickhouse) installs the shared trace storage —
  **sourced once**, one cluster shared by every tenant.
- [`modules/stackit/postgresflex/buildingblock/database`](../../../modules/stackit/postgresflex/buildingblock/database)
  creates the gateway's own database inside the shared PostgreSQL Flex instance. The instance itself
  is a prerequisite and is never created here.
- [`modules/ai/model-access`](../../../modules/ai/model-access) is the integration, not the
  building block: it registers the tenant-facing definition. It is sourced **once per landing zone**,
  because the allowed models, the budget and the budget period are `STATIC` inputs of a definition.

[`modules/ai/langfuse`](../../../modules/ai/langfuse) is deliberately absent here. There is one
tracing instance **per tenant**, and `ai/model-access` deploys it when the tenant is created.

All modules are sourced by Git URL and pinned with `?ref=${var.hub.git_ref}`, so one variable moves
the whole composition to another Hub release.

## What one order produces

| In the cluster | In meshStack |
|---|---|
| The gateway, its namespace, its Secret and one Ingress | A platform of the custom platform type, named `<platform_name>.<location>` |
| The shared ClickHouse cluster and its Keeper | One AI landing zone per entry in `landing_zones` |
| A database and its owner user on the shared Postgres instance | One `AI Model Access` building block definition per landing zone, listed in that zone's `mandatory_building_block_refs` |

## Everything is a static input

This is a `WORKSPACE_LEVEL` block and **every input of its definition is `STATIC`**. The kubeconfig
binds a definition to one cluster anyway, so there is nothing left for a human to fill in at order
time: the platform team configures the architecture in
[`../meshstack_integration.tf`](../meshstack_integration.tf) and ordering it is one click.

The kubeconfig arrives as an encrypted static input, in the `sensitive = { argument = {
secret_value, secret_version } }` shape. That shape exists for inputs and not for outputs, which is
the same reason the gateway's master key never leaves this run.

## The credentials this run generates

Two secrets are generated here rather than taken as inputs, because they only ever move between two
modules of one run:

| Secret | Where it ends up |
|---|---|
| The gateway's master key | The Secret named by the `litellm_master_key_secret` output, in the gateway namespace, and the `STATIC` admin key input of every model access definition. |
| The ClickHouse administrative password | The Secret the ClickHouse module keeps in its namespace, which each tenant's DDL Job mounts. |

Neither is a building block output, and neither can be: `version_spec.outputs` has no `sensitive`
block, so every output is stored and displayed in cleartext in meshPanel.

## No DNS, no certificate

The architecture below this one — [`stackit-kubernetes`](../../stackit-kubernetes) or any
conformant cluster — already delivers namespaces **and a working HTTPS hostname**. Every name under
`apps_domain` resolves to the ingress load balancer, and the controller serves a wildcard
certificate for it as its default. So this building block creates exactly one `Ingress` for the
gateway, with no `tls` block and no cert-manager annotation, and each tenant's tracing instance gets
one the same way.

## The platform type is created by the integration, not by the run

`meshstack_platform_type` lives in [`../meshstack_integration.tf`](../meshstack_integration.tf) and
is passed in here by name. A platform type is one catalog-wide object that outlives any single
order — ordering the architecture a second time for a second cluster adds a second platform of the
same type — and creating it from the run would need an ephemeral API permission whose name is not
documented in this repository. `version_spec.permissions` therefore covers platforms, landing zones
and building block definitions only.

The default is `AI-MODEL`, named for the capability rather than for LiteLLM, the product that
delivers it — the same reason the tenant-facing block is called "AI Model Access". A dash and not an
underscore, because meshStack restricts a platform type name to uppercase letters, digits and dashes.

## What has to exist before this runs

| Prerequisite | Why it is not created here |
|---|---|
| A Kubernetes cluster with an ingress controller and a wildcard certificate | It is the architecture below this one. |
| A shared PostgreSQL Flex instance | Tenants arrive one at a time and share it; creating it per order would put a server behind an order. |
| A shared Valkey instance | The hub has no Valkey module yet. It is a work item, not a reason to inline a Helm release here. |
| An administrative Object Storage credentials group and its credential | The same reason `modules/ai/model-access` takes it as an input: moving it to workload identity federation needs a backplane. |
| Model backends and their upstream credentials | The platform team provisions them — a single Azure OpenAI instance, one or more STACKIT Model Serving deployments — and the gateway is what hides them from tenants. |

## Validating locally

Every module source interpolates `${var.hub.git_ref}` and `var.hub` is `const`, so its value has to
come from an environment variable rather than from `-var`:

```sh
export TF_VAR_hub='{"git_ref":"<the branch or tag that carries the sourced modules>"}'
tofu init && tofu validate
```

There is no generated terraform-docs section here. terraform-docs cannot parse a module whose
`source` interpolates a variable, and `reference-architectures/stackit-landingzone` and
`reference-architectures/stackit-kubernetes` fail the same way. Read
[`variables.tf`](variables.tf) and [`outputs.tf`](outputs.tf) directly.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).
