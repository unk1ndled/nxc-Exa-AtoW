{ pkgs, ... }:
{
  imports = [ ../openmpi.nix ];
  environment.systemPackages = [ pkgs.openQCD ];
}
