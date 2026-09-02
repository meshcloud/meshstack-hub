# Management Groups (foundation glue)

Creates the Enterprise-Scale management group hierarchy for the Azure Landing Zone reference
architecture, under a given parent (typically the tenant root group):

```
<parent>
├── Landing Zones        # platform replicator/metering + building block backplane scope
│   ├── Corp
│   ├── Online
│   └── Sandbox
└── Connectivity         # hosts the hub subscription; hub-network backplane scope
```

Management groups are created with display names only; Azure generates their names (IDs). The module
outputs each group's `name` (for meshStack platform/landing-zone references) and, where needed, its
full `scope` path (for policy assignments and RBAC).

This is **foundation glue** for the reference architecture. The caller (the reference architecture's
`buildingblock`) drives it from the `azure_management_groups` variable, whose
`parent_management_group_id` is pre-configured STATIC to the bootstrap scope — so the hierarchy is
created under the same management group the bootstrap identity owns.

The applying identity needs permission to create management groups (Management Group Contributor at
the parent, or Owner on it — which the bootstrap identity has).
