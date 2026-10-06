---
name: Forgejo Teams
supportedPlatforms:
  - stackit
description: |
  Helper module managing Forgejo organization teams and their members via the restapi provider.
  Needed because the Forgejo provider's team resource requires site admin rights.
---

# forgejo-teams

Creates Forgejo organization teams and adds members to them by username. A team with permission
`owner` uses the organization's built-in Owners team. Assigning a team to a repository is left to
the caller, because a repository usually has to be deleted before its teams.
