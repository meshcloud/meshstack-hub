---
description: Architecture diagram conventions for meshstack-hub. Graphviz DOT sources with committed SVGs, the shared colour palette and emoji vocabulary that keep diagrams looking like one family, layout-control attributes (rank=same, constraint=false, splines=ortho), label discipline, and why Mermaid was dropped.
---

# Architecture Diagrams

Diagrams are **Graphviz DOT** source committed next to the Markdown that uses them, with the rendered
SVG committed alongside:

```
reference-architectures/
├── azure-kubernetes.md     # references the SVG: ![...](azure-kubernetes.svg)
├── azure-kubernetes.dot    # the source you edit
└── azure-kubernetes.svg    # generated — never hand-edit
```

```sh
task diagrams        # re-render every *.dot in the repo to a sibling *.svg
task diagrams:check  # verify committed SVGs match their sources (what CI runs)
```

Graphviz runs from a WASM npm package, so no system `dot` install is needed. CI fails when a `.dot`
is edited without committing the re-rendered SVG.

---

## Composition

**Separate the systems into top-level clusters.** The single most effective structural choice is one
box per system — the cloud provider's resource hierarchy in one, meshStack's constructs in the other —
with the relationships drawn as dotted edges across the boundary. The reader sees two worlds they
already understand and one set of lines explaining how they connect, instead of one undifferentiated
graph.

```dot
subgraph cluster_stackit { label="  STACKIT" /* org, folders, projects */ }
subgraph cluster_mesh    { label="  meshStack" /* platform, landing zones, BBDs */ }

FOUND -> PLAT [style=dotted constraint=false xlabel="authenticates"]
```

Use a **lifecycle split** instead (catalog / per application team / existing infrastructure) when the
diagram's story is *who does what and when* rather than *how two systems map onto each other*. Do not
mix both splits in one diagram — pick the one that matches the story and let colour carry the rest.

**Give each cluster its own depth.** A cluster holding one node reads as noise; either merge it into
a neighbouring cluster or let the node stand alone at the top level. Where a system has layers, show
them (platform → landing zone → building block definition).

---

## Palette

Colour encodes **what kind of thing a box is**, never decoration. Never introduce a new colour to
distinguish two boxes of the same kind.

| Role | Fill | Border | Use for |
|------|------|--------|---------|
| `definition` | `#ecedfb` | `#9aa2e6` | meshStack constructs: platform, landing zone, building block definition |
| `instance` | `#e5f2ea` | `#85bfa0` | what a tenant ends up with: project, network, namespace, repo |
| `provider` | `#eef2f6` | `#93a7bb` | services the cloud provider runs: managed cluster, registry, model API |
| `structure` | `#ffffff` | `#a2abb8` | containers and grouping objects: organization, folder |
| `muted` | `#f0f1f3` | `#cdd2d8` | shown for context only, not managed by this architecture |

`muted` nodes also take `style="rounded,filled,dashed"` and `fontcolor="#99a1ac"` so they read as
out-of-scope even in greyscale.

Supporting greys: cluster border `#d5dae0`, cluster label `#697180`, edge `#8b95a3`, edge label
`#697180`.

---

## Emoji vocabulary

Every node label opens with an emoji, and the **same concept always gets the same emoji** across
diagrams. This is what makes separate diagrams read as one family, and it lets a reader match a box
in one diagram to a box in another without reading the label.

| Emoji | Concept |
|-------|---------|
| 🏢 | organization / tenant root |
| 📁 | folder / resource group |
| 🗂️ | project / subscription |
| 🔑 | service account, credentials |
| 🌐 | network area, address plan |
| 🔌 | network, subnet |
| ☸️ | Kubernetes cluster |
| 🗄️ | container registry |
| ⚙️ | CI/CD wiring |
| 🔀 | git repository |
| 🧠 | model serving / AI API |
| 🛰️ | meshStack platform |
| 🛬 | landing zone |
| 📦 | building block definition |

Extend the table when a diagram needs a concept it does not cover — do not invent a second emoji for
a concept already listed.

Copy the emoji straight from this table — several of them carry a **U+FE0F variation selector** that
is invisible in the source but decides whether the glyph renders in colour. `☸ ⚙ 🗄 🗂 🛰` default to
*text* presentation and come out as small monochrome symbols without it; `🏢 📁 🔑 🌐 🔌 🔀 🧠 🛬 📦`
are colour by default. If an icon renders monochrome in the SVG, it is missing the selector.

The **same emoji with a different fill** is deliberate and useful: a green `🔀` repo inside the
application-team box and a provider-coloured `🔀` in the STACKIT box say "same concept, different
owner" in a way two different icons never could. Emoji carries the concept, colour carries the kind.

---

## Preamble

Start every diagram from this block so spacing, type and stroke weight match across the repo:

```dot
digraph <name> {
  rankdir=TB
  splines=ortho
  forcelabels=true
  bgcolor="white"
  nodesep=0.55
  ranksep=0.85

  node [shape=box style="rounded,filled" fontname="Helvetica" fontsize=11
        fillcolor="#ffffff" color="#a2abb8" penwidth=1.1 margin="0.20,0.11"]
  edge [fontname="Helvetica" fontsize=9 fontcolor="#697180" color="#8b95a3" arrowsize=0.7]
}
```

Cluster styling, with two leading spaces in the label so it clears the rounded corner:

```dot
subgraph cluster_team {
  label="  Per Application Team"
  labeljust=l
  fontname="Helvetica" fontsize=12 fontcolor="#697180"
  style="rounded" color="#d5dae0"
  margin=18
}
```

`bgcolor="white"` is not optional. A transparent background renders dark-on-dark for anyone reading
the diagram in GitHub's dark theme.

---

## Layout control

These are the attributes Mermaid lacks, and the reason for the render step:

- **`{ rank=same; A B C }`** pins nodes to one row. This is how sibling folders end up at the same
  height instead of staggered down a diagonal.
- **`constraint=false`** draws an edge without letting it influence ranking. Use it for every
  cross-cutting relationship — a mapping between two clusters, or a link back up a hierarchy — that
  would otherwise distort the layout it is describing.
- **`style=invis`** edges inside a `rank=same` block nudge left-to-right order:
  `{ rank=same; DEV -> PROD [style=invis] }`. Treat it as a hint, not a guarantee — always confirm the
  rendered order.
- **`splines=ortho`** gives right-angle connectors, which read as a wiring diagram rather than a mind
  map.

Traps, each of which cost a debugging round:

- Under `splines=ortho`, use **`xlabel`** (with `forcelabels=true`) for edge labels. Plain `label`
  gets placed far from its edge, sometimes in open space.
- **Never set `ordering=out`.** It fights rank ordering and silently mirrors rows — a `rank=same`
  chain of `dev -> prod` came out as `prod`, `dev`, and reversing the chain changed nothing.
- **Avoid `newrank=true`** unless a `rank=same` must span clusters. It makes cluster boxes overlap.
- A **`constraint=false` edge between two nodes on the same rank is itself a flat edge** and outranks
  your invisible ordering chain. `HARBOR -> SKE [constraint=false]` silently pulled `SKE` out of the
  declared `SKE -> MODEL -> HARBOR` order. Declare the chain in the direction the real edge implies
  instead of fighting it.
- `splines=polyline` is not a substitute for `ortho` — it produces diagonals and more crossings.

---

## Labels

- Label the **relationship**, not the objects: `provisioned by`, `target folder of`, `deploys to`.
- On parallel edges that mean the same thing (a dev and a prod edge into the same registry), label
  **one** of the pair. Repeating it doubles the text for no information and the labels collide.
- Keep labels to three or four words. Push detail into the node's second line, which is quieter:
  `label="🔌 Routed Network ×N\nspoke subnet"`.
- Use `×N` / `×1` to show cardinality rather than drawing several identical boxes.

---

## Diagrams in Markdown

Reference the SVG with a plain relative image link:

```markdown
![Azure Kubernetes reference architecture](azure-kubernetes.svg)
```

Do **not** inline HTML or `<svg>` in a Markdown body. The hub website renders these files through
`marked` into Angular's `[innerHTML]`, which strips `<style>` blocks, `style` attributes and inline
SVG; GitHub's Markdown pipeline does the same. `index.ts` rewrites relative image links to absolute
`raw` URLs pinned to the built commit, so one relative link works on GitHub and on the website.

---

## Why not Mermaid

Mermaid renders inline in Markdown with no build step, which is genuinely convenient. It was dropped
because it offers no way to constrain layout: there is no "keep these three nodes on one row" and no
"this edge must not affect ranking". Any diagram with two related hierarchies comes out as diagonal
spaghetti, cross-cluster edges render as unconnected stubs when a subgraph declares its own
`direction`, and each attempted fix fights the engine instead of the diagram.

---

## Checklist

- [ ] `<name>.dot` committed next to the Markdown, `<name>.svg` regenerated with `task diagrams`
- [ ] Markdown references the SVG with a relative `![...](<name>.svg)` link
- [ ] Preamble matches the block above, including `bgcolor="white"`
- [ ] Top-level clusters separate systems (or lifecycle stages) — not both in one diagram
- [ ] Every node label opens with an emoji from the vocabulary
- [ ] Every fill/border pair comes from the palette, and colour encodes kind
- [ ] Sibling nodes that belong on one row are pinned with `rank=same`
- [ ] Cross-cutting edges use `constraint=false`
- [ ] Edge labels use `xlabel`, name the relationship, and are not repeated on parallel edges
- [ ] `task diagrams:check` passes
