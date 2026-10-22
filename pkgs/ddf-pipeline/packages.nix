# The DDFacet stack: ddf-pipeline (./package.nix) and the packages it needs
# that nixpkgs does not provide (./deps). They build against their own Python
# with the compatibility overrides in ./python-overrides.nix, so nothing here
# replaces a global package. Only ddfacet, kill-ms, and ddf-pipeline are
# exported, by ../packages.nix.
pkgs:
let
  ddfPython = pkgs.python312.override {
    packageOverrides = import ./python-overrides.nix;
  };
  callPackage = pkgs.lib.callPackageWith (
    pkgs
    // {
      python3 = ddfPython;
      python3Packages = ddfPython.pkgs;
    }
  );

  casacore = callPackage ./deps/casacore.nix { };
  ephem = callPackage ./deps/ephem.nix { };
  dysco = callPackage ./deps/dysco.nix { inherit casacore; };
  lofar-beam = callPackage ./deps/lofar-beam.nix { inherit casacore; };
  python-casacore = callPackage ./deps/python-casacore.nix { inherit casacore; };
  pyephem = callPackage ./deps/pyephem.nix { inherit ephem; };
  extension-helpers = callPackage ./deps/extension-helpers.nix { };
  regions = callPackage ./deps/regions.nix { inherit extension-helpers; };
  sharedarray = callPackage ./deps/sharedarray.nix { };
  pyfftw = callPackage ./deps/pyfftw.nix { };
  codex-africanus = callPackage ./deps/codex-africanus.nix { };
  hpgeom = callPackage ./deps/hpgeom.nix { };
  healsparse = callPackage ./deps/healsparse.nix { inherit hpgeom; };
  skyproj = callPackage ./deps/skyproj.nix { inherit healsparse hpgeom; };
in
rec {
  ddfacet = callPackage ./deps/ddfacet.nix {
    inherit
      pyephem
      pyfftw
      lofar-beam
      regions
      sharedarray
      python-casacore
      codex-africanus
      skyproj
      ;
    mpiSupport = true;
    mpi = pkgs.openmpi;
  };
  kill-ms = callPackage ./deps/kill-ms.nix {
    inherit ddfacet;
    mpiSupport = true;
    mpi = pkgs.openmpi;
  };
  ddf-pipeline = callPackage ./package.nix {
    inherit
      ddfacet
      kill-ms
      dysco
      python-casacore
      ;
  };
}
