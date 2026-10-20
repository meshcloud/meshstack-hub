# T Cloud Public OBS Bucket – Backplane

Lets the OBS bucket building block sign in through workload identity federation instead of an access
key:

- **An OIDC identity provider for programmatic access** that trusts meshStack's run issuer. Its one
  mapping rule matches only the subject of this building block definition, and signs it in as a
  virtual user in the group below.
- **An IAM group with what the building block needs:**
  - Security Administrator on the domain, because the upstream module creates an IAM user, a group
    and custom roles for every bucket;
  - a custom role allowing `obs:*:*`, through the `MOS` project;
  - a custom role allowing `kms:*:*` in the region's project.

Apply it with credentials holding Security Administrator, with the provider targeting the region's
own project (`tenant_name = "eu-de"`).

## Operational notes

- The identity provider holds a copy of the issuer's signing keys. When meshStack rotates them, runs
  fail at the token exchange until the integration is applied again.
- The rule trusts the subject of the definition's newest version, see
  [Runner identity](../../../../.agents/references/meshstack-integration.md#runner-identity).
