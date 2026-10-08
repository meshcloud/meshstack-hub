---
name: T Cloud Public Landing Zone
description: >
  Bootstraps a self-service-ready T Cloud Public (Open Telekom Cloud) platform: a backplane IAM user,
  an optional federated company identity provider, and the T Cloud Public Project platform with a
  default landing zone. Every project gets one IAM group per meshStack role, and federated users are
  mapped into those groups by the meshStack project they belong to.
cloudProviders:
  - otc
buildingBlocks:
  - path: otc/project
    role: Provisions a T Cloud Public project with one IAM group per meshStack role and maps federated project users into them.
---

# T Cloud Public Landing Zone

## Overview

The **T Cloud Public Landing Zone** reference architecture turns a T Cloud Public domain into a
self-service-ready meshStack platform in one step. Application teams create meshStack projects in
its landing zone, and each one becomes a T Cloud Public project `<region>_<project>`, with access
that follows the meshStack project's roles.

Access runs through the company identity provider. T Cloud Public federates it into the domain, and
users sign in as virtual users. meshStack does not create IAM users. Instead, every project
building block writes mapping rules that put a project's users, matched by email, into that
project's IAM groups at sign-in.

**Target audience:**

- **Platform engineers** onboarding a T Cloud Public domain into meshStack who want application
  teams to get projects self-service, with access governed in meshStack and authenticated by the
  company identity provider.
- **Application teams** who need a T Cloud Public project and want to manage who can use it by
  managing their meshStack project.

## Architecture Diagram

The left half shows the company identity provider and the **T Cloud Public domain**: the backplane
IAM user, the identity provider federated into the domain, and the tenant projects under the region
project, each with its IAM groups. The right half is **meshStack**: the platform, its landing zone
and the project building block definition. Dotted edges across the boundary show how each meshStack
construct acts on T Cloud Public. Green nodes are created once per meshStack project.

![T Cloud Public Landing Zone reference architecture](otc-landingzone.svg)

## How It Works

Running this reference architecture:

1. Creates a **meshStack location**, unless the global location is chosen.
2. Sources the [`modules/otc`](../../modules/otc) platform integration, which:
   - creates the **backplane IAM user** `mesh-<platform identifier>` and a group holding Security
     Administrator on the domain, which the project building block authenticates as;
   - federates the **company identity provider** (SAML or OIDC) when one is configured, with a base
     mapping rule that lets any federated user sign in without permissions;
   - registers the **T Cloud Public Project** platform, its default landing zone and the
     [`otc/project`](../../modules/otc/project) building block definition as the landing zone's
     mandatory building block.

For every meshStack project in the landing zone, the `otc/project` building block then:

1. Creates the project `<region>_<project>` under the region's project.
2. Creates one IAM group per meshStack role and gives it the T Cloud Public system roles that the
   **role mapping** names, on that project.
3. Writes one mapping rule per role into the identity provider's mapping. The rule matches the role's
   users by email and adds the role's group. A user who changes role in meshStack gets the new
   groups at their next sign-in.

### Identity: federation, not replication

T Cloud Public gives a federated user their groups at sign-in, from the identity provider's mapping
rules. So meshStack never writes users or group memberships. The mapping rules are the only place
membership lives, and meshStack remains the source of truth for who is on a project.

An identity provider has a single mapping that all projects share. Each project building block owns
exactly the rules that name one of its groups, and merges them in and out with
`federation_mapping.py`. The IAM API has no conditional write, so the script reads the mapping back
after writing and retries if a concurrent run of another project overwrote its change.

Without an identity provider (the input left empty), projects and groups are still created, but nobody is
mapped into them. The platform team then has to add IAM users to the groups by hand.

### Authentication

T Cloud Public's Terraform provider cannot exchange an OIDC token for credentials, so meshStack's
workload identity federation is not usable yet:

- This building block runs with an **access key and secret key** you supply. They belong to an IAM
  user holding Security Administrator on the domain, and are used on every run.
- The project building block runs as the **backplane IAM user** with a generated password, which
  reaches meshStack as a sensitive static input. It is a password rather than an AK/SK because the
  federation script calls the IAM API directly, and a password gets it a token without
  implementing AK/SK request signing.

The IAM API can turn an OIDC ID token into a temporary credential, so moving the project building
block to workload identity is a later step, not a dead end.

## Getting Started

### Prerequisites

| Requirement | Description |
|---|---|
| T Cloud Public domain | With an IAM user holding Security Administrator, and an access key for it. |
| meshStack platform type `OTC` | A custom platform type named `OTC` must exist in the meshStack instance. Override the name with `otc_platform_type` on [`modules/otc`](../../modules/otc). |
| Identity provider *(recommended)* | SAML metadata, or the OIDC issuer, client ID and JWKS signing keys. The email claim or attribute must carry exactly the address meshStack knows for each user. For OIDC, register the IdP's redirect URI shown in the T Cloud Public console. |

### Deployment Order

Order the **T Cloud Public Landing Zone** building block once per workspace. It creates the
platform, the landing zone and the project building block definition in the same apply.
Application teams can then create meshStack projects in the landing zone.

### Playground Mode

`playground_mode` defaults to `true`, so an unconfigured deployment is a throwaway one. The platform
identifier and the backplane IAM user name get a random suffix, because a platform identifier is
unique across the whole meshStack instance, and an IAM user name is unique across the domain.

**A playground platform is for the deploying workspace only.** Do not publish it or its project
building block definition to other workspaces. Set `playground_mode = false` for a platform that is
actually used. The flag reaches the building block as a `STATIC` input, so whoever orders the
architecture cannot change it.

### Approval Gates

`approval_policies` sets which run triggers need an operator's approval before a run of this
architecture is applied. It defaults to no gate at all.

## Not Yet Covered

- **Hub-and-spoke networking.** T Cloud Public documents a hub VPC with a NAT gateway and spoke
  VPCs peered to it. A hub building block and a self-service spoke VPC building block would add it.
  T Cloud Public has no built-in IP address management, so the address plan would need its own
  allocation.
- **Security baseline.** A Cloud Trace Service tracker writing to a KMS-encrypted OBS bucket, and the
  domain's password, login and protection policies.
- **Project starterkit** that creates a meshStack project and its T Cloud Public project in one order.

## Shared Responsibilities

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Provide the admin access key, domain and role mapping | ✅ | ❌ |
| Federate the company identity provider and keep its signing keys current | ✅ | ❌ |
| Provision the T Cloud Public Project platform and default landing zone | ✅ | ❌ |
| Request T Cloud Public projects through the landing zone | ❌ | ✅ |
| Decide who is on each project, and with which role | ❌ | ✅ |
| Build and run workloads inside the projects | ❌ | ✅ |
