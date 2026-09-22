---
name: STACKIT Kubernetes Platform
description: >
  A sovereign-cloud Kubernetes platform on STACKIT, built on top of a STACKIT Landing Zone:
  an SKE cluster, cloud-agnostic in-cluster ingress and meshStack identities, and the meshStack SKE platform with dev/prod
  landing zones that application teams order self-service Kubernetes namespaces from.
cloudProviders:
  - stackit
buildingBlocks:
  - path: ske/cluster
    role: Provisions the STACKIT Kubernetes Engine (SKE) cluster and mints the admin kubeconfig the rest of the platform is built on.
  - path: kubernetes/ingress
    role: Installs cert-manager, the HAProxy ingress controller and the Let's Encrypt ClusterIssuer on the cluster.
  - path: kubernetes
    role: Registers the meshStack Kubernetes platform and its landing zones, and creates the in-cluster replicator and metering identities meshStack authenticates with.
  - path: stackit/git
    role: Provisions the STACKIT Git (Forgejo) instance the platform's CI/CD runs on, and the organization application repositories live in.
  - path: stackit/git-repository
    role: Registered for application teams so they can order a Git repository in that organization.
  - path: ske/forgejo-connector
    role: Registered for application teams so they can wire a repository to their namespace for Forgejo Actions CI/CD.
---

# STACKIT Kubernetes Platform

## Overview

The **STACKIT Kubernetes Platform** reference architecture delivers a complete,
sovereign-cloud Kubernetes experience on [STACKIT](https://www.stackit.de/). It combines
three Hub building blocks into a cohesive platform that gives application teams self-service
access to Kubernetes namespaces with integrated Git repositories and CI/CD pipelines —
all running on European infrastructure with full data sovereignty. Each team receives
a ready-to-use ai-summarizer demo application with provisioned access to STACKIT Model Serving,
a sovereign LLM API, ensuring even AI capabilities remain under full data control.

**Target audience:**

- **Platform engineers** building an internal developer platform on STACKIT.
- **Application teams** who need a fast, secure path to Kubernetes with built-in CI/CD
  in a sovereign cloud environment.

## Architecture Diagram

![STACKIT Kubernetes reference architecture](stackit-kubernetes.svg)

## How It Works

### 1. STACKIT Kubernetes Engine (SKE)

SKE is a managed Kubernetes service provided by STACKIT. The platform team provisions
and maintains the cluster(s); application teams consume namespaces via meshStack tenants.
SKE handles control-plane management, upgrades, and scaling automatically.

### 2. Developer Starterkit — `ske/ske-starterkit`

The starterkit is the **single entry point** for application teams. When a developer
orders the starterkit from the meshStack self-service catalog, the following resources
are created automatically:

1. **Forgejo Git repository** (`stackit/git-repository`) — a code repository hosted
   on STACKIT Git (Forgejo), optionally cloned from a template URL. Workspace members
   get team-based access (Owner → admin, Manager → write, others → read).

2. **Dev project with SKE tenant** — a meshStack project with a dedicated Kubernetes
   namespace on SKE, assigned to the dev landing zone.

3. **Dev Forgejo connector** (`ske/forgejo-connector`) — wires the Git repo to the
   dev namespace so that pushes to `dev` trigger a Forgejo Actions workflow that
   builds, pushes to the STACKIT Harbor global registry, and deploys to the dev namespace.

4. **Prod project with SKE tenant** — same as above but assigned to the prod landing
   zone.

5. **Prod Forgejo connector** — wires the Git repo to the prod namespace, triggered
   by pushes to the `prod` branch.

6. **Project Admin binding** — the requesting developer is granted Project Admin on
   both projects.

### 3. Forgejo Git Repository — `stackit/git-repository`

Each application team's repository includes:

- **Team-based access** managed via Forgejo organization teams, synced from meshStack
  workspace membership.
- **Forgejo Actions secrets** — `KUBECONFIG_DEV`, `KUBECONFIG_PROD`, container
  registry credentials, and `STACKIT_MODEL_SERVING_API_KEY` are injected automatically
  by the connector.
- **Forgejo Actions variables** — `K8S_NAMESPACE_DEV`, `K8S_NAMESPACE_PROD`,
  `APP_HOSTNAME_DEV`, `APP_HOSTNAME_PROD`, and `STACKIT_MODEL_SERVING_ENDPOINT` are
  made available to Forgejo Actions for use during Helm chart installation, avoiding
  hardcoded configuration values in stage-aware deployments.
- **Template repository** — optionally cloned from a template URL, pre-configured
  with an ai-summarizer sample application that uses the STACKIT Model Serving API.

### 4. CI/CD Pipeline — `ske/forgejo-connector`

The connector building block creates per-stage resources:

- **Kubernetes service account & RBAC** scoped to the tenant namespace, including
  read access to cert-manager cluster issuers.
- **Harbor image-pull secret** attached to the default service account so pods can
  pull images from the STACKIT Harbor registry.
- **Model Serving API secret** — a Kubernetes secret containing the `STACKIT_MODEL_SERVING_API_KEY`
  is provisioned in each dev/prod namespace, allowing applications to authenticate
  with the STACKIT Model Serving endpoint.
- **Forgejo Actions secrets & variables** for the stage-specific kubeconfig,
  namespace, Model Serving credentials, and app hostname.
- **Pipeline trigger** — after provisioning, the connector triggers the Forgejo
  Actions workflow and waits for it to complete.

## What It Builds On: One Landing Zone UUID

This architecture sits on top of a deployed
[STACKIT Landing Zone](https://hub.meshcloud.io/reference-architectures/stackit-landingzone). That
landing zone provides the STACKIT organization structure, the foundation project and the platform
this architecture's hosting project is created on — and nothing Kubernetes- or Git-specific. It does
not register the SKE cluster or STACKIT Git definitions; **this architecture registers those itself,
once per ordered platform**, so every platform owns its own definitions and its own backplane
identities.

Wiring is a single value: the landing zone building block's UUID. The building block reads that
object at order time for

- `platform_ref` and `landingzone_refs` — the meshPlatform and landing zone the hosting project is
  created on, and
- `service_account_bbd_version_ref` — the **STACKIT Service Account** definition this architecture
  orders to mint its own identity.

**No STACKIT credential crosses that boundary, and this architecture holds none.** Its own apply
declares no `stackit` provider at all. It orders the service account definition on the hosting tenant
it just created, granting the account `editor`, `ske.admin` and `git.admin` and federating the SKE
Cluster and STACKIT Git definition subjects into it. Both definitions then run in
`external_service_account = true` mode, so every STACKIT resource here is created by a child building
block authenticating through workload identity federation.

Adding a STACKIT capability to this architecture — Harbor, DNS — means adding its role to the landing
zone's `stackit_assignable_roles` and its definition's subject to the `federated_identities` list. It
never means adding a credential.

## Ordering It: One Order, One Manual Step, One Update

The architecture is **ordered once and updated once**. It is not two building blocks — the same
building block runs twice, with one more input the second time.

### Phase 1 — order it with the token input empty

The run provisions everything that needs no Forgejo credential:

- the hosting STACKIT project (a self-hosted meshStack tenant),
- the **SKE Cluster** and **STACKIT Git Instance** building block definitions, registered for this
  platform, each with its own federated backplane identity,
- the SKE cluster,
- **ingress** (`kubernetes/ingress`) — cert-manager, the HAProxy ingress controller and the Let's
  Encrypt ClusterIssuer, in a single building block,
- the **meshStack Kubernetes integration** (`kubernetes`), which creates the replicator and metering
  identities and registers the meshStack platform they are wired into,
- the **STACKIT Git instance** (`stackit/git`) — named after the generated platform identifier,
  because `<name>.git.onstackit.cloud` is globally unique across all of STACKIT, and
- the meshStack SKE platform with its dev and prod landing zones.

No Forgejo organization is created, and the application-team definitions are **not** registered.
The building block's summary then shows a warning block with the instance URL and the exact token
scopes to mint.

### Phase 2 — update the same building block with the token

Paste the PAT into the optional **Forgejo API Token** input (and, if you have them, the Harbor
robot credentials). The run then additionally:

- creates the **Forgejo organization** inside the instance, and
- registers the **STACKIT Git Repository** and **SKE Forgejo Connector** building block
  definitions, so application teams can order a repository wired to a namespace on this cluster.

The summary flips from the warning to a confirmation listing what phase 2 created. Everything from
phase 1 is left untouched.

### The manual step is a gap, not a requirement

Nothing about STACKIT Git forces a human into the middle. The Git API (`v1beta`,
`https://git.api.stackit.cloud`,
[spec](https://docs.api.eu01.stackit.cloud/oas/git/version/v1beta)) can create a local/technical
user in an instance —
`POST /v1beta/projects/{projectId}/instances/{instanceId}/users` with
`{name, username, email, password, force_send_reset_password}`, permission
`git.instance.users.create`, plus
`PATCH /v1beta/projects/{projectId}/instances/{instanceId}` to flip
`feature_toggle.enable_local_login`. That user's password then mints a PAT through Forgejo's own
`POST {instance_url}/api/v1/users/{username}/tokens`, which returns it once in the `sha1` field and
accepts **HTTP Basic auth only** (an existing token cannot mint another).

None of this is in the STACKIT Terraform provider or the Go SDK yet, and `stackit_git` has neither
update support nor a `feature_toggle` attribute, so it would have to go out of band. The flow is
verified against the published spec, **not** against a live instance, and it is not implemented.
The code is shaped for it: both `modules/stackit/git/buildingblock/main.tf` and this architecture's
`buildingblock/main.tf` resolve the token into a single local and branch on that, so an automatic
mint only has to feed that one expression. The optional input then stays as the override and the
fallback.

## Getting Started

### Prerequisites

| Requirement          | Description                                                                                                                                       |
|----------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| meshStack instance   | With Terraform/OpenTofu IaC runtime configured.                                                                                                   |
| STACKIT Landing Zone | A deployed STACKIT Landing Zone building block. Its UUID is the only value wired into this architecture — see above.                             |
| STACKIT account      | With access to SKE, STACKIT Git, and the global STACKIT Harbor registry.                                                                          |
| Forgejo bot account  | Created in the STACKIT Git instance this architecture provisions, for the phase-2 token (see above). Not needed before the first order.           |
| Harbor credentials   | Robot account credentials (username and secret) for push/pull access to the STACKIT global Harbor registry; shared across all STACKIT customers. |
| Model Serving API    | STACKIT Model Serving endpoint and API key for the platform team to provide to the connector.                                                     |
| DNS zone             | A DNS zone provided by STACKIT for application ingress hostnames (e.g. `apps.example.com`).                                                      |

### The Harbor credentials are still a manual prerequisite

Unlike the Forgejo instance, the Harbor project and its robot accounts are not created here. What
it would take is recorded so nobody has to rediscover it — three roles, none a subset of another,
all read from the live authorization and service-enablement APIs:

| Role | Needed for |
|---|---|
| `editor`, `owner` or a `folder.*` role | `service-enablement.service-state.edit`. `cloud.stackit.container-registry` is **disabled by default** on every project checked, so the service has to be switched on first. |
| `container-registry.admin` | `container-registry.project.create` |
| `container-registry.artifactory.admin` | `container-registry.project.permission.administer` — the Harbor project-admin permission that mints robot accounts. Neither `editor` nor `owner` carries it. |

Today the platform team supplies the robot credentials as the two optional inputs, exactly like the
Forgejo token.

## Shared Responsibilities

| Responsibility                                           | Platform Team | Application Team |
|----------------------------------------------------------| --- | --- |
| Provision and manage SKE cluster                         | ✅ | ❌ |
| Configure STACKIT Git (Forgejo) organization             | ✅ | ❌ |
| Manage Harbor project in global registry and credentials | ✅ | ❌ |
| Register and maintain building block definitions         | ✅ | ❌ |
| Manage STACKIT DNS zone for app hostnames                | ✅ | ❌ |
| Order starterkit from the self-service catalog           | ❌ | ✅ |
| Develop and maintain application source code             | ❌ | ✅ |
| Manage Kubernetes resources inside namespaces            | ❌ | ✅ |
| Maintain Forgejo Actions pipeline (`pipeline.yaml`)      | ❌ | ✅ |
| Monitor application health and logs                      | ❌ | ✅ |

## Why Sovereign Cloud?

This architecture runs entirely on STACKIT — a European cloud provider operated by
Schwarz Group. All data stays within EU data centers, meeting requirements for:

- **GDPR compliance** — data processing within the EU.
- **Data sovereignty** — no dependency on US-based hyperscaler infrastructure.
- **Industry regulations** — suitable for public sector, healthcare, and financial
  services workloads that require European data residency.
- **AI sovereignty** — your AI usage stays entirely European with STACKIT Model Serving.

