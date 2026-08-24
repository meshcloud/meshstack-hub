# Covers the directory-lookup and summary-rendering logic without touching Entra. The e2e test only
# ever sees fixture members that all resolve, so the miss-tolerance path has no live coverage.
#
# The azuread provider validates object IDs as UUIDs even when mocked, so the overridden values below
# have to be well-formed GUIDs rather than readable placeholders. Overrides also reject function
# calls and indexed targets, hence the plain `data.azuread_users.members` target and the literal
# attribute lists (azuread_users.users is a fully-typed object, so every attribute must be present).
mock_provider "azuread" {}

variables {
  prefix                 = "acme"
  workspace_identifier   = "ws1"
  project_identifier     = "proj1"
  project_roles          = "admin, user, reader"
  administrative_unit_id = ""
  user_lookup_attribute  = "email"

  users = [
    { meshIdentifier = "id-a", username = "alice", firstName = "Alice", lastName = "A", email = "alice@example.com", euid = "alice@example.com", roles = ["admin"] },
    { meshIdentifier = "id-b", username = "bob", firstName = "Bob", lastName = "B", email = "bob@example.com", euid = "bob@example.com", roles = ["user"] },
    { meshIdentifier = "id-c", username = "carol", firstName = "Carol", lastName = "C", email = "carol@example.com", euid = "carol@example.com", roles = ["admin"] },
    { meshIdentifier = "id-d", username = "dave", firstName = "Dave", lastName = "D", email = "dave@example.com", euid = "dave@example.com", roles = ["reader", "auditor"] },
  ]
}

run "all_members_resolved" {
  override_resource {
    target = azuread_group.project_role
    values = { object_id = "00000000-0000-0000-0000-0000000000aa" }
  }

  override_data {
    target = data.azuread_users.members
    values = {
      users = [
        { account_enabled = true, display_name = "Alice", employee_id = "", mail = "alice@example.com", mail_nickname = "alice", object_id = "00000000-0000-0000-0000-000000000001", onpremises_immutable_id = "", onpremises_sam_account_name = "", onpremises_user_principal_name = "", usage_location = "", user_principal_name = "alice@example.com" },
        { account_enabled = true, display_name = "Bob", employee_id = "", mail = "bob@example.com", mail_nickname = "bob", object_id = "00000000-0000-0000-0000-000000000002", onpremises_immutable_id = "", onpremises_sam_account_name = "", onpremises_user_principal_name = "", usage_location = "", user_principal_name = "bob@example.com" },
        { account_enabled = true, display_name = "Carol", employee_id = "", mail = "carol@example.com", mail_nickname = "carol", object_id = "00000000-0000-0000-0000-000000000003", onpremises_immutable_id = "", onpremises_sam_account_name = "", onpremises_user_principal_name = "", usage_location = "", user_principal_name = "carol@example.com" },
        { account_enabled = true, display_name = "Dave", employee_id = "", mail = "dave@example.com", mail_nickname = "dave", object_id = "00000000-0000-0000-0000-000000000004", onpremises_immutable_id = "", onpremises_sam_account_name = "", onpremises_user_principal_name = "", usage_location = "", user_principal_name = "dave@example.com" },
      ]
    }
  }

  assert {
    condition     = length(output.unresolved_users) == 0
    error_message = "every member resolves, so unresolved_users must be empty, got ${jsonencode(output.unresolved_users)}"
  }

  assert {
    condition     = !strcontains(output.summary, "Unresolved members")
    error_message = "summary must not render the warning section when every member resolved"
  }

  # dave's "auditor" role is not in project_roles, so it must not produce a membership.
  assert {
    condition     = sort(keys(azuread_group_member.project_role)) == tolist(["alice@example.com-admin", "bob@example.com-user", "carol@example.com-admin", "dave@example.com-reader"])
    error_message = "unexpected group memberships: ${jsonencode(sort(keys(azuread_group_member.project_role)))}"
  }

  assert {
    condition     = azuread_group.project_role["admin"].display_name == "acme.ws1.proj1.admin"
    error_message = "group display name must join prefix, workspace, project and role with dots, got ${azuread_group.project_role["admin"].display_name}"
  }
}

run "unresolved_members_are_reported" {
  override_resource {
    target = azuread_group.project_role
    values = { object_id = "00000000-0000-0000-0000-0000000000aa" }
  }

  override_data {
    target = data.azuread_users.members
    values = {
      users = [
        { account_enabled = true, display_name = "Alice", employee_id = "", mail = "alice@example.com", mail_nickname = "alice", object_id = "00000000-0000-0000-0000-000000000001", onpremises_immutable_id = "", onpremises_sam_account_name = "", onpremises_user_principal_name = "", usage_location = "", user_principal_name = "alice@example.com" },
        { account_enabled = true, display_name = "Bob", employee_id = "", mail = "bob@example.com", mail_nickname = "bob", object_id = "00000000-0000-0000-0000-000000000002", onpremises_immutable_id = "", onpremises_sam_account_name = "", onpremises_user_principal_name = "", usage_location = "", user_principal_name = "bob@example.com" },
      ]
    }
  }

  assert {
    condition     = output.unresolved_users == tolist(["carol@example.com", "dave@example.com"])
    error_message = "expected the two members absent from the directory, got ${jsonencode(output.unresolved_users)}"
  }

  assert {
    condition     = sort(keys(azuread_group_member.project_role)) == tolist(["alice@example.com-admin", "bob@example.com-user"])
    error_message = "unresolved members must not be added to any group, got ${jsonencode(sort(keys(azuread_group_member.project_role)))}"
  }

  # An unresolved member degrades the run, it does not abort it: the groups are still created.
  assert {
    condition     = length(azuread_group.project_role) == 3
    error_message = "expected one group per project role, got ${length(azuread_group.project_role)}"
  }

  assert {
    condition     = strcontains(output.summary, "## ⚠️ Unresolved members")
    error_message = "summary must render the warning section when a member is unresolved"
  }

  assert {
    condition     = strcontains(output.summary, "- `carol@example.com`") && strcontains(output.summary, "- `dave@example.com`")
    error_message = "summary must list every unresolved member as a bullet"
  }

  assert {
    condition     = strcontains(output.summary, "2 group membership(s) assigned from 4 project member(s)")
    error_message = "summary must count assigned memberships against all project members"
  }

  assert {
    condition     = strcontains(output.summary, "| `admin` | `acme.ws1.proj1.admin` |")
    error_message = "summary must render one table row per project role"
  }

  # Regression guard: four leading spaces turn a table row or a bullet into a markdown code block,
  # which is exactly what a %{for} directive body would produce here.
  assert {
    condition     = length([for line in split("\n", output.summary) : line if startswith(line, "    ")]) == 0
    error_message = "no summary line may be indented by four spaces: ${jsonencode([for line in split("\n", output.summary) : line if startswith(line, "    ")])}"
  }
}

run "euid_case_differs_from_directory" {
  variables {
    users = [
      { meshIdentifier = "id-a", username = "alice", firstName = "Alice", lastName = "A", email = "Alice@Example.com", euid = "Alice@Example.com", roles = ["admin"] },
    ]
  }

  override_resource {
    target = azuread_group.project_role
    values = { object_id = "00000000-0000-0000-0000-0000000000aa" }
  }

  override_data {
    target = data.azuread_users.members
    values = {
      users = [
        { account_enabled = true, display_name = "Alice", employee_id = "", mail = "alice@example.com", mail_nickname = "alice", object_id = "00000000-0000-0000-0000-000000000001", onpremises_immutable_id = "", onpremises_sam_account_name = "", onpremises_user_principal_name = "", usage_location = "", user_principal_name = "alice@example.com" },
      ]
    }
  }

  assert {
    condition     = length(output.unresolved_users) == 0
    error_message = "a euid differing from the directory only in case must resolve, got ${jsonencode(output.unresolved_users)}"
  }

  assert {
    condition     = sort(keys(azuread_group_member.project_role)) == tolist(["Alice@Example.com-admin"])
    error_message = "expected the case-differing member to be added to the admin group, got ${jsonencode(keys(azuread_group_member.project_role))}"
  }
}

run "project_without_members" {
  variables {
    users = []
  }

  override_resource {
    target = azuread_group.project_role
    values = { object_id = "00000000-0000-0000-0000-0000000000aa" }
  }

  assert {
    condition     = length(data.azuread_users.members) == 0
    error_message = "a project with no members must not query the directory at all"
  }

  assert {
    condition     = length(azuread_group.project_role) == 3
    error_message = "groups must be created even when the project has no members"
  }

  assert {
    condition     = strcontains(output.summary, "0 group membership(s) assigned from 0 project member(s)")
    error_message = "summary must report zero memberships for a project without members"
  }

  assert {
    condition     = !strcontains(output.summary, "Unresolved members")
    error_message = "no members means nothing is unresolved"
  }
}
