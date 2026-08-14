---
name: STACKIT Kubernetes Platform
description: >
  A sovereign-cloud Kubernetes platform on STACKIT. One order creates an SKE cluster,
  gives it an HTTPS ingress with Let's Encrypt certificates and registers it in meshStack
  as a Kubernetes platform with namespace landing zones. A second order gives application
  teams self-service namespaces, Forgejo Git repositories, CI/CD via Forgejo Actions and a
  container registry backed by Harbor.
cloudProviders:
  - stackit
buildingBlocks:
  - path: stackit/ske
    role: Creates the SKE cluster and the kubeconfig the rest of the architecture authenticates with.
  - path: kubernetes/platform
    role: Registers the cluster in meshStack as a platform of type kubernetes and creates its namespace landing zones.
  - path: kubernetes/ingress
    role: Installs cert-manager, the HAProxy ingress controller and a Let's Encrypt ClusterIssuer, and issues the wildcard certificate for the cluster's own domain.
  - path: stackit/dns
    role: Writes the cluster's wildcard record into the DNS zone the platform team owns and shares between clusters.
  - path: ske/ske-starterkit
    role: Orchestrates the full developer onboarding by composing dev/prod projects, SKE tenants, Git repos, and connectors into one self-service offering.
  - path: stackit/git-repository
    role: Provisions Forgejo Git repositories on STACKIT Git with team-based access management and CI/CD secret wiring.
  - path: ske/forgejo-connector
    role: Connects a Forgejo repository to an SKE namespace for automated build and deploy via Forgejo Actions.
---

# STACKIT Kubernetes Platform

## Overview

The **STACKIT Kubernetes Platform** reference architecture delivers a complete,
sovereign-cloud Kubernetes experience on [STACKIT](https://www.stackit.de/). The architecture
provisions the cluster itself: one order creates an SKE cluster, installs an ingress controller
with Let's Encrypt certificates on it and registers it in meshStack as a Kubernetes platform whose
landing zones hand out namespaces. On top of that platform it gives application teams self-service
namespaces with integrated Git repositories and CI/CD pipelines — all running on European
infrastructure with full data sovereignty. Each team receives a ready-to-use ai-summarizer demo
application with provisioned access to STACKIT Model Serving, a sovereign LLM API, ensuring even
AI capabilities remain under full data control.

**Target audience:**

- **Platform engineers** building an internal developer platform on STACKIT.
- **Application teams** who need a fast, secure path to Kubernetes with built-in CI/CD
  in a sovereign cloud environment.

## Architecture Diagram

![STACKIT Kubernetes reference architecture](stackit-kubernetes.svg)

## How It Works

### 1. The Cluster — `STACKIT Kubernetes Cluster` building block

SKE is a managed Kubernetes service provided by STACKIT, and SKE handles control-plane management,
upgrades and scaling automatically. The architecture creates the cluster rather than expecting one
to exist. Its `TENANT_LEVEL` building block is ordered against the STACKIT Project platform, so the
cluster lands in the meshTenant's own STACKIT project, and it composes three Hub modules in a
single Terraform run:

1. **`stackit/ske`** creates the cluster and its kubeconfig.
2. **`kubernetes/platform`** registers the cluster in meshStack as a platform of type `kubernetes`
   and creates the dev and prod namespace landing zones. Application teams consume namespaces on
   it through meshStack tenants.
3. **`kubernetes/ingress`** installs cert-manager, the HAProxy ingress controller and a Let's
   Encrypt ClusterIssuer.

The team ordering a cluster decides two things: its name and how the ingress is reachable. The
`expose` input takes `public`, `internal` — which keeps the load balancer inside the STACKIT
network — or `none`, which installs no ingress controller at all. Everything else is a
landing-zone concern that the platform team sets once.

#### One identity for the whole run

All of it runs as a **single STACKIT service account**, created by
[`modules/stackit/ske/backplane`](../../modules/stackit/ske/backplane), which
[`meshstack_integration.tf`](meshstack_integration.tf) calls. The account authenticates through
workload identity federation, so no long-lived key exists for it, and it holds exactly two grants —
at two different scopes, for a reason that is the whole design of the backplane's role inputs:

| Role | Scope | Why that scope |
| --- | --- | --- |
| `ske.admin` | the folder in `stackit_folder_id` | The cluster is created in the STACKIT project of whichever meshTenant orders it, so no project can be named when the definition is registered. A folder covers all of them. |
| `dns.admin` | the project in `stackit_dns_zone_project_id` | The shared zone's project is a static input filled in at registration time. Naming it keeps the identity off every other project. |

Neither role exists at organization scope on STACKIT — the authorization API offers a different set
of roles per resource type, and an organization offers 76 of them, including neither of these.

The second grant is what makes one backplane enough. Drop it and the composition still creates the
cluster, then fails with a `403` when it writes the wildcard record.

The account is named `mesh-ske` by default. If you already run one by hand under that name, either
import it into this configuration or give the backplane a name of its own with
`stackit_service_account_name` — STACKIT rejects a second account with the same name in the same
project.

### 2. Hostnames and Certificates

The platform team owns **one DNS zone**, for example `likvid.stackit.run`, in its own STACKIT
project, and every cluster shares it. Each ordered cluster gets its **own label inside that zone**:
the `stackit/dns` module writes the record set `*.<cluster_name>` pointing at the cluster's HAProxy
load balancer, so every hostname below `<app>.<cluster_name>.likvid.stackit.run` resolves to that
cluster. cert-manager then holds a **single wildcard certificate** for
`*.<cluster_name>.likvid.stackit.run`, which HAProxy serves for every application hostname.

The result is a landing zone that promises more than a namespace: an application team that adds an
Ingress with a hostname under the cluster's domain gets a working HTTPS URL, without requesting a
certificate and without creating a DNS record.

A subzone per cluster is not possible, and this is measured against the live API rather than
assumed. A free STACKIT subdomain admits exactly one label, so creating the zone
`cluster1.likvid.stackit.run` fails with *"subdomain should only have one level"* — in every
project, and even with a correct NS delegation already in place in the parent zone. A record set
with that depth **inside** the existing zone is allowed, which is what the design uses.

Two consequences worth knowing before you deploy:

- **The DNS credential is zone-wide.** cert-manager's DNS-01 solver authenticates with a service
  account key that carries `dns.admin` on the zone's project, and that role cannot be narrowed to
  one zone, let alone to one label. A cluster could write records outside its own label. The
  building block code is what keeps clusters inside their label, and the permission system does not
  enforce it.
- **One cluster per zone may sit at the apex.** Set `dns_cluster_label_enabled = false` and the
  cluster's wildcard becomes `*.likvid.stackit.run`, which gives flat hostnames and reproduces the
  shape existing SKE foundations already have. Only one cluster in a zone can hold that record, so
  every further cluster needs its label. Moving a cluster from the apex to a label renames every
  hostname it serves.

The DNS handling is isolated in [`buildingblock/dns.tf`](buildingblock/dns.tf), together with the
inputs that drive it.

#### The ACME account has no contact address

This architecture registers its Let's Encrypt account without one, and there is no `acme_email`
input on the building block. Let's Encrypt accepts an account with no contact address, and a
certificate that fails to renew shows up on the `Certificate` resource in the cluster, where an
operator watching the cluster sees it. The mail is a backstop, not the signal.

Exposing the address is a **later feature**, for operators who do want mail about expiring
certificates. It cannot simply be a constant: `modules/kubernetes/ingress` keeps `acme_email`
required precisely because the address is not one value across an estate — the SKE foundation units
use `ske@meshcloud.io`, but other units of other clouds use their own. So the module keeps the
input, and this architecture passes `""` until there is a real value to pass.

### 3. Developer Starterkit — `ske/ske-starterkit`

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

### 4. Forgejo Git Repository — `stackit/git-repository`

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

### 5. CI/CD Pipeline — `ske/forgejo-connector`

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

## Getting Started

### Prerequisites

| Requirement          | Description                                                                                                                                       |
|----------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| meshStack instance   | With Terraform/OpenTofu IaC runtime configured.                                                                                                   |
| STACKIT account      | With access to SKE, STACKIT Git, and the global STACKIT Harbor registry.                                                                          |
| STACKIT Project platform | Registered in meshStack, for example through the [`stackit-landingzone`](../stackit-landingzone) reference architecture. Clusters are ordered on its tenants. |
| STACKIT identity     | Created for you by [`modules/stackit/ske/backplane`](../../modules/stackit/ske/backplane), which [`meshstack_integration.tf`](meshstack_integration.tf) calls. You supply the STACKIT project the account lives in and the folder the tenant projects live under; the backplane does the roles and the workload identity federation. The STACKIT provider you apply that file with needs `experiments = ["iam"]`. |
| Forgejo organization | On STACKIT Git, with an API token for the Terraform provider.                                                                                     |
| Harbor credentials   | Robot account credentials (username and secret) for push/pull access to the STACKIT global Harbor registry; shared across all STACKIT customers. |
| Model Serving API    | STACKIT Model Serving endpoint and API key for the platform team to provide to the connector.                                                     |
| DNS zone             | A STACKIT DNS zone the platform team owns, for example `likvid.stackit.run`, and the project it lives in. Every cluster writes its own label into that one zone. |
| DNS service account key | A key with `dns.admin` on the zone's project, which cert-manager's DNS-01 solver uses to answer the ACME challenge. |

### Deployment Order

1. Register the STACKIT Project platform, so tenants have a STACKIT project to order into.
2. Register the **STACKIT Kubernetes Cluster** building block definition from
   [`meshstack_integration.tf`](meshstack_integration.tf), setting the STACKIT project and folder
   the backplane works with, the shared DNS zone with the project that owns it, and the DNS service
   account key. Applying that file creates the service account, its WIF identity provider and both
   role assignments, so nothing about the identity is set up by hand.
3. An application team orders a cluster on its STACKIT project. The order creates the cluster, its
   ingress and the Kubernetes platform with its namespace landing zones.
4. Register the starterkit and connector building block definitions against that platform.
5. Application teams order the starterkit and receive namespaces, a repository and a pipeline.

## Shared Responsibilities

| Responsibility                                           | Platform Team | Application Team |
|----------------------------------------------------------| --- | --- |
| Provide the STACKIT identity the cluster building block runs as | ✅ | ❌ |
| Own the shared DNS zone and the key its records are written with | ✅ | ❌ |
| Configure STACKIT Git (Forgejo) organization             | ✅ | ❌ |
| Manage Harbor project in global registry and credentials | ✅ | ❌ |
| Register and maintain building block definitions         | ✅ | ❌ |
| Order an SKE cluster and choose its ingress exposure     | ❌ | ✅ |
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

