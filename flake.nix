{
  description = "A standard for making Nix-flake-first repos installable on any distribution";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # The pinned toolbox for check-templates.sh, locally and in CI: every binary the
      # lint runs comes from this lock, never from an unpinned registry lookup — the
      # same doctrine the ci skill prescribes to the repos this skill standardizes
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            actionlint
            shellcheck
            shfmt
            zsh
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
