variable "github_repository" {
  type        = string
  description = "Repository in `owner/repo` format the workflow and the Ansible playbook are committed to, and run from. It needs at least one commit on `github_branch`."

  validation {
    condition     = length(split("/", var.github_repository)) == 2
    error_message = "github_repository must be in owner/repo format."
  }
}

variable "github_branch" {
  type        = string
  default     = "main"
  description = "Branch the files are committed to and the workflow is dispatched on."
}

variable "github_base_url" {
  type        = string
  default     = "https://api.github.com"
  description = "Base URL of the GitHub API. Override for GitHub Enterprise Server."
}

variable "github_integration_uuid" {
  type        = string
  default     = null
  description = "UUID of an existing meshStack GitHub integration for the repository owner to dispatch the workflow with. Null registers a new one from the GitHub App credentials below."
}

variable "github_app_id" {
  type        = string
  description = "ID of the GitHub App the backplane commits the workflow and the playbook with, which needs `contents: write` and `workflows: write`. Without `github_integration_uuid` meshStack also dispatches the workflow with it, which needs `actions: write`."
}

variable "github_app_installation_id" {
  type        = string
  description = "Installation ID of the GitHub App for the repository owner. Found under GitHub App settings → Install App → your org."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "PEM-encoded private key of the GitHub App."
}

variable "vm_bbd_uuid" {
  type        = string
  description = "UUID of the building block definition that provisions the VM. Hardening attaches to its building blocks and reads the VM's address, login user and SSH key from their outputs."
}

variable "vm_public_ip_output" {
  type        = string
  default     = "public_ip"
  description = "Output of the VM building block holding the address Ansible connects to."
}

variable "vm_ssh_username_output" {
  type        = string
  default     = "ssh_username"
  description = "Output of the VM building block holding the login user, which needs passwordless sudo."
}

variable "vm_ssh_private_key_output" {
  type        = string
  default     = "ssh_private_key"
  description = "Output of the VM building block holding the OpenSSH private key of the login user."
}

variable "supported_platform_types" {
  type        = list(string)
  description = "meshStack platform types the VM building block runs on, e.g. `[\"STACKIT\"]`. The hardening definition is offered on the same tenants."
}

variable "summary_embeds_ssh_key" {
  type        = bool
  default     = false
  description = "Puts the VM's private key into the summary, so one pasted snippet opens the landing page. For demos only: everyone who can see the building block can read the key. The GitHub run never shows it either way."
}

variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

variable "integration_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the meshStack integration this module registers. Ignored when `github_integration_uuid` is set."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "main"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

locals {
  github_owner           = split("/", var.github_repository)[0]
  github_repository_name = split("/", var.github_repository)[1]

  github_integration_ref = var.github_integration_uuid == null ? meshstack_integration.github.ref : {
    kind = "meshIntegration"
    uuid = var.github_integration_uuid
  }
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/ansible/vm-hardening/backplane?ref=${var.hub.git_ref}"

  github_owner               = local.github_owner
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key
  github_repository_name     = local.github_repository_name
  github_branch              = var.github_branch
}

resource "meshstack_integration" "github" {
  lifecycle {
    enabled = var.github_integration_uuid == null
  }

  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name = coalesce(var.integration_display_name, "GitHub (${local.github_owner})")
    config = {
      github = {
        owner    = local.github_owner
        base_url = var.github_base_url
        app_id   = var.github_app_id
        app_private_key = {
          secret_value   = var.github_app_private_key
          secret_version = nonsensitive(sha256(var.github_app_private_key))
        }
      }
    }
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "Ansible VM Hardening")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ansible/vm-hardening/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Hardens a VM with Ansible (devsec.hardening) and serves a landing page from nginx, reachable through an SSH tunnel only.")
    support_url         = "https://github.com/dev-sec/ansible-collection-hardening"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [for t in var.supported_platform_types : { name = t }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    Hardens a VM you ordered as a building block in this tenant. A GitHub Actions workflow runs an
    **Ansible** playbook against the VM: the
    [devsec.hardening](https://github.com/dev-sec/ansible-collection-hardening) OS and SSH baselines,
    then nginx serving a landing page on `127.0.0.1` only. You reach it through an SSH tunnel.

    ## 🎯 When to use it

    Use this building block when you:
    - want a VM that meets a known OS and SSH baseline without writing the hardening yourself
    - need a web server that is not exposed to the internet
    - want evidence that the baseline holds: the run applies the playbook twice and fails if the second run still changes anything

    ## 💡 Usage examples

    **Example 1: Hardened internal tool**
    You order a VM, attach this building block, and get a hardened Ubuntu VM with nginx.
    You deploy your internal dashboard behind it and reach it through the SSH tunnel from the summary.

    **Example 2: Repair drift**
    Someone changed the SSH configuration by hand. Re-running this building block puts the baseline
    back, and the summary shows the run ended without drift.

    ## 🔑 Reaching the landing page

    Save the SSH private key output of your VM building block as `id_vm`. The summary then has one
    snippet to paste into a terminal in that folder: it opens the SSH tunnel in the background and
    your browser on http://localhost:8080.
    Where the platform team enabled it, the snippet writes the key file itself, so pasting it is all
    there is to do.

    ## ⚠️ Before you order

    - The VM has to run Debian or Ubuntu, and its login user needs passwordless sudo.
    - The VM has to accept SSH from GitHub-hosted runners, which in practice means from anywhere.
      SSH stays key-only: the baseline disables password and root login.
    - The baseline restricts SSH: TCP forwarding is limited to local forwards (`ssh -L`), and
      agent and X11 forwarding are off.
    - Removing this building block leaves the VM hardened. It does not undo the playbook.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Maintain the Ansible playbook and the hardening baseline | ✅ | ❌ |
    | Run the playbook and report drift | ✅ | ❌ |
    | Order the VM and keep its SSH key safe | ❌ | ✅ |
    | Re-run the building block after changing the VM by hand | ❌ | ✅ |
    | Operate what you deploy behind nginx | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft
    # PURGE: removing the block runs no workflow. There is nothing to tear down, since hardening
    # stays on the VM and the VM belongs to its own building block, and meshStack refuses DELETE
    # without a destroy workflow.
    deletion_mode   = "PURGE"
    dependency_refs = [{ uuid = var.vm_bbd_uuid }]

    implementation = {
      github_workflows = {
        # The repository name alone: meshStack prefixes the owner from the integration.
        repository      = local.github_repository_name
        branch          = module.backplane.branch
        apply_workflow  = module.backplane.workflow
        integration_ref = local.github_integration_ref
        async           = true

        # Only the run object carries the inputs the runner decrypted; in URL mode the workflow fetches
        # them itself and gets `ssh_private_key` still encrypted.
        omit_run_object_input = false
      }
    }

    inputs = {
      public_ip = {
        display_name    = "Public IP"
        description     = "Public IP of the VM, from its VM building block."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = jsonencode("${var.vm_bbd_uuid}.${var.vm_public_ip_output}")
      }

      ssh_username = {
        display_name    = "SSH Username"
        description     = "Login user of the VM, from its VM building block."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = jsonencode("${var.vm_bbd_uuid}.${var.vm_ssh_username_output}")
      }

      ssh_private_key = {
        display_name    = "SSH Private Key"
        description     = "Private key Ansible logs into the VM with, from its VM building block."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = jsonencode("${var.vm_bbd_uuid}.${var.vm_ssh_private_key_output}")
      }

      workspace_identifier = {
        display_name    = "Workspace"
        description     = "Workspace the VM belongs to, shown on the landing page."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      summary_embeds_ssh_key = {
        display_name    = "Summary Embeds SSH Key"
        description     = "Whether the summary carries the VM's private key in its paste-ready snippet."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.summary_embeds_ssh_key)
      }

      project_identifier = {
        display_name    = "Project"
        description     = "Project the VM belongs to, shown on the landing page."
        type            = "STRING"
        assignment_type = "PROJECT_IDENTIFIER"
      }
    }

    outputs = {
      landing_page_url = {
        display_name    = "Landing Page (through the tunnel)"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      tunnel_command = {
        display_name    = "SSH Tunnel Command"
        type            = "STRING"
        assignment_type = "NONE"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.26.2"
    }
  }
}
