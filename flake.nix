{
  description = "Canonical ebuffer-backed HPC composition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";
    ebufferpkgs.url = "git+https://gricad-gitlab.univ-grenoble-alpes.fr/exa-atow/ebuffer-nix-pkgs.git?ref=full-workflow";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git?ref=25.05";
  };

  outputs =
    {
      self,
      nixpkgs,
      ebufferpkgs,
      nxc,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ ebufferpkgs.overlays.default ];
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
        compositions = import ./compositions.nix;
        overlays = [ ebufferpkgs.overlays.default ];
        extraConfigurations = [ ebufferpkgs.nixosModules.default ];
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
          pkgs.mdbook
          pkgs.uv
        ];
      };
    };
}
