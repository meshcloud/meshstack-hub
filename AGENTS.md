# meshstack-hub — Agent Instructions

The canonical registry of OpenTofu building blocks for meshStack — an Artifactory-like catalog with
a UI at hub.meshcloud.io, and the monorepo for every IaC building block importable into any
meshStack instance.

Platform engineers can reference modules from the hub in their own IaC repositories and deploy
building block definitions, reference architectures and other assets to their own meshStack
instances. We call these customer repositories **foundation repositories**, because they are
typically owned by a cloud foundation team. A foundation repository references a module, it never
re-implements its logic. meshcloud maintains two public ones:

- [likvid-bank/likvid-cloudfoundation](https://github.com/likvid-bank/likvid-cloudfoundation) — the
  demo foundation of a fictional bank
- [meshcloud/trial-cloudfoundation](https://github.com/meshcloud/trial-cloudfoundation) — the
  foundation behind shared meshStack trials

**CI in this repo is linting only.** It runs `pre-commit run --all-files` (`terraform-docs`,
`terraform fmt`, trailing whitespace, `ci/validate_modules.sh`) and the scorecard — never `plan` or
`apply`. Only an [e2e run](.agents/skills/e2e-test/SKILL.md#verify-before-merging) shows a module
works.

## Domain concepts

- **building block definition (BBD)** — published by a platform team, defining inputs, outputs and
  automation: a reusable tofu module to deploy, or a GitOps pipeline to execute.
- **building block (BB)** — an instance of a BBD consumed by an application team, with specific
  input and output values.
- **backplane** — what a BBD needs in order to create BB instances: typically cloud principals,
  permissions and shared resources.
- **hub module** — packages a backplane + BBD + BB module, so platform engineers can configure and
  deploy it to their meshStack instance.
- **reference architecture** — packages several hub modules and pre-configures them for one
  solution, for example a landing zone deployment.

## Layout

```
modules/<provider>/<service>/    backplane/, buildingblock/, meshstack_integration.tf, e2e/
reference-architectures/<cloud>-<capability>/
.agents/references/, .agents/skills/   agent instructions — authoritative, this file only routes
tools/scorecard/                 module maturity checks
website/                         public/assets/ is generated; never add files there by hand
```

## Instruction files — load the ones matching the files you touch

- `modules/*/*/**` — two-tier layout, `README.md` front-matter, logos, which readme the app team
  reads, checklist for new modules →
  [module-layout.md](.agents/references/module-layout.md). For the create/update workflow use the
  [`module` skill](.agents/skills/module/SKILL.md).
- `*/meshstack_integration.tf` — variable and block order, `variable "hub"` / `variable
  "meshstack"`, module sources and BBD `ref_name` pinned by `var.hub.git_ref`, BBD
  `terraform_version`, overridable catalog properties (`bbd_*`), `building_block_definition` output →
  [meshstack-integration.md](.agents/references/meshstack-integration.md)
- Any `.tf` declaring a `meshstack_*` resource — `*_ref` attributes, `meshstack_platform`
  lifecycle, run-status postcondition on every child building block →
  [meshstack-resources.md](.agents/references/meshstack-resources.md)
- Any `.tf` — OpenTofu-only toolchain, `lifecycle.enabled` over `count`, `snake_case`, provider
  versions floating inside one major, commenting what a `try` swallows →
  [terraform-conventions.md](.agents/references/terraform-conventions.md)
- The app-team readme — the BBD `readme` field, or `**/buildingblock/APP_TEAM_README.md` →
  [bbd-readme.md](.agents/references/bbd-readme.md)
- `modules/<provider>/*/backplane/**` — identity and permissions →
  [aws](.agents/references/aws-backplane.md) ·
  [azure](.agents/references/azure-backplane.md) ·
  [gcp](.agents/references/gcp-backplane.md) ·
  [stackit](.agents/references/stackit-backplane.md)
- `modules/*/*/e2e/**` and every `*.tftest.hcl` — `e2e/` is the only place one runs →
  [`e2e-test` skill](.agents/skills/e2e-test/SKILL.md)
- `reference-architectures/**` →
  [reference-architectures.md](.agents/references/reference-architectures.md)
- `**/*.dot` — Graphviz source plus committed SVG, rendered by `task diagrams` →
  [diagrams.md](.agents/references/diagrams.md)

## Always

- A comment carries what the code can't — a reason, a constraint, a tradeoff. Never restate a rule
  from these instruction files; link to it when the connection isn't obvious. Assume the reader has
  read them.
- Check a module you touched, and fix the module rather than the check:
  ```sh
  node tools/scorecard/scorecard.mjs --module=<provider>/<service> [--fix]
  ```
- Prototyping from a foundation repository may point a `source` at a local path
  (`../../../meshstack-hub/modules/<provider>/<service>/buildingblock`). Never commit that — switch
  back to the hub GitHub URL first.
- No trailing whitespace.
