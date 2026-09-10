# Tag inputs e2e fixture

Covers `assignment_type = "TAG"` building block inputs: meshStack resolves them from a tag on the
workspace, project, payment method or landing zone, and re-resolves them when that tag changes or
when the object it reads from is reassigned.

## Why this fixture owns everything

Every meshObject here — platform, landing zone, payment methods, project, tenant — is created by the
test rather than taken from `test_context.fixtures`. Two reasons:

- **Retagging is the thing under test.** There is no `meshstack_project_tag` or
  `meshstack_payment_method_tag` resource, so a shared fixture project or payment method cannot be
  tagged at all. Only an object this module owns can carry a tag it also edits.
- **A custom platform needs no cloud.** It has no replicator, so nothing outside meshStack has to
  exist or succeed for the tenant to reach a usable state.

This is why the fixture is hub mode only. A foundation's project and payment methods are not ours to
retag.

Two consequences worth knowing before the first run: tag definitions and payment methods are
admin-scoped (`ADM_TAGDEFINITION_SAVE`, `ADM_PAYMENTMETHOD_SAVE`, neither with a workspace-scoped
variant), and the mandatory tags of the objects it creates come from the instance itself.
`data.meshstack_tag_definitions` supplies them: a select tag takes its first option, every other
type a marker. A mandatory tag that validates its value — a regex, a number — needs that case
added to `local.mandatory_tags`.

## Why the tenant needs a manual building block

The provider counts a tenant as created once `spec.platform_tenant_id` is set, and a custom platform
has no replicator to set it. The landing zone therefore carries a mandatory building block whose only
output is assigned `PLATFORM_TENANT_ID`. All its inputs are `STATIC`, so the manual run completes
with no operator action, `wait_for_completion = true` stays, and teardown does not race.

## Why the definition lives here

A `TAG` input reading a project, payment method or landing zone is only valid on a `TENANT_LEVEL`
definition, and a tenant-level definition requires `spec.supported_platforms` — a platform. The
shipped `../../meshstack_integration.tf` keeps its single `WORKSPACE_LEVEL` definition, where the
provider accepts only the `WORKSPACE` tag target. So the definition under test is declared here,
against the small building block in `buildingblock/`, the same way `../env-audit` does it.

## What the test proves, and what it does not

It proves **the value a tag holds now reaches the next building block run**.

It does *not* prove the tag edit alone triggered that run. meshStack does trigger one, but the
provider exposes no way to attribute a run to an edit: `status.latest_run_uuid` exists, but `Read`
never blocks, so a refresh reads stale outputs.

Two things follow, and both cost a debugging round to find:

- **Every mutating run bumps `run_marker`.** A TAG input is resolved server-side, so nothing in the
  configuration tells the provider a tag moved — it plans no change and waits for no run. Bumping an
  input it does track makes it issue an update and await a run, and that run resolves the current tag
  values.
- **`tag_settle_duration` lets meshStack's own run get out of the way.** That run competes with the
  one the test triggers: `awaitRun` polls the block's aggregate status and stops at the first
  terminal one, so the wrong run's outputs can land in state, and meshStack rejects an update issued
  while a run is in flight. The wait is a `time_sleep` replaced per scenario via `triggers`, not a
  polling script. If it turns out an update during an in-flight run does not 409, drop it to `"0s"`
  and save six minutes per run.

## Scenarios

The three `run` blocks in `../tests/building_block_noop_tag_inputs_hub.tftest.hcl` share one state,
so each is a change to the one before it. Each changes as little as possible, so a failed assertion
names one mechanism rather than three.

| scenario | change | asserts |
|---|---|---|
| `initial` | — | all three tags resolve; the landing zone tag carries two values, so a list is really a list |
| `changed_values` | all three tag values edited | the new values resolve |
| `reassigned_payment_method` | no tag edited; the project is funded from the substitute payment method | `payment_method` follows the new source, the other two are untouched |

The third case is meshfed's `onProjectPaymentMethodChanged`, the cheapest of the four reassignment
triggers to exercise.

`WORKSPACE` is deliberately out of scope: tagging the shared test workspace needs
`meshstack_workspace_tag`, which the provider's own docs mark "not recommended for general use"
(whole-workspace read-modify-write, races within a single apply).
