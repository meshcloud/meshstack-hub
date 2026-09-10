---
description: Conventions for meshstack-hub reference architectures under reference-architectures/ — folder structure, README.md front-matter (name, description, cloudProviders, buildingBlocks), required body sections, logo placement, and the checklist for new reference architectures.
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
[meshstack-resources.md](meshstack-resources.md). The scorecard only scans `modules/`, so nothing
here checks them for you.
