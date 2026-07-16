#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

if [ ! -f "$DIR/local.nix" ]; then
  echo "error: $DIR/local.nix not found. Run ./init.sh first." >&2
  exit 1
fi

# path:$DIR (not bare $DIR): local.nix is gitignored, and the default
# git+file: source a bare directory ref resolves to only sees git-tracked
# files. path: copies the whole directory verbatim, so local.nix is visible
# with no --impure needed anywhere -- see CLAUDE.md.
home-manager switch -b backup --flake "path:$DIR#$(whoami)"

# Shell-integration changes (keybindings/completions/prompt hooks) only take
# effect in a brand-new shell, not this one (see CLAUDE.md Gotchas). Inside
# WezTerm, open a fresh tab and close this one automatically instead of
# leaving you in a stale shell. No-op outside WezTerm (or if the switch
# above failed -- set -e already stopped the script before here).
if [ -n "${WEZTERM_PANE:-}" ] && command -v wezterm >/dev/null 2>&1; then
  new_pane="$(wezterm cli spawn --cwd "$PWD")"
  wezterm cli activate-pane --pane-id "$new_pane"
  wezterm cli kill-pane --pane-id "$WEZTERM_PANE"
fi
