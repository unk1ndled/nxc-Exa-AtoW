# Every package under pkgs/, as a nixpkgs overlay applied by flake.nix. A
# package's module (`<name>/default.nix`) installs it.
final: prev:
let
  callPythonPackage = prev.python3Packages.callPackage;
  ddf = import ./ddf-pipeline/packages.nix prev;
in
{
  # The platform services deployed by cluster/topology.nix.
  ebuffer = prev.python3Packages.callPackage ./ebuffer/package.nix { };
  ebservice = prev.python3Packages.callPackage ./ebservice/package.nix {
    inherit (final) ebuffer;
  };
  ebhelpers = prev.callPackage ./ebhelpers/package.nix { pkgs = prev; };

  # Scientific packages, enabled per node by compositions.
  openqcd = prev.callPackage ./openqcd/package.nix { };
  mpi-hello = prev.callPackage ./mpi-hello/package.nix { };
  inherit (ddf) ddfacet kill-ms ddf-pipeline;

  # Python libraries for talking to ebservice.
  ebcommon = callPythonPackage ./ebcommon/package.nix { };
  remotemanager = callPythonPackage ./remotemanager/package.nix { };
  ebsclient = callPythonPackage ./ebsclient/package.nix {
    inherit (final) ebcommon remotemanager;
  };
  ebstemplate = callPythonPackage ./ebstemplate/package.nix {
    inherit (final) ebcommon remotemanager ebsclient;
  };
  ebuffer-tests = callPythonPackage ./ebuffer-tests/package.nix {
    ebRepoSrc = prev.callPackage ./ebuffer-tests/src.nix { };
    inherit (final) ebcommon;
  };
}
