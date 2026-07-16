# dotfiles

My personal Fedora KDE setup, managed with standalone [home-manager](https://github.com/nix-community/home-manager)
via a Nix flake. One repo, one command, and a fresh Fedora box gets my shell,
CLI tools, and dotfiles configured the same way every time.

This intentionally does **not** manage the OS itself — Fedora, `dnf`, KDE,
drivers, and system services stay exactly as Fedora installed them. Nix only
owns my user-level home-manager profile, installed alongside Fedora in
`/nix`. See [CLAUDE.md](./CLAUDE.md) for why.

## What this manages

- **Shell**: bash, with oh-my-posh (gruvbox theme), fzf history search, and
  zoxide.
- **Git**: identity, SSH commit signing, `delta` as pager, `gh` as the
  credential helper.
- **Editor**: VS Code, fully declarative — settings and extensions are both
  defined in `home.nix`, not clicked through the marketplace UI.
- **Terminal**: WezTerm, config tracked and live-editable under `home/`.
- **Dev toolchains**: .NET, Go, Python (`uv`), Azure CLI, and a Kubernetes
  stack (`kubectl`, `helm`, `flux`, `kind`, `k9s`, `kubectx`).

The full, current list of what's installed and how it's configured lives in
`home.nix` — this is a summary, not a mirror, so it won't drift out of sync
with the code.

## Prerequisites

- Fedora 44+ (or similar systemd-based Linux), `x86_64-linux`. If you're on
  ARM, change `system = "x86_64-linux"` in `flake.nix` to `"aarch64-linux"`.
- No pre-existing Nix install required — `bootstrap.sh` installs it.

## Fresh-machine setup

```sh
git clone <this-repo-url> ~/.dotfiles-src  # or wherever you like
cd ~/.dotfiles-src
./bootstrap.sh
```

`bootstrap.sh` will:
1. Install [Determinate Nix](https://github.com/DeterminateSystems/nix-installer) if it isn't already present.
2. Symlink this repo to `~/.dotfiles` (home-manager's config resolves its
   symlinked dotfiles through this fixed path).
3. Run `./init.sh` if `local.nix` doesn't exist yet: auto-detects your OS
   username (`whoami`) and git identity (already-configured global git
   config, or your authenticated `gh` user, or your fork's remote owner --
   whatever it finds is shown to you to accept or override, never applied
   silently), and writes `local.nix` -- gitignored, never committed. This
   repo carries no identity of its own; every machine needs its own
   `local.nix`.
4. Run the first `home-manager switch` from the flake, targeting whichever
   OS user is running the script. No username or identity to hand-edit
   anywhere in the tracked repo.

Neither this script nor `rebuild.sh` ever calls `sudo` — home-manager only
touches your home directory and Nix profile, never system state. The one
exception is step 1: installing Nix itself needs root (to create `/nix`, the
build daemon, etc.), so the Determinate installer will prompt for `sudo`
itself, once, the first time you ever run `bootstrap.sh` on a machine. Every
`rebuild.sh` after that is genuinely sudo-free.

## Daily use

After the first bootstrap, apply any changes with:

```sh
./rebuild.sh
```

## Repo tour

- `flake.nix` — pins `nixpkgs`/`home-manager` versions, defines the
  `homeConfigurations` output.
- `home.nix` — the actual home-manager config: packages, shell, dotfile
  symlinks.
- `init.sh` — generates `local.nix` (OS username + git identity), gitignored.
- `bootstrap.sh` — one-time fresh-machine setup.
- `rebuild.sh` — day-2 "apply changes" script.
- `home/` — the real dotfiles, symlinked into `$HOME` by `home.nix`.
- `CLAUDE.md` — deliberate decisions, for humans and coding agents alike.

## How the symlinks work

`home.nix` uses `config.lib.file.mkOutOfStoreSymlink` to point paths under
`$HOME` (e.g. `~/.config/wezterm`) directly at files living in this repo's
`home/` directory, via the fixed `~/.dotfiles` symlink `bootstrap.sh`/
`rebuild.sh` maintain. That means editing a file in `home/` takes effect
immediately — no `home-manager switch` required for that file. You only
need to re-run `rebuild.sh` when you change `home.nix` itself (e.g. to add
a package or a new symlink).

## Validate without applying

Needs `local.nix` to exist first (`./init.sh`) -- `path:` is required on the
flake ref, not the bare `.`/directory form, since `local.nix` is gitignored
and the default git-tracked-files-only source can't see it (see
[CLAUDE.md](./CLAUDE.md)):

```sh
nix flake check path:.
nix build "path:$(pwd)#homeConfigurations.$(whoami).activationPackage" --dry-run
```

## Learning Nix

This repo leans on two things you'll want to actually understand rather
than cargo-cult: **Nix flakes**, and **home-manager**. Suggested order:

1. [nix.dev — Flakes](https://nix.dev/concepts/flakes.html) — read this
   first, just for vocabulary (inputs, outputs, `flake.lock`).
2. [Zero to Nix](https://zero-to-nix.com/) — Determinate Systems' guided,
   hands-on quick start. Best on-ramp for actually doing things.
3. [NixOS Wiki — Home Manager](https://wiki.nixos.org/wiki/Home_Manager) —
   read the **standalone install** section specifically; that's the mode
   this repo uses (not the NixOS-module or nix-darwin-module modes).
4. [home-manager manual](https://nix-community.github.io/home-manager/) —
   the flakes-based usage chapter, for the exact `homeConfigurations` shape
   used in `flake.nix` here.
5. [Determinate `nix-installer` README](https://github.com/DeterminateSystems/nix-installer) —
   what `bootstrap.sh` step 1 is actually doing under the hood on Fedora.

For later, as references rather than start-to-end reads:
- [NixOS Wiki — Flakes](https://wiki.nixos.org/wiki/Flakes)
- [home-manager source](https://github.com/nix-community/home-manager) —
  for looking up specific module options while writing `home.nix`.
- [Determinate's Learn Nix guide index](https://docs.determinate.systems/guides/learn-nix/)
