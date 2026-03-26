#!/usr/bin/env python3
"""Resolve the default branch of a remote Git repository.

Called as a Terraform external data source.
Input (via stdin JSON):  { "clone_addr": "https://github.com/owner/repo.git" }
Output (via stdout JSON): { "default_branch": "main" }

Uses `git ls-remote` to find the HEAD symref without cloning the repository.
Falls back to "main" if the default branch cannot be determined.
"""

import json
import subprocess
import sys


def resolve_default_branch(clone_addr: str) -> str:
    """Resolve the default branch from a remote repository URL."""
    try:
        result = subprocess.run(
            ["git", "ls-remote", "--symref", clone_addr, "HEAD"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        # Output format: "ref: refs/heads/main\tHEAD\n..."
        for line in result.stdout.splitlines():
            if line.startswith("ref: refs/heads/"):
                return line.split("ref: refs/heads/")[1].split("\t")[0]
    except (subprocess.TimeoutExpired, OSError):
        pass

    return "main"


def main() -> None:
    query = json.loads(sys.stdin.read())
    clone_addr = query.get("clone_addr", "").strip()

    if not clone_addr or clone_addr == "null":
        print(json.dumps({"default_branch": "main"}))
        return

    branch = resolve_default_branch(clone_addr)
    print(json.dumps({"default_branch": branch}))


if __name__ == "__main__":
    main()
