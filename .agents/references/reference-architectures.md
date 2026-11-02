---
description: Conventions for meshstack-hub reference architectures under reference-architectures/ — folder structure, README.md front-matter (name, description, cloudProviders, buildingBlocks), required body sections, logo placement, tests, the scorecard, and the checklist for new reference architectures.
---

# Reference Architectures

Reference architectures are curated, end-to-end blueprints that show how multiple Hub building blocks
fit together to deliver a complete platform capability. They live in the `reference-architectures/`
directory at the repo root, one folder per architecture — mirroring how modules are laid out.

## Folder structure

```
reference-architectures/<cloud>-<capability>/
├── README.md                  # front-matter + body (this is the architecture)
├── logo.png                   # optional — falls back to the cloud provider logos on the website
├── <cloud>-<capability>.dot   # optional — diagram source
├── <cloud>-<capability>.svg   # optional — generated, committed alongside
├── meshstack_integration.tf   # optional — makes the architecture importable into meshStack
└── buildingblock/             # optional — Terraform for the importable architecture
```

`buildingblock/README.md` is maintained by hand. terraform-docs only runs on the `backplane/` and
`buildingblock/` folders of hub modules, so a ref arch readme has no generated section.

The folder name is the architecture id used in website URLs. A folder without a `README.md` is
ignored by the website generator.

## File format

```yaml
---
name: Human-Readable Architecture Name
description: >
  A concise paragraph explaining the architecture's purpose and value proposition.
cloudProviders:
  - azure
buildingBlocks:
  - path: azure/aks
    role: Short description of this block's role in the architecture.
  - path: aks/github-connector
    role: Short description of this block's role in the architecture.
---

# Architecture Title

Markdown body with overview, architecture diagram, how-it-works walkthrough,
getting-started steps, and shared responsibility matrix.
```

<!-- scorecard-checks: ref_arch_diagram -->
## Conventions

- Folder name: `<cloud>-<capability>` (e.g. `azure-kubernetes`, `stackit-kubernetes`), with the
  architecture itself in `README.md`.
- Logo: colocate as `logo.png` (or `logo.svg`) in the architecture folder, the same convention
  `buildingblock/logo.png` uses. The website generator copies it to
  `website/public/assets/reference-architecture-logos/<id>.png` — never add files there by hand,
  that directory is generated and gitignored.
- `buildingBlocks[].path` must match a module path under `modules/` (e.g. `azure/aks`).
- The Markdown body should include an **architecture diagram** showing how blocks relate — see
  [diagrams.md](diagrams.md) for the format.
- Include a **shared responsibility matrix** (platform team vs. application team) with ✅ / ❌ emojis.
- Include **Getting Started** steps with prerequisites and deployment order.

## Checklist for New Reference Architectures

- [ ] Folder `reference-architectures/<cloud>-<capability>/` containing a `README.md` with YAML front-matter
- [ ] `logo.png` colocated in the architecture folder (no logo files added under `website/public/assets/`)
- [ ] `name`, `description`, `cloudProviders`, and `buildingBlocks` fields present
- [ ] Every `buildingBlocks[].path` references an existing module in `modules/`
- [ ] Every `buildingBlocks[].role` has a one-sentence description
- [ ] Body includes: overview, architecture diagram, how-it-works, getting started, shared responsibilities
- [ ] Diagram committed as `<name>.dot` + generated `<name>.svg`, referenced with `![...](<name>.svg)`
- [ ] `task diagrams` run and the regenerated SVG committed
- [ ] No trailing whitespace

---

An importable architecture (`meshstack_integration.tf` + `buildingblock/`) follows the same rules as
a module: [meshstack-integration.md](meshstack-integration.md) and
[meshstack-resources.md](meshstack-resources.md).

<!-- scorecard-checks: ref_arch_children_version_latest, ref_arch_hub_ref_from_caller, ref_arch_approval_policies -->
## Ordering Building Blocks

- Order every child building block from `version_latest`, directly or through a module's
  `building_block_definition.version_ref`, and hand out `version_latest` in outputs. A
  `{ uuid = ... }` built by hand pins one version.
- Take the Hub ref from the caller, as a module integration does: module sources end in
  `?ref=${var.hub.git_ref}`, the BBD sets `ref_name = var.hub.git_ref`, and asset URLs such as the
  `symbol` use the same ref.
- The definition takes `spec.approval_policies` from an `approval_policies` variable, so whoever
  installs the architecture can gate its runs.

## Review Rules

The scorecard does not check these; a reviewer does.

- An input that only matters in one mode carries a `condition` (CEL): `imports` only when adopting,
  playground knobs only with `playground_mode`.
- A resource the architecture can adopt follows the imports pattern of its module: an `imports`
  input decides between creating (`null`) and importing (an object), and `release_on_destroy`
  leaves an adopted resource in place on destroy.

<!-- scorecard-checks: ref_arch_e2e -->
## Testing

An importable architecture has an `e2e/main.tf` with its tests under `e2e/tests/`: the smoke tests
discover it by that file and run it like a module e2e. The rules of the
[`e2e-test` skill](../skills/e2e-test/SKILL.md#where-terraform-tests-live) apply: every test runs
against real infrastructure, and no `*.tftest.hcl` lives outside `e2e/`.

## Scorecard

```sh
node tools/scorecard/scorecard.mjs --ref-archs            # every reference architecture
node tools/scorecard/scorecard.mjs --ref-arch=<name> [--fix]
node tools/scorecard/scorecard.mjs --changed-since=origin/main  # what the branch changed, as in the PR comment
```

It scores the practices it shares with modules (no credentials in outputs, refs over uuids,
structured inputs and defaults), the rules of [Ordering Building Blocks](#ordering-building-blocks),
the diagram and the tests. An architecture without code fails its code and e2e checks with "no
buildingblock code yet", so the report reads as its todo list. For the modules it includes — those
its code sources or registers and those its front-matter lists — it shows a one-line summary of
their module scorecard; fix a finding there with `--module=<provider>/<service>`.
