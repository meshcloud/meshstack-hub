#!/usr/bin/env python3
"""Resolves the default branch of a remote Git repository for a Terraform external data source. Falls back to "main"."""

import json
import subprocess
import sys


def resolve_default_branch(clone_addr: str) -> str:
    try:
        result = subprocess.run(
            ["git", "ls-remote", "--symref", clone_addr, "HEAD"],
            capture_output=True,
            text=True,
            timeout=30,
        )
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
