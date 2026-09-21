---
name: Azure DevOps Pipeline Building Block
supportedPlatforms:
  - meshstack
description: |
  Reference building block for meshStack's Azure DevOps pipeline implementation type: it queues an
  Azure DevOps pipeline, checks that every value meshStack sent arrived, and provisions nothing.
---
# Azure DevOps Pipeline Building Block

This module is the Azure DevOps counterpart of [`meshstack/github-workflow`](../../github-workflow).
Where that one documents what a GitHub Actions workflow receives from meshStack, this one documents
what an **Azure DevOps pipeline** receives — and what it cannot send back. It provisions nothing.

The pipeline itself is [`../backplane/pipelines/azure-pipelines.yml`](../backplane/pipelines/azure-pipelines.yml),
committed into your repository by the [backplane](../backplane/README.md).

## How meshStack talks to an Azure DevOps pipeline

meshStack queues a run of a pipeline **definition**, addressed by its numeric id, and then polls it:
it reads the run and its timeline every few seconds, maps each pipeline **stage** onto a step of the
building block run, and finishes when the pipeline reaches a terminal result. Polling stops after 30
minutes and fails the building block.

Two consequences worth knowing before you build on this module:

- **The pipeline definition has to exist already.** A definition is what carries the numeric id, and
  committing a YAML file does not create one. The backplane writes the file; you create the
  definition (by hand, or with [`azuredevops/pipeline`](../../../azuredevops/pipeline)) and pass its
  id in.
- **A pipeline reports no outputs.** The runner reads the timeline for status and nothing else, so
  the definition declares no outputs. Anything a pipeline needs to tell you has to be an assertion
  inside the pipeline: a failing stage is the only signal that reaches meshStack. Use the
  [`gitlab-pipeline`](../../gitlab-pipeline) module's callback approach as a reference for what
  reporting outputs would take.

## How inputs arrive

Every input reaches the pipeline as an Azure DevOps **template parameter** of the same name, with its
value stringified. meshStack adds one parameter of its own, `MESHSTACK_BEHAVIOR`, carrying `APPLY`,
`DESTROY` or `DETECT` — one pipeline serves every behaviour, because the implementation names a
single pipeline id.

Two rules follow from Azure DevOps, and breaking either one fails every run:

- **The pipeline's `parameters:` block must declare every input.** Azure DevOps rejects a queued run
  that carries a template parameter the YAML does not know, so an input added to the definition
  without a matching parameter in the file breaks the definition at trigger time, not at apply time.
- **Do not mark an input `is_environment`.** The block runner filters those out of the trigger
  payload, and Azure DevOps offers no variable channel to deliver them on instead, so the pipeline
  simply never sees the value.

## Which branch the pipeline runs on

The definition's `ref_name` is sent as the run's `resources.self.refName`, so a run executes **that
ref's copy** of the YAML rather than the definition's default branch. The backplane commits onto the
same ref, which is what keeps the file and the definition's inputs in step — and what lets the
[e2e test](../e2e) give each run its own ephemeral branch without touching the shared one.

## Setup

1. Create an Azure DevOps Git repository, or pick an existing one, and note its UUID.
2. Create a pipeline definition pointing at that repository and at the YAML path the backplane
   writes (`azure-pipelines.yml` by default). Note its `definitionId`.
3. Create a personal access token with Build (Read & execute) and Code (Read & write) — see
   [backplane/README.md](../backplane/README.md) on splitting those.
4. Copy [`../meshstack_integration.tf`](../meshstack_integration.tf) into your foundation repository
   and fill in the `azuredevops_*` variables.
