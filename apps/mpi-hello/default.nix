{ config, lib, pkgs, ... }:
let
  cfg = config.exa-atow.apps.mpi-hello;
  inherit (import ./test.nix) testDir;

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
  options.exa-atow.apps.mpi-hello = {
    enable = lib.mkEnableOption "the MPI Hello example";
    testFixtures = lib.mkEnableOption "staging the test job in user1's NFS home";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      exa-atow.openmpi.enable = true;
      environment.systemPackages = [ mpiHello ];
    })

    (lib.mkIf cfg.testFixtures {
      systemd.services.setup-mpi-hello-test = {
        description = "Populate the MPI Hello integration-test directory";
        wantedBy = [ "multi-user.target" ];
        after = [ "remote-fs.target" ];
        unitConfig.RequiresMountsFor = "/users";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          rm -rf "${testDir}"
          mkdir -p "${testDir}"
          cp "${./mpi-hello.sbatch}" "${testDir}/mpi-hello.sbatch"
          chmod 0755 "${testDir}/mpi-hello.sbatch"
          chown -R user1:users "${testDir}"
        '';
      };
    })
  ];
}
