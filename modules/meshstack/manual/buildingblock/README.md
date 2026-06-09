---
name: meshStack Manual Building Block
supportedPlatforms:
  - meshstack
description: |
  Reference building block demonstrating meshStack's MANUAL implementation type:
  the backend derives one output per input, translating types that cannot be outputs.
---
# meshStack Manual Building Block

This building block is a reference implementation demonstrating how meshStack handles the MANUAL implementation type. It exercises output mirroring: the backend derives one output per input (assignment type `NONE`), copying input values 1:1 at run time. Input types that cannot be output types are translated — `SINGLE_SELECT` becomes `STRING`, `MULTI_SELECT`/`LIST` become `CODE` — and `STATIC` inputs (supplied by the definition, not the user) are mirrored too.

Use it to:
- Understand how meshStack handles MANUAL building blocks
- See how each input type is mirrored to an output (and how non-output types are translated)
- Note that outputs are computed: `version_spec.outputs` is omitted from configuration and reconciled from the API

## Input Types

| Input | Type | Assignment | Output Type |
|-------|------|-----------|-------------|
| `text` | `STRING` | `USER_INPUT` | `STRING` |
| `flag` | `BOOLEAN` | `USER_INPUT` | `BOOLEAN` |
| `num` | `INTEGER` | `USER_INPUT` | `INTEGER` |
| `single_select` | `SINGLE_SELECT` | `USER_INPUT` | `STRING` (translated) |
| `static_note` | `STRING` | `STATIC` | `STRING` |
