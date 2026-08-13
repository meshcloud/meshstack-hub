---
name: AI Model Access
supportedPlatforms:
  - ai
description: Gives a project a governed OpenAI-compatible model endpoint with a budget, delivers the credential as a Kubernetes Secret in the namespace of the project, and deploys a tracing instance of its own for it together with the per-tenant database, bucket and ClickHouse database that instance needs.
# The module creates resources on STACKIT, but it receives every credential it needs for them as a
# static input: the two cluster kubeconfigs, the gateway admin key, the STACKIT service account key
# and the administrative object storage credential. Nothing has to be provisioned per tenant ahead of
# time, so there is no backplane. See "The STACKIT credential" below for what the platform team
# creates by hand instead, and why workload identity federation would need a backplane.
requiresBackplane: false
---

# AI Model Access Building Block

This is the one building block an application team gets when its project lands in the AI landing
zone. The AI landing zone lists the building block definition in
`spec.mandatory_building_block_refs`, so meshStack provisions it when the tenant is created and the
application team fills in nothing.

The display name is **AI Model Access**, named for the capability. LiteLLM and Langfuse stay behind
that name, so the platform team can replace either without renaming what the application team
ordered.

## What one run does

1. Creates the tenant's team on the shared LiteLLM gateway, with the budget and the model allow-list
   of the landing zone, and one virtual key scoped to that team.
2. Creates the three per-tenant backend resources the tenant's Langfuse instance needs: a database
   and its owner user on the shared Postgres instance, a database and a scoped user in the shared
   ClickHouse cluster, and a bucket with a credential of its own.
3. Deploys the tenant's own Langfuse instance into the AI platform cluster, by sourcing
   `modules/ai/langfuse/buildingblock`, wired to the three resources of step 2.
4. Looks up the sibling tenant of the same meshProject on the demo application cluster, to learn its
   namespace.
5. Writes the virtual key and the endpoint into a Kubernetes Secret in that namespace, in the demo
   application cluster.

## One root module, and why that is the whole design

A `buildingblock` directory is always a meshStack root module: the meshStack Terraform runner checks
it out and runs `tofu plan` and `tofu apply` inside it. Provider configuration therefore belongs
here, and this module configures seven providers — `litellm`, two `kubernetes` configurations with
aliases, `helm`, `meshstack`, `stackit` and `aws`.

The four steps above are not split into separate building blocks, and they are not split into
submodules either. **A building block output cannot be sensitive.** `version_spec.outputs` of
`meshstack_building_block_definition` has no `sensitive` block, unlike `version_spec.inputs`, and an
output's `assignment_type` is limited to `NONE`, `PLATFORM_TENANT_ID`, `SIGN_IN_URL`, `RESOURCE_URL`
and `SUMMARY`. So a building block output is stored and displayed in cleartext in meshPanel. LiteLLM
returns a virtual key once, at creation, and never again. Keeping the mint and the delivery in one
Terraform run is what keeps the key inside that run: it is never an output of this module, and it
never crosses a building block boundary.

## Two clusters, two provider aliases

The tenant's Langfuse instance and the tenant's workload live in different clusters, so there are two
`kubernetes` provider configurations:

| Alias | Cluster | What it does there |
|---|---|---|
| `kubernetes.ai_platform`, `helm.ai_platform` | AI platform cluster | Creates the namespace, the secret and the Helm release of the tenant's Langfuse instance. |
| `kubernetes.demo_app` | Demo application cluster | Writes one Secret into the namespace of the application team. |

Both kubeconfigs arrive as `STATIC` encrypted inputs, in the `sensitive = { argument = {
secret_value, secret_version } }` shape.

## The namespace comes from the sibling tenant

The block runs on the AI model tenant, on the LiteLLM platform. The workload runs on a second tenant
of the same meshProject, a namespace on the demo application cluster. meshStack does not hand the
sibling tenant to a building block run, so the run asks for it:

```hcl
data "meshstack_tenants" "sibling" {
  workspace = var.workspace_identifier
  project   = var.project_identifier
  platform  = var.demo_app_platform_identifier
}
```

`spec.platform_tenant_id` of a Kubernetes tenant **is** the namespace name. The filter is on
`platform`, the full `<platform>.<location>` identifier, and never on `platform_type`: two Kubernetes
clusters are two platforms of one type, so a type filter would match a tenant on the wrong cluster.

The lookup needs an ephemeral API token, which `version_spec.permissions = ["TENANT_LIST"]` grants.
`modules/aks/github-connector` proves that a `TENANT_LEVEL` block can hold those permissions.

Three preconditions on the Secret cover the three ways the lookup can go wrong: no match, more than
one match, and a match whose `platform_tenant_id` is still null because meshStack has not replicated
the tenant yet. The third one is the dangerous case. The Kubernetes provider falls back to the
namespace of the kubeconfig's current context when `metadata.namespace` is null, so a null id would
put the credential in a namespace that belongs to somebody else.

`one()` is deliberately not used to read the single match. It raises an error of its own on a
collection with more than one element, and that error would replace the precondition message, which
names the platform and the project.

## Residual risk of the demo cluster credential

The credential for the demo application cluster is deliberately narrow: a ClusterRole permitting
`get`, `create`, `update`, `patch` and `delete` on `secrets`, and nothing else. `get` cannot be
dropped — without it the Terraform provider can neither plan nor detect drift.

**Be honest about what remains.** A ClusterRole is not namespaced, so the credential can write a
Secret into **any** namespace of that cluster. The boundary is enforced by this module's code rather
than by the permissions, and `create` on secrets is a known privilege-escalation path: a Secret can
carry a service account token, and a controller that consumes Secrets can be steered by one.

What mitigates it is that no tenant can influence which namespace is chosen. Every input that reaches
the namespace decision is either injected by meshStack from the tenant — `WORKSPACE_IDENTIFIER` and
`PROJECT_IDENTIFIER` — or a `STATIC` value the platform team fixed in the building block definition:
the platform identifier, the Secret name and both kubeconfigs. **No `USER_INPUT` reaches the
namespace decision, and none may be added.** A test in `../definition.tftest.hcl` asserts that every
input of the definition carries one of those four assignment types.

### Why `delete` is in the list

`version_spec.deletion_mode` is `DELETE`, so meshStack destroys everything the run created when the
building block is deleted. Destroying the Secret needs `delete` on `secrets`, and without the verb the
destroy fails with a 403 on that one resource: the deletion stops half-way and the credential in the
namespace outlives the building block it belonged to.

`delete` grants little beyond what the credential already has. `update` can replace the content of any
Secret in the cluster, so a credential that holds `update` can already make any Secret useless to the
workload reading it; `delete` removes the object instead of emptying it. `create` remains the verb that
carries the real risk, for the reason above.

## Per-tenant names

`naming.tf` derives every per-tenant name from `<workspace_identifier>.<project_identifier>`, the
pair being unique in meshStack. Each name carries the first eight characters of the SHA256 hash of
the untruncated pair, because Postgres identifiers, DNS labels, Kubernetes namespaces and bucket
names all stop at 63 characters and two long identifier pairs that share a prefix would otherwise
collide after truncation.

The module creates the resources carrying these names, so a name that changes takes its resource with
it: Terraform replaces the database, the user or the bucket, and the data in it is gone. Every
expression in `naming.tf` is part of the module's contract.

| What | Shape | Example for `acme.payments` |
|---|---|---|
| Langfuse namespace and hostname label | `langfuse-<slug>-<hash>` | `langfuse-acme-payments-817e29e9` |
| Postgres database, and the user owning it | `langfuse_<slug>_<hash>` | `langfuse_acme_payments_817e29e9` |
| ClickHouse database, and the user scoped to it | `langfuse_<slug>_<hash>` | `langfuse_acme_payments_817e29e9` |
| Bucket | `langfuse-<slug>-<hash>` | `langfuse-acme-payments-817e29e9` |
| ClickHouse DDL release, and the objects of it | `langfuse-<shorter slug>-<hash>` | `langfuse-acme-payments-817e29e9` |
| Valkey key prefix | `<slug>-<hash>:` | `acme-payments-817e29e9:` |
| Valkey database index | hash modulo the index count | |
| Langfuse organisation and project | the plain meshStack identifiers | `acme`, `payments` |

A database and a user carry the same name on purpose, in Postgres as in ClickHouse: an operator reads
one name in two places. Both users have to be per-tenant, because a Postgres role and a ClickHouse user
are objects of the whole server, and two tenants sharing a user share every grant that user holds.

The DDL release gets a shorter slug than everything else. Helm stops a release name at 53 characters,
which is the tightest limit of the family, and the Jobs of the release derive their names from the
release name plus a suffix — a Job name in turn ends up in the `job-name` label of its pods, and a label
value stops at 63 characters.

The Valkey index and the key prefix carry different guarantees, and both are set. The prefix is
unique per tenant and is what actually separates two tenants: Langfuse's BullMQ queue names are
hardcoded, so two tenants sharing a keyspace without a prefix would have one tenant's worker consume
the other tenant's ingestion jobs. The index is a hard namespace that no application bug can cross,
but an instance serves only so many indices, so it is derived by hash and repeats once there are more
tenants than indices. It is defence in depth behind the prefix, never the separation itself.

## The three backend resources this building block creates

Langfuse creates tables inside a database and objects inside a bucket, never the database or the bucket
itself. The Postgres database, the ClickHouse database and the bucket therefore have to exist before its
first pod starts, and tenants arrive one at a time, so nothing applied once at the level of the platform
can pre-create them. **This building block creates them**, in the same run that deploys the instance
using them.

That makes the block STACKIT-bound. It is a deliberate choice: `modules/ai/` groups a capability rather
than promising cloud-agnosticism, and `modules/ai/azure-openai` sits in the same directory. An Azure
twin of this block would keep the shape and swap the two submodules.

| Backend | How it is created | What is destroyed with the block |
|---|---|---|
| Postgres | `modules/stackit/postgresflex/buildingblock/database` in database-only mode | the database and its owner user |
| Object storage | `modules/stackit/storage-bucket/buildingblock/bucket` | the credentials group, the credential and the bucket, if the bucket is empty |
| ClickHouse | a Helm release of the chart in `clickhouse-ddl/`, two hook Jobs | the database and the user, dropped by the `pre-delete` hook |

### Postgres, through the provider-free submodule

`modules/stackit/postgresflex/buildingblock/database` declares no provider of its own, which is what
makes it usable from here: a module carrying its own provider configuration is a legacy module, and
OpenTofu rejects `count`, `for_each` and `depends_on` on every call to it. Passing
`existing_instance_id` selects the submodule's database-only mode, in which it creates
`stackit_postgresflex_database` and `stackit_postgresflex_user` against the shared instance and touches
nothing about the instance itself. Tenant churn therefore never re-plans the shared server.

The owner user is created with the role `login` and nothing else. `prisma migrate deploy` creates and
alters tables inside a database the user owns and never creates a database, so `createdb` would only let
a tenant create databases outside its own scope.

STACKIT generates the password of the user, so it is not an input either. One consequence is worth
knowing: `modules/ai/langfuse` rejects a Postgres password containing `:`, `@`, `/`, `?`, `#` or `%`,
because Langfuse substitutes the value into its connection URL without percent-encoding it and Prisma
then answers `P1013`. Should STACKIT ever generate such a password, the apply stops with that message
and the way out is to have STACKIT generate a new one for the user.

`modules/ai/langfuse` receives the host, the port, the database, the user and the password from that
call, and `DIRECT_URL` from its `direct_connection_string` output. **Both connection limits stay
pinned.** The pool of a pod is capped at 5 connections and the pool of a migration at 2, which are the
defaults of `modules/ai/langfuse`: the shared instance has a fixed `max_connections`, of which STACKIT
reserves 15, and every pod of every tenant draws from the rest. The value handed to `DIRECT_URL` carries
no `connection_limit` of its own — the submodule puts `sslmode=require` on it and nothing else — and
`modules/ai/langfuse` appends the smaller limit itself, because two occurrences in one query string
leave the effective pool size to the parser.

### The bucket, created with the `aws` provider

`modules/stackit/storage-bucket/buildingblock/bucket` is provider-free for the same reason, and it needs
two providers: `stackit` for the credentials group and the credential, and **`aws` for the bucket and its
policy**. The `aws` provider is configured here as a generic S3 client against the STACKIT Object Storage
endpoint, because the stackit provider has no permission to create a bucket. `provider.tf` mirrors
`modules/stackit/storage-bucket/buildingblock/provider.tf`, region included: the region is fixed at
`eu01` and is not an input, because the endpoint URL carries it and the two cannot be set apart.

The credential the tenant's instance uses comes out of that call rather than in as an input. The
submodule creates a credentials group per bucket and writes a bucket policy that denies every principal
outside that group and the administrative group, so a tenant's credential reaches its own bucket and no
other tenant's.

### ClickHouse: a Helm release with two hook Jobs

ClickHouse has no Terraform resource for a database and a user, and **it cannot have one here**. The
shared cluster answers on an in-cluster hostname such as
`clickhouse-clickhouse-headless.clickhouse.svc.cluster.local`, which the meshStack Terraform runner can
neither resolve nor reach. Any provider speaking the ClickHouse protocol would need a route from the
runner into the cluster network, so the DDL has to execute inside the cluster whatever drives it. This is
the decisive difference to Postgres, where the STACKIT API is a public endpoint and a provider does the
work.

What was weighed:

| Option | Verdict |
|---|---|
| The official `ClickHouse/clickhouse` provider | Not applicable. It manages ClickHouse Cloud services and has no resource for DDL against a self-managed server. |
| A community ClickHouse provider | Rejected. Each is a single-maintainer project, and none of them changes the reachability problem above: the runner still cannot open a connection to a Service inside the cluster. |
| A bare `kubernetes_job_v1` | Rejected. It creates the database, but Terraform destroys resources and has no way to run a Job on the way out, so the tenant's data would outlive the tenant. |
| A Helm release with hook Jobs | **Chosen.** |

The chart lives in `clickhouse-ddl/` inside this module, the pattern `modules/ai/clickhouse` and
`modules/kubernetes/ingress` already use for manifests Terraform cannot express. It carries two Jobs:

- a `post-install,post-upgrade` hook that creates the database, the user and the grants;
- a `pre-delete` hook that drops the database and the user again.

Both run in the namespace of the shared cluster, not in the tenant's own namespace. The administrative
password is a Secret in that namespace, and the tenant's namespace does not exist yet at that point,
because `modules/ai/langfuse` creates it and has to run afterwards.

This answers the three awkward parts of running DDL from a Job:

- **Ordering.** The Langfuse module call carries `depends_on` on the release, so the instance is deployed
  after the DDL has run. Inside the release, Helm applies the hook before it reports the release ready.
- **Failure.** `clickhouse-client` exits non-zero on a failed statement, `set -e` fails the container,
  `backoffLimit: 0` fails the Job, Helm fails the release and Terraform fails the apply. A failed
  statement cannot pass silently. `activeDeadlineSeconds` bounds a cluster that never answers, so the
  result is a failed Job with a log rather than a Terraform timeout without one.
- **Deletion.** `helm uninstall` runs the `pre-delete` hook and waits for it before it removes anything
  else, and destroying the release is what the runner does when the building block is deleted.

Every apply of the building block runs the create Job again, so every statement in it is idempotent:
`CREATE DATABASE IF NOT EXISTS`, `CREATE USER IF NOT EXISTS` followed by an `ALTER USER … IDENTIFIED
WITH`, and a `GRANT … WITH REPLACE OPTION`. The `ALTER USER` is there because `CREATE USER IF NOT EXISTS`
leaves the password of an existing user untouched, and Terraform holds the value it also hands to
Langfuse. `WITH REPLACE OPTION` revokes what the user held before, so the grants converge on the list
below instead of only ever growing.

The grants are exactly what Langfuse uses on its own database:

```sql
GRANT ON CLUSTER default
  SELECT, INSERT, CREATE, DROP TABLE, ALTER UPDATE, ALTER DELETE, ALTER DROP INDEX
  ON langfuse_acme_payments_817e29e9.* TO langfuse_acme_payments_817e29e9
  WITH REPLACE OPTION;
```

`CREATE DATABASE` is deliberately absent. Langfuse runs its ClickHouse migrations with golang-migrate,
which creates tables inside a database that already exists and never creates one, so the right would only
let a tenant create databases outside its own scope.

Two details worth knowing when comparing this with the DDL written out in
`modules/ai/clickhouse/buildingblock/README.md`. First, the position of `ON CLUSTER`: the documented
ClickHouse grammar puts it **directly after `GRANT`**, unlike in `CREATE DATABASE` and `CREATE USER`,
where it follows the object the statement names, and that readme places it at the end of the `GRANT`
instead. Second, the password of the tenant's user is generated in this run rather than taken as an
input, for the same reason the three Langfuse secrets are: a `STATIC` input is the same value for every
tenant, and a shared password would let one tenant connect as another.

### What deletion actually does, and where it stops

`deletion_mode` is `DELETE`, and each of the three backends behaves differently:

| Resource | On deletion |
|---|---|
| Postgres database and owner user | Destroyed by the STACKIT API. The data is gone. |
| ClickHouse database and user | Dropped by the `pre-delete` hook Job, with `SYNC`, so the tables are gone before the Job finishes. |
| Bucket, credentials group and credential | Destroyed — **but only when the bucket is empty.** |

**A bucket that still holds objects fails the destroy.** The S3 API refuses to delete a non-empty bucket,
and the submodule sets no `force_destroy`. The submodule destroys the credential only after the bucket, so
a destroy that stops on a non-empty bucket leaves the credential in place: an operator can empty the
bucket with it and run the deletion again. Emptying it stays a deliberate step, because those objects are
the tenant's trace payloads.

Two more failure modes to know about:

- If the ClickHouse cluster is unreachable when the building block is deleted, the `pre-delete` hook Job
  never succeeds, the uninstall fails and the destroy stops. Removing the release from the state with
  `tofu state rm` and cleaning up by hand is the way out — the same command is also the way to keep a
  tenant's trace data on purpose.
- A first install that fails is removed again, because the release is `atomic`, and that removal runs the
  same `pre-delete` hook. On a fresh tenant that is what should happen: no half-created database is left
  behind. A failed *upgrade* rolls back and runs no hook at all.

## The STACKIT credential

The module authenticates against STACKIT with a service account key, a `STATIC` sensitive input. The hub
convention for modules under `modules/stackit/` is workload identity federation instead, and it is the
better pattern: no long-lived secret to rotate. It is not available here without more work, because a
federated identity provider has to assert the subject of this building block definition, and creating one
needs a backplane this module does not have. `modules/kubernetes/ingress` takes a STACKIT service account
key as an input for the same reason.

The platform team therefore creates three things by hand, or from its own foundation code, and passes them
in: the service account and its key, the administrative object storage credentials group, and the shared
PostgreSQL Flex instance itself. A backplane that creates the first two and moves the block to workload
identity federation is follow-up work.

The administrative ClickHouse password is **not** an input. The DDL Job mounts the Secret the shared
cluster already holds it in, named by the `admin_secret` output of `modules/ai/clickhouse`.

## Access control of the tracing instances

Langfuse upserts an organisation membership with `langfuse_default_org_role` for every user who logs
in, which is what removes member synchronisation from the picture: no group mapping, no SCIM.

With one OIDC client shared across tenants, that has a consequence worth stating plainly: every user
the identity provider authenticates reaches every tenant's instance with that role. The three ways
out are a client per tenant, which contradicts the zero-input rule of a mandatory block; restricting
who is assigned to the shared client at the identity provider; or `langfuse_default_org_role = "NONE"`
plus memberships added by hand. Pick one deliberately.

Every tenant's instance has a callback URL of its own, reported by the `langfuse_oidc_callback_url`
output, and the shared client needs each of them as an allowed redirect URI. Where the identity
provider supports a wildcard redirect URI, one entry covers every tenant.

## Generated secrets

Four secrets have to differ per tenant, or the isolation between the instances is defeated: the salt
that hashes the tenant's API keys, the encryption key for its stored credentials, the NextAuth secret
that signs its session tokens, and the password of its ClickHouse user. They are generated in the run,
because a `STATIC` input is the same value for every tenant. `random_bytes` is used instead of
`random_id` wherever the value is a secret: both produce hex, but only `random_bytes` marks it
sensitive, so the value stays out of the plan.

The password of the Postgres user is generated by STACKIT, and the credential of the bucket by the
Object Storage API. Neither is an input either.

## Provider constraints

Two constraints in `versions.tf` are not the `>=` the hub rule asks for, and both are deliberate:

- `ncecere/litellm` is pinned to exactly `2.0.1`, because it is a community provider that has changed
  resource behaviour inside a minor release and a recreated `litellm_key` takes the credential away
  from a running application. `versions.tf` carries the full reasoning.
- `hashicorp/aws` carries an upper bound of `< 5.0`. That is not a choice made here:
  `modules/stackit/storage-bucket/buildingblock/bucket` carries the same constraint, because v5 of the
  provider always sends `LocationConstraint` in `CreateBucket` while STACKIT's StorageGRID only accepts
  a request without it. A wider constraint here would not intersect with the submodule's and `init`
  would fail.

## Validating locally

The module sources three modules with `?ref=${var.hub.git_ref}` — `modules/ai/langfuse/buildingblock`
and the two STACKIT submodules — and `var.hub` is `const`, so its value has to come from an environment
variable rather than from `-var`:

```sh
export TF_VAR_hub='{"git_ref":"<the branch or tag that carries the three sourced modules>"}'
tofu init && tofu validate && tofu test
```

The chart in `clickhouse-ddl/` renders on its own, which is the quickest way to read the statements the
Jobs run:

```sh
helm template t ./clickhouse-ddl \
  --set clickhouse.host=clickhouse-clickhouse-headless.clickhouse.svc.cluster.local \
  --set clickhouse.image=clickhouse/clickhouse-server:26.4 \
  --set admin.secretName=clickhouse-admin \
  --set tenant.database=langfuse_acme_payments_817e29e9 \
  --set tenant.username=langfuse_acme_payments_817e29e9 \
  --set tenant.secretName=langfuse-acme-payments-817e29e9-user \
  --set 'tenant.grants={SELECT,INSERT}'
```

The same interpolation stops `terraform-docs` from reading this directory, which is why there is no
generated input and output table below. `reference-architectures/stackit-landingzone` and
`reference-architectures/stackit-kubernetes` fail the same way, for the same reason.
