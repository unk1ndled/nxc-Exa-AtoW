{ config, lib, pkgs, ... }:
let
  cfg = config.exa-atow.pkgs.mpi-hello;
  inherit (import ./test.nix) testDir;
in
{
  options.exa-atow.pkgs.mpi-hello = {
    enable = lib.mkEnableOption "the MPI Hello example";
    package = lib.mkPackageOption pkgs "mpi-hello" { };
    testFixtures = lib.mkEnableOption "staging the test job in user1's NFS home";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      exa-atow.openmpi.enable = true;
      environment.systemPackages = [ cfg.package ];
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
