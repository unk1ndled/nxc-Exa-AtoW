# Install OpenQCD without selecting a topology.
{ pkgs, ... }:
{
  imports = [ ./openmpi.nix ];
  environment.systemPackages = [ pkgs.openQCD ];
}
