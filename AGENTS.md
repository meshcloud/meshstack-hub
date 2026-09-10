# meshstack-hub — Agent Instructions

The canonical registry of OpenTofu building blocks for meshStack — an Artifactory-like catalog with
a UI at hub.meshcloud.io, and the monorepo for every IaC building block importable into any
meshStack instance. IaC runtimes (LCF, ICF, customer foundations) consume these modules as shims:
they reference a module, they never re-implement its logic.

**CI proves almost nothing about a module.** It runs `pre-commit run --all-files` (`terraform-docs`,
`terraform fmt`, trailing whitespace, `ci/validate_modules.sh`) and the scorecard — never `plan` or
`apply`. Only an [e2e run](.agents/skills/e2e-test/SKILL.md#verify-before-merging) shows a module
works.

## Layout

```
modules/<provider>/<service>/    backplane/, buildingblock/, meshstack_integration.tf, e2e/
reference-architectures/<cloud>-<capability>/
.agents/references/, .agents/skills/   agent instructions — authoritative, this file only routes
tools/scorecard/                 module maturity checks
website/                         public/assets/ is generated; never add files there by hand
```

## Instruction files — load the ones matching what you touch

- **A module's files, docs or logo** — two-tier layout, `README.md` front-matter, which readme the
  app team reads, checklist for new modules →
  [module-layout.md](.agents/references/module-layout.md). For the create/update workflow use the
  [`module` skill](.agents/skills/module/SKILL.md).
- **`meshstack_integration.tf`** — variable and block order, `variable "hub"` / `variable
  "meshstack"`, module sources and BBD `ref_name` pinned by `var.hub.git_ref`, BBD
  `terraform_version`, `building_block_definition` output →
  [meshstack-integration.md](.agents/references/meshstack-integration.md)
- **Any meshStack provider resource**, in a module or a reference architecture — `*_ref` attributes,
  `meshstack_platform` lifecycle, run-status postcondition on every child building block →
  [meshstack-resources.md](.agents/references/meshstack-resources.md)
- **Any HCL** — OpenTofu-only toolchain, `lifecycle.enabled` over `count`, `snake_case`, provider
  versions floating inside one major, commenting what a `try` swallows →
  [terraform-conventions.md](.agents/references/terraform-conventions.md)
- **The app-team readme** — BBD `readme` field or `APP_TEAM_README.md` →
  [bbd-readme.md](.agents/references/bbd-readme.md)
- **A backplane's identity and permissions** →
  [aws](.agents/references/aws-backplane.md) ·
  [azure](.agents/references/azure-backplane.md) ·
  [gcp](.agents/references/gcp-backplane.md) ·
  [stackit](.agents/references/stackit-backplane.md)
- **Tests** — `e2e/` is the only place a `*.tftest.hcl` runs →
  [`e2e-test` skill](.agents/skills/e2e-test/SKILL.md)
- **A reference architecture** under `reference-architectures/` →
  [reference-architectures.md](.agents/references/reference-architectures.md)
- **A diagram** — Graphviz DOT source plus committed SVG, rendered by `task diagrams` →
  [diagrams.md](.agents/references/diagrams.md)

## Always

- A comment carries what the code can't — a reason, a constraint, a tradeoff. Never restate a rule
  from these instruction files; link to it when the connection isn't obvious. Assume the reader has
  read them.
- Check a module you touched, and fix the module rather than the check:
  ```sh
  node tools/scorecard/scorecard.mjs --module=<provider>/<service> [--fix]
  ```
- Prototyping from an IaC runtime may point a `source` at a local path
  (`../../../meshstack-hub/modules/<provider>/<service>/buildingblock`). Never commit that — switch
  back to the hub GitHub URL first.
- No trailing whitespace.
