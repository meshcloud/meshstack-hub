---
name: AI Model Access
supportedPlatforms:
  - ai
description: Gives a project a governed OpenAI-compatible model endpoint with a budget, delivers the credential as a Kubernetes Secret in the namespace of the project, and deploys a tracing instance of its own for it.
# The module receives both cluster credentials, the gateway admin key and every backend credential
# as static inputs, and it creates nothing outside the two clusters and the gateway, so there is no
# cloud-side setup to perform ahead of time.
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
2. Deploys the tenant's own Langfuse instance into the AI platform cluster, by sourcing
   `modules/ai/langfuse/buildingblock`.
3. Looks up the sibling tenant of the same meshProject on the demo application cluster, to learn its
   namespace.
4. Writes the virtual key and the endpoint into a Kubernetes Secret in that namespace, in the demo
   application cluster.

## One root module, and why that is the whole design

A `buildingblock` directory is always a meshStack root module: the meshStack Terraform runner checks
it out and runs `tofu plan` and `tofu apply` inside it. Provider configuration therefore belongs
here, and this module configures five providers — `litellm`, two `kubernetes` configurations with
aliases, `helm` and `meshstack`.

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
`get`, `create`, `update` and `patch` on `secrets`, and nothing else. `get` cannot be dropped —
without it the Terraform provider can neither plan nor detect drift.

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

### The four verbs are not enough to delete the building block

`version_spec.deletion_mode` is `DELETE`, so meshStack destroys everything the run created when the
building block is deleted. Destroying the Secret needs `delete` on secrets, which the four verbs above
do not include, and the destroy fails with a 403 on that one resource. **Add `delete` on `secrets` to
the ClusterRole if the building block has to be deletable.** It grants little beyond `update`, which
can already replace the content of any Secret in the cluster. Without it, deletion has to be finished
by hand, or the credential in the namespace outlives the building block.

## Per-tenant names, and what has to exist first

`naming.tf` derives every per-tenant name from `<workspace_identifier>.<project_identifier>`, the
pair being unique in meshStack. Each name carries the first eight characters of the SHA256 hash of
the untruncated pair, because Postgres identifiers, DNS labels, Kubernetes namespaces and bucket
names all stop at 63 characters and two long identifier pairs that share a prefix would otherwise
collide after truncation.

| What | Shape | Example for `acme.payments` |
|---|---|---|
| Langfuse namespace and hostname label | `langfuse-<slug>-<hash>` | `langfuse-acme-payments-817e29e9` |
| Postgres database | `langfuse_<slug>_<hash>` | `langfuse_acme_payments_817e29e9` |
| ClickHouse database | `langfuse_<slug>_<hash>` | `langfuse_acme_payments_817e29e9` |
| Bucket | `langfuse-<slug>-<hash>` | `langfuse-acme-payments-817e29e9` |
| Valkey key prefix | `<slug>-<hash>:` | `acme-payments-817e29e9:` |
| Valkey database index | hash modulo the index count | |
| Langfuse organisation and project | the plain meshStack identifiers | `acme`, `payments` |

The Valkey index and the key prefix carry different guarantees, and both are set. The prefix is
unique per tenant and is what actually separates two tenants: Langfuse's BullMQ queue names are
hardcoded, so two tenants sharing a keyspace without a prefix would have one tenant's worker consume
the other tenant's ingestion jobs. The index is a hard namespace that no application bug can cross,
but an instance serves only so many indices, so it is derived by hash and repeats once there are more
tenants than indices. It is defence in depth behind the prefix, never the separation itself.

**This building block does not create the Postgres database, the ClickHouse database or the bucket.**
Langfuse creates tables inside a database, never the database itself, so all three have to exist
under exactly the names above before the first apply, together with the users the credentials belong
to. The `langfuse_backend_names` output reports the names of a tenant, so the platform team's own
provisioning can create them. Closing that gap needs providers this module does not configure and is
follow-up work.

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

Three Langfuse secrets have to differ per tenant, or the isolation between the instances is defeated:
the salt that hashes the tenant's API keys, the encryption key for its stored credentials, and the
NextAuth secret that signs its session tokens. They are generated in the run, because a `STATIC`
input is the same value for every tenant. `random_bytes` is used instead of `random_id` wherever the
value is a secret: both produce hex, but only `random_bytes` marks it sensitive, so the value stays
out of the plan.

## Provider pin

The `ncecere/litellm` provider is pinned to exactly `2.0.1`. This is a deliberate exception to the
hub rule that provider constraints use `>=`, and `versions.tf` explains why.

## Validating locally

The module sources `modules/ai/langfuse/buildingblock` with `?ref=${var.hub.git_ref}`, and `var.hub`
is `const`, so its value has to come from an environment variable rather than from `-var`:

```sh
export TF_VAR_hub='{"git_ref":"<the branch or tag that carries modules/ai/langfuse>"}'
tofu init && tofu validate && tofu test
```

The same interpolation stops `terraform-docs` from reading this directory, which is why there is no
generated input and output table below. `reference-architectures/stackit-landingzone` and
`reference-architectures/stackit-kubernetes` fail the same way, for the same reason.
