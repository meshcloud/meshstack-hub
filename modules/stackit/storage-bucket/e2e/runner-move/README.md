# Runner move e2e fixture

Covers `meshstack.trusted_runner_refs`: a building block on an older definition version still signs
in after the definition moves to another building block runner.

The test has two steps that share one state, because its subject is a change:

1. `released_on_old_runner` releases version 1 of the definition on the old runner and creates a
   building block on it.
2. `moved` moves the definition to the new runner, which creates version 2 as a draft, and lists the
   old runner in `trusted_runner_refs`. It changes the bucket name of the first building block, so
   that it runs again on version 1 and on the old runner. It creates a second building block on
   version 2.

The second run of the first building block is the proof. Without the trusted runner, the backplane
would trust only the new runner, and that run would fail to sign in.

The fixture is hub mode only. It needs two runners with different issuers that both offer the Azure
token, which STACKIT takes as a generic OIDC token. `old_runner` and `new_runner` name them by
display name and owning workspace; the defaults are the two hosted runners of meshcloud-dev.
