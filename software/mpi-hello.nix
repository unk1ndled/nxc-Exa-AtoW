{ pkgs, ... }:
let
  mpiHello = pkgs.stdenv.mkDerivation {
    pname = "mpi-hello";
    version = "1.0";
    src = ./mpi-hello.c;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.openmpi ];

    buildPhase = ''
      runHook preBuild
      mpicc "$src" -o mpi-hello
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 mpi-hello "$out/bin/mpi-hello"
      runHook postInstall
    '';
  };
in
{
  imports = [ ./openmpi.nix ];
  environment.systemPackages = [ mpiHello ];
}
