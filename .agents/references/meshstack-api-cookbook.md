# meshStack API cookbook for migration work

Every meshObject type needs its own versioned `Accept` header, and the wrong one fails in a way that looks
like an empty result rather than an error. The public spec is at
`https://docs.meshcloud.io/api/meshstack-openapi-docs.json` — download it and query it with `jq` rather
than guessing, because it documents required headers and validation rules that are not obvious from the
object shapes.

## Getting a token

`/api/login` only issues a redirect. Take the token from Keycloak directly:

```sh
MT=$(curl -s -u "<client-id>:<api-secret>" -d 'grant_type=client_credentials' \
  "https://sso.<instance>/auth/realms/meshfed/protocol/openid-connect/token" | jq -r .access_token)
```

## Media types that matter

The full header value is `application/vnd.meshcloud.api.<value>`; the table lists the `<value>` part.

| Object | `Accept` | Notes |
|---|---|---|
| meshTenant | `meshtenant.v3.hal+json` | Has `spec.localId` — the cloud resource id — but no uuid. |
| meshTenant | `meshtenant.v4-preview.hal+json` | The **only** place tenant uuids are exposed. Plain `v4` returns 406. |
| meshBuildingBlock | `meshbuildingblock.v2-preview.hal+json` | |
| meshBuildingBlockRun | `meshbuildingblockrun.v1-preview.hal+json` | Also the only accepted type on the logs sub-resource. |
| meshBuildingBlockDefinition | `meshbuildingblockdefinition.v1-preview.hal+json` | |
| meshBuildingBlockDefinitionVersion | `meshbuildingblockdefinitionversion.v1-preview.hal+json` | |
| meshLandingZone | `meshlandingzone.v1.hal+json` | Not `v1-preview`. |
| meshPlatform | `meshplatform.v2.hal+json` | `v1-preview` renders every custom platform's config as `type: "unsupported"`, which is misleading. `v3`+ returns 406. |
| meshProject | `meshproject.v2.hal+json` | Tags are under `spec.tags`, **not** `metadata.tags`. |
| meshProjectUserBinding | `meshprojectuserbinding.v3.hal+json` | |

A request therefore looks like this:

```sh
curl -sS --fail-with-body -H "Authorization: Bearer $MT" \
  -H 'Accept: application/vnd.meshcloud.api.meshtenant.v4-preview.hal+json' \
  "$MESHSTACK/api/meshobjects/meshtenants?workspaceIdentifier=$WS"
```

## Traps that cost real time

**A 401 looks like an empty result.** `jq` on an error body yields `null` or an empty list, so a stale
token reads as "no tenants exist". Always check the HTTP status before believing an empty list —
`--fail-with-body` is enough.

**`meshtenants` returns nothing without a filter.** Use `?workspaceIdentifier=<ws>`. There is no
instance-wide listing, so an inventory means iterating workspaces.

**`meshlandingzones?platformIdentifier=…` ignores the filter** and returns every landing zone on the
instance. Filter client-side, and beware that the `v1` list does not expose the owning platform at all —
fetch each zone individually if you need it.

**Blocks of a definition** come from `meshbuildingblocks?definitionUuid=<bbd-uuid>`. Do **not** filter the
full block list on `spec.buildingBlockDefinitionVersionRef.uuid` — that field holds the *version* uuid, not
the definition's, so it never matches.

**Run logs need one exact `Accept`.** The run's `_links.downloadLogs` returns 406 for
`application/octet-stream`, `text/plain`, `application/zip` and even `*/*`. Only
`meshbuildingblockrun.v1-preview.hal+json` works, and it returns JSON with a `steps` array carrying
`displayName`, `status`, `systemMessage` and `userMessage`. The run uuid is `status.latestRunUuid` on the
block.

**Project members are not readable via `meshusers`** without a `USER_*` permission — it returns 403. Use
the bindings instead, and note the path is `meshprojectbindings/userbindings`, not
`meshprojectuserbindings`, which 404s:

```
GET /api/meshobjects/meshprojectbindings/userbindings?workspaceIdentifier=<ws>&projectIdentifier=<p>
Accept: application/vnd.meshcloud.api.meshprojectuserbinding.v3.hal+json
```

Roles come back as display names — `Project Admin`, `Project User`, `Project Reader` — which map to the
lowercase identifiers a building block's `users` input carries: `admin`, `user`, `reader`. Confirm the
mapping against a real run's `users` input rather than assuming it.

**`meshbuildingblockdefinitionversions` requires `buildingBlockDefinitionUuid`.** There is no unfiltered
listing, so auditing sources across an instance means one request per definition.

## Landing zones

`DELETE /api/meshobjects/meshlandingzones/<identifier>` is documented as a **disable**, not a removal:
*"Deleting a meshLandingZone will disable it, preventing new tenants from being created on this landing
zone. Existing tenants will not be affected."* The object stays readable afterwards with
`lifecycle.state = DEACTIVATED`.

**The identifier is global, not scoped per platform.** Verify uniqueness before deleting by bare
identifier — on one instance, 141 landing zones had zero duplicate names, but many carried the same
platform word in their name while belonging to different platforms.

## Platform availability

`PUT /api/meshobjects/meshplatforms/<uuid>` with the `meshplatform.v2` media type accepts
`spec.availability`, so availability *can* be set through the API even where the panel is the usual route.

**Round-trip safely:** `GET`, drop `status` and `_links`, keep `kind` / `apiVersion` / `metadata` / `spec`,
change the one field, `PUT`. Required on `metadata`: `name`, `ownedByWorkspace`, `uuid`. Required on `spec`:
`availability`, `contributingWorkspaces`, `displayName`, `locationRef`, `quotaDefinitions`. **Include
`spec.config`** — it is optional in the schema, so omitting it risks wiping the platform's configuration.

Three guards fire in sequence, each a `400` with a precise message:

1. `'spec.availability.restriction' must be 'PRIVATE' when marketplaceStatus is 'UNPUBLISHED'`
2. `'spec.availability.restrictedToWorkspaces' must contain exactly the owner when restriction is 'PRIVATE'`
3. `Cannot change spec.availability.restriction to 'PRIVATE' when the platform instance was published before.`

**Together these make `UNPUBLISHED` unreachable for any platform that has ever been published.** A
published platform can only be `PUBLIC` (empty allowed-workspaces list) or `RESTRICTED` (non-empty). So
"disable a platform" is not an operation the API offers — deactivate its landing zones instead.

Going the other way, to public, is also ordered. `setAllowedWorkspaces()` rejects an empty list that does
not contain the owner until `wasOncePublished` is true, so the sequence is: publish first, which leaves the
platform visibly `RESTRICTED`, then clear the list to become `PUBLIC`.

**Platform deletion permanently consumes the identifier.** The delete is soft, but the identifier check
does not exclude deleted rows, so the name can never be reused. Recovering from that has meant deleting a
row from the database.

## Auditing where building block code actually lives

A `kit/`-style directory that nothing in a repository references can still be live, because a BBD reaches
it by Git repository path. To answer the question properly, read the sources off the instance:

```sh
# per definition
GET /api/meshobjects/meshbuildingblockdefinitionversions?buildingBlockDefinitionUuid=<uuid>
# then read each version's
.spec.implementation.terraform.repositoryUrl and .spec.implementation.terraform.repositoryPath
```

The field is `spec.implementation`, not `spec.source`. Write the fallback
`(.spec.implementation // .spec.source)` if you want the query to survive either shape, because a plain
`.spec.source` returns null and reads as "this definition has no source".

Two things to get right:

- **Check versions, not definitions.** A definition's source moves over its lifetime. One observed
  definition pointed at three different paths across v1–v37, ending on a hub module.
- **Check what live blocks are pinned to.** A released version stays orderable, so a path is only truly
  dead when no active block runs a version that uses it. Map each block's
  `spec.buildingBlockDefinitionVersionRef.uuid` back to a version number.

A display name is a weak signal but a useful hint — a definition renamed to something like
"(Deprecated, don't use!)" is telling you where to look first.
