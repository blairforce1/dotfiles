{ config, pkgs, pkgsUnstable, vscodeMarketplace, user, gitUserName, gitUserEmail, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/home/${user}";
  home.stateVersion = "26.05";

  # Fedora is not NixOS, so this fills in the environment wiring
  # (XDG_DATA_DIRS, etc.) that NixOS normally provides for free.
  targets.genericLinux.enable = true;

  # Standalone home-manager doesn't install its own CLI into the managed
  # profile by default. bootstrap.sh works anyway (it calls home-manager via
  # `nix run`, which doesn't need the binary pre-installed), but rebuild.sh's
  # `exec home-manager switch` assumes `home-manager` is already on PATH.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ripgrep # fast search
    fd      # fast find
    jq      # json on the command line
    lazygit # terminal UI for git
    btop    # resource monitor. Config lives at home/.config/btop (see home.file below)
    marp-cli # markdown -> slide deck CLI (https://marp.app/), pairs with the marp-team.marp-vscode extension below
    inkscape # vector graphics editor

    # GitHub CLI -- shadows dnf's /usr/bin/gh once first on PATH. Deliberately
    # not using the programs.gh module: it always renders config.yml through
    # jsonFormat.generate into the read-only Nix store (no path-passthrough
    # escape hatch like programs.vscode.userSettings has), so `gh config set`/
    # `gh alias set` would hit the exact EACCES footgun VS Code just did.
    # config.yml is wired as a real file instead (see home.file below).
    # hosts.yml (holds the OAuth token) is untouched by Nix entirely.
    gh

    # Terminal multiplexer that tracks AI coding agent state across panes
    # (blocked/working/done). Not in the pinned nixos-26.05 snapshot yet --
    # it ships weekly releases -- so this comes from pkgsUnstable (same
    # reasoning as vscode below). Config lives at home/.config/herdr (see
    # home.file below).
    pkgsUnstable.herdr

    # .NET -- 10.0 is the current LTS (verified against dotnet.microsoft.com,
    # 2026-07-08; 11.0 exists in nixpkgs but is still preview-only, don't use it).
    # SDK lives in the read-only /nix/store, so `dotnet workload install`
    # (MAUI, etc.) doesn't work here -- fine for web/console/API dev.
    dotnetCorePackages.sdk_10_0

    # Go -- shadows dnf's golang once confirmed first on PATH (see CLAUDE.md
    # migration notes / dotfiles plan). 1.26.4 on nixos-26.05, already current.
    go

    # Python -- system /usr/bin/python3 stays Fedora's; this is the dev-facing
    # one. Explicitly python314 rather than the generic `python3` (= 3.13 on
    # this nixpkgs channel) to match the latest stable CPython release, same
    # as Fedora's own system python3 (3.14.6). Still provides a `python3` binary.
    python314
    uv # fast pip/venv replacement

    # Azure
    azure-cli

    # Kubernetes
    kubectl
    kubernetes-helm # v3 (3.20.2) -- Helm v4 is current upstream but a deliberate
                    # stay-on-v3 call (breaking changes); revisit via pkgsUnstable later.
    kubelogin    # AAD auth for AKS: `kubectl kubelogin convert-kubeconfig`
    kustomize
    fluxcd       # provides the `flux` CLI
    kind         # local cluster; see KIND_EXPERIMENTAL_PROVIDER below
    k9s
    kubectx      # provides kubectx + kubens

    # Icon-patched Fira Code, backing "FiraCode Nerd Font Mono" -- used by
    # both VS Code's integrated terminal (below) and WezTerm (see
    # home/.config/wezterm), and needed for oh-my-posh's gruvbox glyphs to
    # render instead of showing as boxes. Plain fira-code-fonts comes from
    # dnf, but that doesn't carry the Nerd Font glyph patches.
    nerd-fonts.fira-code
  ];

  home.sessionVariables = {
    # "code" alone doesn't block -- it hands the file to VS Code and returns
    # immediately, so tools that wait for $EDITOR to exit (crontab -e,
    # kubectl edit, gh pr create, sudoedit) would think editing finished
    # before the file's touched. -w/--wait fixes that. git already sidesteps
    # this via its own core.editor = "code --wait" below.
    EDITOR = "code --wait";
    # Run kind's clusters against the rootless podman already on this box
    # instead of requiring Docker.
    KIND_EXPERIMENTAL_PROVIDER = "podman";
    # Scroll wheel scrolls the Claude Code transcript; clicks (which would
    # otherwise drive menu/history selection) stay disabled.
    CLAUDE_CODE_DISABLE_MOUSE_CLICKS = "1";
    # Carried over from the old .bashrc -- podman's rootless socket, used by
    # anything that shells out to `docker` (and VS Code's dev containers).
    DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";
    # bun isn't nix-managed (out of scope here), but this keeps its existing
    # install discoverable instead of silently dropping it from PATH below.
    BUN_INSTALL = "${config.home.homeDirectory}/.bun";
  };

  # Carried over from the old .bashrc's manual `export PATH=...` lines --
  # go/bin and .cargo/bin are real tool-output dirs (`go install`, `cargo
  # install`), not nix-managed themselves, so still need to be on PATH.
  # .local/bin and ~/bin matched the old distro-default bashrc block.
  home.sessionPath = [
    "${config.home.homeDirectory}/go/bin"
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/.bun/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/bin"
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.oh-my-posh = {
    enable = true;
    useTheme = "gruvbox";
    enableBashIntegration = true;
  };

  # Ctrl+R fuzzy-searches .bash_history in arrival order -- no smart
  # ranking, no separate popup UI. Replaced programs.atuin (disliked the
  # ranking + intrusive full-screen search UI).
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  # Was dnf's zoxide + a manual `eval "$(zoxide init bash --cmd cd)"` at the
  # very end of .bashrc; see Part 4 of the dotfiles plan for the dnf removal.
  programs.zoxide = {
    enable = true;
    options = [ "--cmd" "cd" ];
    enableBashIntegration = true;
  };

  # Package only -- the actual wezterm.lua is a real file under home/, wired
  # up via home.file below (same edit-in-place pattern as the rest of this
  # repo's dotfiles), not this module's `settings`/`extraConfig`. Leaving
  # those unset means home-manager writes nothing to
  # ~/.config/wezterm/wezterm.lua itself, so there's no collision with the
  # symlink. enableBashIntegration wires up WezTerm's OSC 133 shell
  # integration (prompt jumping, "select last command output").
  programs.wezterm = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      ls = "ls --hyperlink --color=auto";
      rg = "rg --hyperlink-format=kitty";
      delta = "delta --hyperlinks --hyperlinks-file-link-format='file://{path}#{line}'";
    };
    # home-manager's generated .bashrc doesn't source /etc/bashrc on its own
    # (unlike Fedora's stock one) -- keep it so Fedora's prompt/umask/etc still apply.
    bashrcExtra = ''
      if [ -f /etc/bashrc ]; then
        . /etc/bashrc
      fi
    '';
    historyFile = "${config.home.homeDirectory}/.bash_history";
    historySize = 10000;
    historyFileSize = 20000;
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true; # wires up core.pager itself
  };

  # gitUserName/gitUserEmail come from local.nix (see flake.nix), generated
  # by ./init.sh -- this repo carries no identity of its own (see CLAUDE.md's
  # Deliberate decisions). Not sourced from git/passwd's own auto-detection,
  # which falls back to the OS account's real name and is exactly what
  # caused the identity leak in CLAUDE.md's ~/.gitconfig gotcha.
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = gitUserName;
        email = gitUserEmail;
        signingkey = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      };
      gpg.format = "ssh";
      commit.gpgsign = true;
      init.defaultBranch = "main";
      core.editor = "code --wait";
      fetch.prune = true;
      pull.rebase = true;
      # Only "gh auth git-credential" actually speaks git's credential-helper
      # protocol (get/store/erase appended as an arg). A prior unscoped
      # `helper = "!gh auth token"` here didn't -- `gh auth token` takes no
      # positional args, so git calling it as `gh auth token get` errored
      # with "accepts 0 arg(s), received 1" on every push. Harmless (the
      # scoped helpers below already supplied the credential first) but
      # noisy and wrong; removed rather than left in.
      #
      # PATH-relative "gh", not a hardcoded /usr/bin/gh -- gh is now the
      # Nix-managed package (see home.packages) and resolves ahead of dnf's
      # copy on PATH the same way core.editor above relies on PATH already.
      credential = {
        "https://github.com".helper = [ "" "!gh auth git-credential" ];
        "https://gist.github.com".helper = [ "" "!gh auth git-credential" ];
      };
    };
  };

  # Fully declarative VS Code: the binary itself comes from pkgsUnstable (see
  # flake.nix) since the stable nixpkgs channel only backports security fixes
  # and would otherwise lag Microsoft's weekly releases. The extension list
  # lives here -- installing/removing an extension is "edit this list, run
  # rebuild.sh", not the marketplace UI. Extensions are sourced from the
  # nix-vscode-extensions marketplace mirror (vscodeMarketplace, see
  # flake.nix) rather than nixpkgs' own curated vscode-extensions set, which
  # only carries a handful of these.
  #
  # userSettings follows the same real-file pattern as WezTerm/herdr/lazygit
  # (see the recipe in CLAUDE.md) rather than an inline attrset: an inline
  # attrset renders through jsonFormat.generate into the read-only Nix store,
  # so VS Code itself can never write settings.json (EACCES on any in-editor
  # change). Passing userSettings a path instead makes home-manager symlink
  # it straight in, out-of-store -- see home/.config/Code/User/settings.json.
  programs.vscode = {
    enable = true;
    package = pkgsUnstable.vscode;
    profiles.default = {
      userSettings =
        config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/Code/User/settings.json";

      extensions = with vscodeMarketplace; [
        # already installed today
        ms-azuretools.vscode-bicep
        ms-dotnettools.vscode-dotnet-runtime
        ms-python.debugpy
        ms-python.python
        ms-python.vscode-pylance
        ms-python.vscode-python-envs
        ms-vscode-remote.remote-containers
        redhat.vscode-yaml
        streetsidesoftware.code-spell-checker
        github.vscode-github-actions
        davidanson.vscode-markdownlint
        eliostruyf.vscode-front-matter
        tomoki1207.pdf
        yzane.markdown-pdf
        jetbrains.resharper-code
        chrischinchilla.vale-vscode
        anthropic.claude-code

        # new, for the .NET/Go/Kubernetes/Azure/direnv workflow
        ms-dotnettools.csharp # base C# language server (csdevkit is proprietary/optional, add later if wanted)
        golang.go
        ms-kubernetes-tools.vscode-kubernetes-tools
        ms-azuretools.vscode-azureresourcegroups
        mkhl.direnv # loads each project's flake devShell into VS Code's terminal/LSPs
        marp-team.marp-vscode # slide preview/export for the marp-cli package above
      ];
    };
  };

  # Edit-in-place: the real file stays in this repo, ~/.config just points at it.
  # Proves the mkOutOfStoreSymlink mechanism before any real dotfiles are added.
  home.file.".config/starter".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/starter";
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/CLAUDE.md";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";
  home.file.".claude/statusline-command.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/statusline-command.sh";
  home.file.".config/wezterm/wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm/wezterm.lua";
  home.file.".config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr/config.toml";
  home.file.".config/lazygit/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/lazygit/config.yml";
  home.file.".config/btop/btop.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/btop/btop.conf";
  # gh writes this itself on `gh config set`/`gh alias set` -- see the
  # home.packages comment on why this bypasses programs.gh entirely.
  home.file.".config/gh/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/gh/config.yml";
  home.file.".config/vale/.vale.ini".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/vale/.vale.ini";
  # Only the custom style is Nix-managed -- `vale sync` (imperative, not
  # declarative; re-run after a fresh machine bootstrap with
  # `vale --config ~/.config/vale/.vale.ini sync`) downloads the write-good
  # package as a real sibling directory alongside this.
  home.file.".config/vale/styles/Dotfiles/NoEmDash.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/vale/styles/Dotfiles/NoEmDash.yml";
}
