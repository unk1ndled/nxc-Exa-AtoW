{ pkgs, ... }:
let
  # OpenQCD fixes both its MPI grid and local lattice at compile time. Keep the
  # overlay's two-rank grid, but use the smallest valid lattice for the E2E.
  openqcd = pkgs.openQCD.overrideAttrs (previousAttrs: {
    postPatch = (previousAttrs.postPatch or "") + ''
      substituteInPlace include/global.h \
        --replace-fail '#define L0 8' '#define L0 4' \
        --replace-fail '#define L1 8' '#define L1 4' \
        --replace-fail '#define L2 8' '#define L2 4' \
        --replace-fail '#define L3 8' '#define L3 4'
    '';
  });

  # The overlay installs ym1 below app/ rather than bin/. Re-expose the
  # configured executable through PATH without copying it.
  openqcdBins = pkgs.runCommand "openqcd-bins" { } ''
    mkdir -p "$out/bin"
    ln -s "${openqcd}/app/ym1" "$out/bin/ym1"
  '';
in
{
  imports = [ ./openmpi.nix ];
  environment.systemPackages = [ openqcdBins ];
}
