#!/usr/bin/env bash
# Bumps pinned flake inputs (nixpkgs, nixpkgs-unstable, home-manager,
# nix-vscode-extensions) to their latest revisions in flake.lock. Pass one
# or more input names to update only those (e.g. ./update.sh
# nixpkgs-unstable to bump just herdr/vscode); with no args, updates all.
# Doesn't apply anything -- run ./rebuild.sh afterwards to build with the
# new pins.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# path:$DIR (not bare $DIR): see CLAUDE.md -- every Nix command against this
# flake must use a path: ref.
nix flake update --flake "path:$DIR" "$@"

echo "Lock file updated. Run ./rebuild.sh to apply."
