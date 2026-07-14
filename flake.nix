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
      composed = nxc.lib.compose {
        inherit nixpkgs system;
        compositions = {
          hpc = import ./composition.nix;
        };
        overlays = [ ebufferpkgs.overlays.default ];
        extraConfigurations = [ ebufferpkgs.nixosModules.default ];
      };
    in
    {
      packages.${system} = composed // {
        default = composed."hpc::vm";
      };
      devShells.${system}.default = nxc.devShells.${system}.nxcShell;
    };
}
