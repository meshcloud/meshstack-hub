---
name: meshStack GitLab Pipeline NoOp
supportedPlatforms:
  - meshstack
description: |
  Reference building block for meshStack's GitLab pipeline implementation type: it provisions
  nothing and reports every input it received back as an output.
# Everything this module needs is a static input: the project, the branch and a trigger token. It
# provisions nothing cloud-side, so there is no backplane tier — and no tofu module either, because
# the implementation is a GitLab pipeline.
requiresBackplane: false
---
# meshStack GitLab Pipeline NoOp

This module is the GitLab counterpart of [`meshstack/noop`](../../noop). Where that one documents the
Terraform interface, this one documents what a **GitLab CI/CD pipeline** receives from meshStack and
what it has to send back. It provisions nothing.

The pipeline itself is [`./gitlab-ci.yml`](./gitlab-ci.yml). You copy it into your GitLab project —
see [Setup](#setup) below.

## How meshStack talks to a GitLab pipeline

meshStack triggers the pipeline and then waits. It never polls GitLab, so **a pipeline that does not
report back leaves the building block running forever**. The pipeline registers itself as a run
source and reports its own terminal status, and a separate `report-failure` job covers the case where
the main job dies before it can.

The run token is the pipeline's only credential, and it arrives inside the `MESHSTACK_RUN` variable
rather than as a variable of its own.

## The two input channels

| `is_environment` | Arrives as | Declared in `spec:inputs`? | Limits |
|---|---|---|---|
| `true` | CI variable of the same name | no | 10,000 characters per value |
| `false` (default) | GitLab pipeline input | **required** — GitLab rejects undeclared inputs | 20 inputs, 1 KB each |

Two consequences worth knowing before you copy this module:

- **Values from the trigger are strings, and not always JSON.** A list arrives as `[multi1, multi2]`,
  which no JSON parser accepts. Read structured values from the run object instead — the pipeline
  fetches it from `MESHSTACK_SELF_URL` and that copy is properly typed and not length-capped.
- **Sensitive values are the exception.** meshStack serves them encrypted and only a runner holds the
  key, so a sensitive input is readable by a pipeline *only* through the trigger payload, and only if
  you mark it `is_environment = true`. The `sensitive_in_run_object_is_plaintext` output records what
  the API actually served.

Because pipeline inputs and the `spec:inputs` header must agree exactly, adding an input to the
definition without adding it to the pipeline file breaks every run. Marking an input
`is_environment = true` avoids that coupling entirely.

## Inputs

`text`, `num` and `flag` take the pipeline-input channel. Everything else takes the variable channel:
`single_select`, `multi_select`, `optional_text`, `conditional_text`, `code_json`, `json_form`,
`file_yaml`, `sensitive_text`, `static_text`, `author`, `user_permissions`, `workspace_identifier`
and `operator_text`.

`optional_text` is never filled in and `conditional_text`'s condition never holds, so neither is sent
at all — that absence is the thing they demonstrate.

## Outputs

`received_from_run_object_json` and `received_from_trigger_json` hold the same inputs as each channel
delivered them; comparing the two is the point of this module. Alongside them are typed echoes
(`text`, `num`, `flag`), the `behavior` of the run, the `pipeline_url`, a `summary`, and
`sensitive_in_run_object_is_plaintext`.

## Setup

This module has no backplane, so the two GitLab-side steps are yours:

1. **Copy [`./gitlab-ci.yml`](./gitlab-ci.yml) to `.gitlab-ci.yml`** on the branch you will point
   `gitlab_branch` at. Started by anything other than meshStack, the pipeline prints its environment
   and exits 0 — so pushing it is already the check that the project has a working runner.
2. **Create a pipeline trigger token** under *Settings → CI/CD → Pipeline triggers* and pass it as
   `gitlab_pipeline_trigger_token`. It only starts pipelines in this one project.

Terraform deliberately does neither for you. Committing a file and creating a trigger both need the
`api` scope, and on GitLab Free the token types built for automation — project and group access
tokens, service accounts — are Premium features. Requiring one would mean a personal access token
carrying its owner's full reach, to save two clicks.

Also needed:

- A runner that picks up the project's pipelines. On gitlab.com's free tier, instance runners stay
  idle until the account passes identity verification, and meshStack reports that as
  *"There is a problem with the pipeline trigger token"*.
- GitLab 17.11 or newer for the pipeline-input channel. On an older instance, mark every input
  `is_environment = true` and drop the `spec:inputs` header.
