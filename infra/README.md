# infra

The hub's own infrastructure, as Terragrunt units sharing the backend in `root.hcl`. Each unit keeps
its state in `gs://meshcloud-tf-states/meshstack-hub/infra/<unit>`.

| Unit | Manages | Credentials |
|---|---|---|
| `github` | Repository rulesets, the `main` environment and the CI deploy key | `GITHUB_TOKEN` |
| `amplify` | The Amplify app hosting hub.meshcloud.io, its `main` branch and the custom domain | `AWS_PROFILE=meshstack-hub` |

Both need gcloud application default credentials for the state bucket. Run a unit from its folder:

```sh
cd infra/amplify
AWS_PROFILE=meshstack-hub TG_TF_PATH=tofu terragrunt plan
```

The `pr-*` branches of the Amplify app are pull request previews that Amplify creates and deletes on
its own; they are deliberately not managed here.
