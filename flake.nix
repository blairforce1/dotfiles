{
  description = "dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Tracked only for pkgsUnstable.vscode (see home.nix) -- VS Code moves
    # fast upstream and the stable channel only backports security fixes, so
    # this one package is pinned to nixpkgs-unstable instead. Don't reach for
    # this input for anything else; keep the rest of the profile on the
    # stable release above.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Mirrors the whole VS Code marketplace as a Nix attrset (vscode-marketplace.<publisher>.<name>),
    # since nixpkgs' own curated vscode-extensions set only covers a handful of what's used here.
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, home-manager, nixpkgs, nixpkgs-unstable, nix-vscode-extensions }:
    let
      # Per-machine identity: OS username + git user.name/email. Generated
      # by ./init.sh into local.nix, which is gitignored -- deliberately not
      # part of this repo, so it carries no default identity of its own (see
      # CLAUDE.md's Deliberate decisions). Reading it via plain `import` (no
      # builtins.getEnv, no --impure) only works because every Nix
      # invocation in this repo targets a `path:` flake ref rather than the
      # default git-tracked-files-only source -- see CLAUDE.md.
      local =
        if builtins.pathExists ./local.nix then import ./local.nix
        else throw "local.nix is missing. Run ./init.sh first.";

      system = "x86_64-linux";

      # Built directly (rather than nixpkgs.legacyPackages.${system}) so
      # config.allowUnfree actually takes effect -- home-manager's own
      # nixpkgs.config option is a no-op once a pre-built pkgs is passed in.
      # Needed for ms-python.vscode-pylance (proprietary) in home.nix.
      #
      # The nix-vscode-extensions overlay is applied here (rather than using
      # its `extensions.${system}` flake output directly) specifically so the
      # marketplace extensions it builds inherit *this* allowUnfree=true --
      # that flake's own `extensions` output builds a separate internal pkgs
      # with allowUnfree hardcoded off, which would hit the same unfree error
      # Pylance hits below, with no way for us to override it.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ nix-vscode-extensions.overlays.default ];
      };

      # Separate instantiation, needed only for pkgsUnstable.vscode (see
      # home.nix) -- also needs its own allowUnfree since it's an entirely
      # separate nixpkgs from the one above.
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      homeConfig = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit pkgsUnstable;
          inherit (local) user gitUserName gitUserEmail;
          vscodeMarketplace = pkgs.nix-vscode-extensions.vscode-marketplace;
        };
        modules = [ ./home.nix ];
      };
    in
    {
      homeConfigurations.${local.user} = homeConfig;
    };
}
