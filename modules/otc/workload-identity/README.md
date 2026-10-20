# T Cloud Public Workload Identity (shared)

Lets one building block definition sign in through workload identity federation instead of an access
key. The `opentelekomcloud` provider cannot sign in with an OIDC token itself, so this has two parts:

- **The Terraform module**, used by each service's backplane:
  - an OIDC identity provider for programmatic access that trusts meshStack's run issuer. Its one
    mapping rule matches only the definition's subject, and signs it in as a virtual user;
  - an IAM group for that user, holding `domain_roles` and the custom `policies`.
- **`prerun.sh`**, the definition's pre-run script. It exchanges the run token at the identity
  provider in `OTC_IDENTITY_PROVIDER` for a federated IAM token, then that for a temporary access
  key valid for one hour, and writes it to `otc_credentials.json`. The building block's provider
  reads it from there.

## Operational notes

- The identity provider holds a copy of the issuer's signing keys. When meshStack rotates them, runs
  fail at the token exchange until the backplane is applied again.
- The rule trusts the subject of the definition's newest version, see
  [Runner identity](../../../.agents/references/meshstack-integration.md#runner-identity).
- `all_projects` policies apply to every project in the domain, not only those of the landing zone.
