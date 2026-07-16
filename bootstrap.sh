#!/usr/bin/env bash
# Takes a fresh Fedora box from nothing to a built home-manager config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles, so this
# has to exist before the first switch or the build will fail to find them.
ln -sfn "$DIR" ~/.dotfiles

echo "==> Step 3: local identity"
if [ -f "$DIR/local.nix" ]; then
  echo "    $DIR/local.nix already exists, leaving it as-is."
else
  "$DIR/init.sh"
fi

echo "==> Step 4: first home-manager switch (pinned to release-26.05)"
# home-manager doesn't exist as a command yet on a fresh machine, so run it
# straight from the flake this once. After this, rebuild.sh works normally.
# Unlike a nix-darwin/NixOS switch, this never touches system state, so no
# sudo is needed anywhere in this script.
# path:$DIR (not bare $DIR): local.nix is gitignored, and the default
# git+file: source a bare directory ref resolves to only sees git-tracked
# files. path: copies the whole directory verbatim, so local.nix is visible
# with no --impure needed anywhere -- see CLAUDE.md.
nix run home-manager/release-26.05 -- switch -b backup --flake "path:$DIR#$(whoami)"

echo "==> Done. Use ./rebuild.sh for future changes."
