# Mocked unit runs against ../buildingblock, for the two directory states the live apply cannot
# reach: the fixture project's members all resolve by email, and it always has members. Everything
# the apply *can* reach is asserted there instead — see azure_entra_id_groups_hub.tftest.hcl.
#
# These runs never touch Entra and need no credentials. They live here because `e2e/` is the only
# directory in this repo where a `*.tftest.hcl` is executed at all.
#
# Override values may not call functions or reference variables, so the mocked directory is spelled
# out literally. The `for` keeps the eight schema-required attributes the module never reads out of
# the way — only mail, user_principal_name and object_id carry meaning.

mock_provider "azuread" {}

variables {
  prefix                 = "acme"
  workspace_identifier   = "ws1"
  project_identifier     = "proj1"
  project_roles          = "admin, user, reader"
  administrative_unit_id = ""
  user_lookup_attribute  = "email"

  users = [
    # alice's euid differs from the directory only in case and must still resolve.
    { meshIdentifier = "id-a", username = "alice", firstName = "Alice", lastName = "A", email = "Alice@Example.com", euid = "Alice@Example.com", roles = ["admin"] },
    # bob's "auditor" role is not in project_roles and must not produce a membership. He has to be
    # one of the members that *resolves* for this to bite — an unresolved member is filtered out
    # before the role filter would matter.
    { meshIdentifier = "id-b", username = "bob", firstName = "Bob", lastName = "B", email = "bob@example.com", euid = "bob@example.com", roles = ["user", "auditor"] },
    { meshIdentifier = "id-c", username = "carol", firstName = "Carol", lastName = "C", email = "carol@example.com", euid = "carol@example.com", roles = ["admin"] },
    { meshIdentifier = "id-d", username = "dave", firstName = "Dave", lastName = "D", email = "dave@example.com", euid = "dave@example.com", roles = ["reader"] },
  ]
}

override_resource {
  target = azuread_group.project_role
  values = { object_id = "00000000-0000-0000-0000-0000000000aa" }
}

# Two of the four project members have no object in the directory. The building block must degrade
# rather than fail: create the groups, add the members it could resolve, and name the rest.
run "unresolved_members_are_reported" {
  module {
    source = "../buildingblock"
  }

  override_data {
    target = data.azuread_users.members
    values = {
      users = [
        for i, mail in ["alice@example.com", "bob@example.com"] : {
          mail                = mail
          user_principal_name = mail
          object_id           = "00000000-0000-0000-0000-00000000000${i + 1}"

          account_enabled                = true
          display_name                   = ""
          employee_id                    = ""
          mail_nickname                  = ""
          onpremises_immutable_id        = ""
          onpremises_sam_account_name    = ""
          onpremises_user_principal_name = ""
          usage_location                 = ""
        }
      ]
    }
  }

  assert {
    condition     = output.unresolved_users == tolist(["carol@example.com", "dave@example.com"])
    error_message = "expected the two members absent from the directory, got ${jsonencode(output.unresolved_users)}"
  }

  # alice resolves despite the case difference; bob's out-of-scope "auditor" role produces nothing.
  assert {
    condition     = length(azuread_group.project_role) == 3 && sort(keys(azuread_group_member.project_role)) == tolist(["Alice@Example.com-admin", "bob@example.com-user"])
    error_message = "unresolved members must not be added to any group, got ${jsonencode(sort(keys(azuread_group_member.project_role)))}"
  }

  # Comparing the whole document also guards the indentation bug a %{for} directive body would
  # reintroduce: four leading spaces turn a table row or a bullet into a markdown code block.
  # chomp because the output carries no trailing newline while the file does. path.root is the
  # module under test (../buildingblock) in these runs, hence the hop back into e2e/.
  assert {
    condition     = output.summary == chomp(file("${path.root}/../e2e/tests/azure_entra_id_groups_unit.summary.expected.md"))
    error_message = "summary does not match the expected markdown, got:\n${output.summary}"
  }
}

# A project with no members at all must not query the directory — data.azuread_users.members is
# count = 0 there, and the lookup behind it is guarded by a try().
run "project_without_members" {
  module {
    source = "../buildingblock"
  }

  variables {
    users = []
  }

  assert {
    condition     = length(data.azuread_users.members) == 0
    error_message = "a project with no members must not query the directory at all"
  }

  assert {
    condition     = length(azuread_group.project_role) == 3 && strcontains(output.summary, "0 group membership(s) assigned from 0 project member(s)")
    error_message = "groups must still be created, and the summary must report zero memberships, got:\n${output.summary}"
  }
}
