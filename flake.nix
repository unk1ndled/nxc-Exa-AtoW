{
  description = "Canonical ebuffer-backed HPC composition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git?ref=main";
  };

  outputs =
    {
      self,
      nixpkgs,
      nxc,
    }:
    let
      system = "x86_64-linux";
      # Every package this repository defines.
      overlay = import ./pkgs/packages.nix;
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay ];
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
        overlays = [ overlay ];
        compositions = import ./compositions.nix;
      };
    in
    {
      # NXC adds a non-derivation compositionsNames list, which `nxc build`
      # without -C reads; packages must contain only derivations.
      packages.${system} = builtins.removeAttrs composed [ "compositionsNames" ] // {
        inherit (pkgs)
          ebuffer
          ebservice
          ebhelpers
          openqcd
          mpi-hello
          ebcommon
          remotemanager
          ebsclient
          ebstemplate
          ;
        # Not exposed here: ddfacet, kill-ms, ddf-pipeline, and ebuffer-tests
        # fetch private repositories over SSH when evaluated.
        default = composed."openqcd::vm";
      };
      # For other flakes: the packages and the two service modules.
      overlays.default = overlay;
      nixosModules = {
        ebuffer = ./pkgs/ebuffer;
        ebservice = ./pkgs/ebservice;
      };

      legacyPackages.${system}.compositionsNames = composed.compositionsNames;
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
