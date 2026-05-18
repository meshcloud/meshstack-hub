---
name: meshStack Manual Building Block
supportedPlatforms:
  - meshstack
description: |
  Reference building block demonstrating meshStack's MANUAL implementation type:
  selected input types mirrored to outputs, with additional inputs that have no corresponding output.
---
# meshStack Manual Building Block

This building block is a reference implementation demonstrating how meshStack handles the MANUAL implementation type. It exercises output mirroring (outputs copy input values 1:1), the constraint that some input types (e.g. `SINGLE_SELECT`) have no corresponding output type, and the validity of having more inputs than outputs.

Use it to:
- Understand how meshStack handles MANUAL building blocks
- See which input types can be mirrored to outputs
- Validate that extra inputs (with no matching output) are allowed

## Input Types

| Input | Type | Assignment | Mirrored to Output |
|-------|------|-----------|-------------------|
| `text` | `STRING` | `USER_INPUT` | ✅ |
| `flag` | `BOOLEAN` | `USER_INPUT` | ✅ |
| `num` | `INTEGER` | `USER_INPUT` | ✅ |
| `single_select` | `SINGLE_SELECT` | `USER_INPUT` | ❌ (no corresponding output type) |
| `static_note` | `STRING` | `STATIC` | ❌ (extra input without output) |
