{
  description = "Canonical ebuffer-backed HPC composition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";
    exaAtowPkgs.url = "git+https://gricad-gitlab.univ-grenoble-alpes.fr/exa-atow/exa-atow-nix-pkgs.git";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git?ref=25.05";
  };

  outputs =
    {
      self,
      nixpkgs,
      exaAtowPkgs,
      nxc,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ exaAtowPkgs.overlays.default ];
      };
      e2eFhs = pkgs.buildFHSEnv {
        name = "e2e-fhs";
        targetPkgs = fhsPkgs: [
          fhsPkgs.bash
          fhsPkgs.coreutils
          fhsPkgs.openssh
          fhsPkgs.rsync
          fhsPkgs.uv
        ];
        runScript = "bash";
      };
      composed = nxc.lib.compose {
        inherit nixpkgs system;
        compositions = import ./nix/lib/mk-compositions.nix;
        overlays = [ exaAtowPkgs.overlays.default ];
        extraConfigurations = [ exaAtowPkgs.nixosModules.default ];
      };
    in
    {
      packages.${system} = composed // {
        default = composed."openqcd::vm";
      };
      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [ nxc.devShells.${system}.nxcShell ];
        packages = [
          e2eFhs
          pkgs.jq
          pkgs.just
          pkgs.mdbook
          pkgs.uv
        ];
        shellHook = ''
          if [[ -x "$HOME/.local/bin/nix" ]]; then
            export PATH="$PATH:$HOME/.local/bin"
          fi
        '';
      };
    };
}
