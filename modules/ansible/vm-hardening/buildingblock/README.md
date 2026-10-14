---
name: Ansible VM Hardening
supportedPlatforms:
  - ansible
description: Hardens a VM with Ansible (devsec.hardening) from a GitHub Actions workflow and serves a landing page reachable through an SSH tunnel only.
---

## What this does

This building block attaches to the building block that provisioned a VM, whichever cloud it runs
in. It needs three outputs from it — the VM's address, its login user and that user's OpenSSH
private key — and their names are configurable. meshStack dispatches a GitHub Actions workflow
that runs an Ansible playbook against the VM, in four steps it reports back to meshStack:

1. **Connect** — waits until the VM answers on SSH.
2. **Harden** — applies `devsec.hardening.os_hardening` and `devsec.hardening.ssh_hardening`.
3. **Web server** — installs nginx listening on `127.0.0.1` and renders a landing page with the
   workspace and project the VM belongs to.
4. **Verify** — runs the whole playbook a second time and fails if it still changes anything, then
   checks that port 80 does not answer from the internet.

The summary hands the application team an SSH tunnel command and a `http://localhost:8080` link.

## Files

There is no Terraform here: meshStack runs a workflow, not OpenTofu. The backplane commits these
files to the repository the definition dispatches on:

| File in this folder | Committed to |
|---|---|
| `workflow.yml` | `.github/workflows/ansible-vm-hardening.yml` |
| `ansible/**` | `ansible-vm-hardening/**` |

## How the VM's key reaches Ansible

The VM's private key is a sensitive output of the VM building block. The meshStack runner
decrypts sensitive inputs, but in URL mode (`omit_run_object_input = true`) the workflow fetches the
run object itself and gets them still encrypted. The definition therefore passes the decrypted run
object as the `buildingBlockRun` dispatch input, and the workflow masks the key and the run token
line by line before any other step runs.
