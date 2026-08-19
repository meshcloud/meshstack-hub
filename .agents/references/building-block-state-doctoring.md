# Building block state doctoring

A building block run keeps its Terraform state in meshStack's own HTTP backend, and that state is
reachable from outside the run. This is what makes tenant migration, adoption and run repair possible.

## The endpoint

```
<meshstack>/api/terraform/state/workspace/<workspace>/buildingBlock/<bb-uuid>
```

`GET` reads it, `POST` with the state as the body writes it. The runner sets only `address` on the `http`
backend and passes credentials as `TF_HTTP_USERNAME=x` / `TF_HTTP_PASSWORD=<token>`;
`TfStateRunTokenBasicAuthFilter` rewrites `Basic(x:<jwt>)` into `Bearer <jwt>`, so a normal API-key bearer
token works either way. No lock address is configured, so `-lock=false` is correct.

The API key needs `ADM_TFSTATE_LIST`, `ADM_TFSTATE_SAVE` and `ADM_TFSTATE_DELETE`.

## A local harness against a live block's state

A throwaway directory with the same module source, a matching provider configuration and an `http`
backend pointing at the run's state can `tofu import`, `state rm` and `state mv` against it like any other
remote state. Full plan and apply cycles work too.

It needs:

- the module's `buildingblock/` directory copied **with its non-`.tf` files** — a missing template such as
  `SUMMARY.md.tftpl` breaks the plan
- the BBD's inputs as tfvars
- `MESHSTACK_ENDPOINT` / `MESHSTACK_API_KEY` / `MESHSTACK_API_SECRET` in the environment, because the
  buildingblock does not configure the meshstack provider itself

## The adopt harness

The safest way to build a seed state: a copy of the *new* module's `buildingblock/`, with a **local** state
file rather than the HTTP backend. Import the live cloud resource into it, plan, then use the resulting
state as the seed.

Why this beats rewriting an old block's state:

- it reads the resource's real attributes from the cloud API rather than trusting a stale record
- the plan is a free safety check, and it can be asserted on before anything is written
- it works for tenants that never had a building block at all

Keep the harness a byte-identical copy of the module the runner executes. If it drifts, its plan stops
predicting the run's plan, which is the only reason the harness is worth having.

**Assert before you write.** Refuse to emit a seed unless the plan shows no replacements and no destroys.
Creates of subordinate resources such as role assignments are expected. A single grep on the plan output
is enough, and it belongs in the script rather than in your head.

## Normalising a state before pushing it

| Field | What to do | Why |
|---|---|---|
| `terraform_version` | Set to the runner's version, never higher | OpenTofu refuses to read a state written by a newer version. Read the runner's version off a successful run's state. |
| `serial` | 1 | The run rewrites it. |
| `outputs` | `{}` | The run recomputes them; stale values are misleading if it fails early. |
| `lineage` | Leave as generated | The runner has no prior local state to conflict with. |
| resources with no instances | Drop them | Harmless but noisy. |
| `each` | `"map"` on any resource with string-keyed instances | State v4 needs it, and a hand-built state easily omits it. |

## Import ids are provider-specific and worth checking

Two examples, both from STACKIT, both non-obvious:

- `stackit_resourcemanager_project` imports by **container id**, not project id — the `id` attribute in
  state is the container id.
- `stackit_authorization_project_role_assignment` imports by the triple `<resource-id>,<role>,<subject>`.

Read the resource's `id` attribute in an existing state to work out the format rather than guessing.

## Tokens and long applies

**Mint the token immediately before a long apply.** A meshStack token that expires mid-apply gives `HTTP
401` on state save: the resources exist and the state does not record them. Recovery is
`tofu state push errored.tfstate`, which OpenTofu writes for exactly this case.

## What state doctoring cannot fix

It moves and rewrites *Terraform's* record of the world. It does not help with meshStack objects whose
blockers are about names and identity — a landing zone that needs a different `metadata.name`, or a
platform whose location is wrong. Those are replaces, and no state edit makes them otherwise.
