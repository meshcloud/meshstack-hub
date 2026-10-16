# STACKIT Kubernetes Platform — Implementation Details

## Outer and nested run

The stackit provider rejects a service account email that is unknown while planning, so a run
cannot act as an account it creates. The outer **STACKIT Kubernetes Platform** run therefore holds
no STACKIT identity and only bootstraps, in one apply:

1. the meshProject and its tenant, which is the platform's STACKIT project,
2. the **Automation Identity** from the landing zone's service account definition, with the roles
   `editor` and `iam.member-admin` (the registry block grants members their role with it),
3. the **Bootstrap Identity Federation**, its child, trusting only the nested **STACKIT
   Kubernetes Platform Services** definition,
4. one **Platform Services** building block, with the account's email as a known input.

Platform Services acts as the account from its first run and orders the tree. The outer run waits
for it and shows its summary. Every outer input the tree needs reaches it as a Platform Services
input, so updating the outer building block is the only way to change the platform.

## Federations and parents

- **Automation Identity Federation**, a child of the Automation Identity, trusts the six
  definitions whose runs act as the account: Secrets Manager, SKE cluster, Git, container
  registry, AI Model Serving and DNS. Those six building blocks are its children.
- **Starter Kit Identity Federation** (phase 2) trusts the Git repository definition, whose runs
  list the Git instance's users through the STACKIT Git API to match workspace members by email.
  The Forgejo token's technical user is restricted and cannot see them.
- The Kubernetes Platform Admin service account is a child of the cluster; the meshPlatform
  Credentials and the Ingress are children of the service account; the DNS zone is also a child of
  the Ingress, because it takes the load balancer IP.

A new STACKIT capability needs its role in the landing zone's `stackit_assignable_roles`, its
definition's uuid in `federated_building_block_definitions`, and the federation as a parent of its
building block.

## Secrets

The nested run creates a writer and a reader user in the Secrets Manager. Each block that creates
a credential gets the writer login and the prefix `<platform identifier>/` in `output_to_vault`,
writes one KV v2 secret at `<prefix><provider>/<service>`, and outputs `vault_secret = {path,
secret_hash}`. The nested run reads what a definition needs with the reader login as an ephemeral
value and registers it as a write-only input.

| Secret | Keys | Written by | Read for |
|---|---|---|---|
| `<prefix>ske/cluster` | `kubeconfig` | SKE Cluster | the Kubernetes Platform Admin definition |
| `<prefix>kubernetes/service-account` | `kubeconfig` | Kubernetes Platform Admin | the `kubernetes`, ingress and Forgejo connector definitions |
| `<prefix>kubernetes/platform` | `replicator-token`, `metering-token` | Kubernetes meshPlatform Credentials | the meshStack SKE platform |
| `<prefix>stackit/git` | `forgejo-api-token` | STACKIT Git Instance | Git repository and Forgejo connector runs |
| `<prefix>stackit/container-registry` | `push-action-secrets`, `pull-kubernetes-secret` | STACKIT Container Registry | Git repository and Forgejo connector runs |
| `<prefix>stackit/ai-llm` | `kubernetes-secret` | AI Model Serving | Forgejo connector runs (`stackit-ai`) |
| `<prefix>imports/stackit/git` | `forgejo-api-token` | the nested run, from Import Secrets | the STACKIT Git Instance that adopts an organization |

The registry and AI keys hold JSON objects, read from `data_json`. The phase 2 definitions get the
reader login and the paths, and their runs read the secrets themselves. Git repository runs keep
the push robot in their state, because the restapi provider has no write-only attributes.

An ephemeral value has no version meshStack could compare, so the nested run passes each
`secret_hash` on as `kubeconfig_version` or `tokens_version`. A rotated secret reaches the
definitions on the next nested run. The Forgejo connector gets one hash of the pull robot and the
AI secret as `secrets_revision`, so its runs rewrite the Kubernetes secrets when either changes.

The Forgejo token has no human owner: the Git block creates a technical user through the STACKIT
Git API and exchanges its password for a personal access token.

## Phase 2

`phase2_completed` reaches the registry block as `require_robot_link`. Every registry run checks
whether a robot is linked to the service account; with `require_robot_link` it fails while none
is, so no phase 2 definition is registered without registry credentials. The registry reports its
secret only once the robots exist.

## Adoption

Each adopting block imports in its own state: a `this` resource that is deleted with the block
and a `released` one that is dropped from the state (`destroy = false`). The nested run sets a
block's `release_on_destroy` only in playground mode and only for adopted resources.

The Git block adopting an instance creates its own technical user with a random suffix, because
the existing user's password is unknown, and orders no shared runner, because STACKIT allows one
per instance. With the token from Import Secrets it adds that user to the organization's `Owners`
team and removes it again on deletion; STACKIT refuses to delete a user who is still in an
organization. Its `writers` and `readers` teams carry the same suffix. The block never deletes the
organization itself; it goes with the instance.

## Deletion

- **A child's definition is deleted before its parent's.** meshStack deletes a definition's
  building blocks with it, and fails on the `fk_tbb_Parent` foreign key if one is still the parent
  of another block. So the service account definition depends on the cluster definition, and the
  `kubernetes` and ingress definitions on the service account definition.
- **The Secrets Manager goes last.** Its users and every block that writes to it take its instance
  id.
- **The service account depends on no definition it federates**, or a definition that reads the
  account's email and its child definition would form a cycle. That is why the federation is a
  building block of its own.
- Outside playground mode the outer tenant has `prevent_destroy`: destroying it deletes the STACKIT
  project and everything in it.

## Updates

- The nested and child definitions get the Hub ref as a STATIC input. meshStack starts no run when
  a draft definition version changes in place, so after a `hub.git_ref` bump only the outer
  building block runs; the others pick up the new code on their next run.
- A child's version ref carries the content hash of its definition. A changed definition updates
  every such child, and their outputs are unknown during that plan. The nested run pins the
  Secrets Manager instance id in a `terraform_data`, so the blocks that write to it stay known.
