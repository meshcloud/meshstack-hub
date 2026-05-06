# Smoke test for the noop building block.
# Verifies that the Terraform module applies cleanly with all required inputs,
# covering the full input/output surface that meshStack exercises at runtime.
# The pre-run script (prerun.sh) — including nix-based tool installation — is
# exercised when this building block is deployed via the meshStack BB runner.

# meshStack writes FILE-type inputs to the working directory before tofu init.
# In local tests we create them upfront so the module can read them.
run "noop_applies_successfully" {
  variables {
    user_permissions = [
      {
        meshIdentifier = "likvid-tom-user"
        username       = "likvid-tom@meshcloud.io"
        firstName      = "Tom"
        lastName       = "Likvid"
        email          = "likvid-tom@meshcloud.io"
        euid           = "likvid-tom@meshcloud.io"
        roles          = ["admin", "Workspace Owner"]
      },
      {
        meshIdentifier = "likvid-daniela-user"
        username       = "likvid-daniela@meshcloud.io"
        firstName      = "Daniela"
        lastName       = "Likvid"
        email          = "likvid-daniela@meshcloud.io"
        euid           = "likvid-daniela@meshcloud.io"
        roles          = ["user", "Workspace Manager"]
      }
    ]
    user_permissions_json = jsonencode([
      {
        meshIdentifier = "likvid-tom-user"
        username       = "likvid-tom@meshcloud.io"
        firstName      = "Tom"
        lastName       = "Likvid"
        email          = "likvid-tom@meshcloud.io"
        euid           = "likvid-tom@meshcloud.io"
        roles          = ["admin", "Workspace Owner"]
      }
    ])
    sensitive_yaml    = { some = "yaml", other = "value" }
    static            = "A static value"
    static_code       = { some = "code" }
    flag              = true
    num               = 42
    text              = "hello"
    sensitive_text    = "s3cr3t"
    single_select     = "single1"
    multi_select      = ["multi1", "multi2"]
    multi_select_json = jsonencode(["multi1", "multi2"])
  }

  assert {
    condition     = output.flag == true
    error_message = "expected flag output to be true"
  }

  assert {
    condition     = output.num == 42
    error_message = "expected num output to be 42"
  }

  assert {
    condition     = output.text == "hello"
    error_message = "expected text output to be 'hello'"
  }

  assert {
    condition     = output.static == "A static value"
    error_message = "expected static output to echo back the static input"
  }

  assert {
    condition     = output.single_select == "single1"
    error_message = "expected single_select output to echo back the selected value"
  }

  assert {
    condition     = length(output.multi_select) == 2
    error_message = "expected multi_select output to contain two values"
  }

  assert {
    condition     = length(output.user_permissions) == 2
    error_message = "expected user_permissions output to contain two entries"
  }
}
