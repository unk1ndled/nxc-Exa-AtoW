{ config, lib, pkgs, ... }:
let
  cfg = config.exa-atow.pkgs.openqcd;
  inherit (import ./test.nix) testDir;
in
{
  options.exa-atow.pkgs.openqcd = {
    enable = lib.mkEnableOption "OpenQCD";
    package = lib.mkPackageOption pkgs "openqcd" { };
    testFixtures = lib.mkEnableOption "staging the test job and input in user1's NFS home";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      exa-atow.openmpi.enable = true;
      environment.systemPackages = [ cfg.package ];
    })

    (lib.mkIf cfg.testFixtures {
      systemd.services.setup-openqcd-test = {
        description = "Populate the OpenQCD integration-test directory";
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
          cp "${./openqcd-ym1.in}" "${testDir}/openqcd-ym1.in"
          cp "${./openqcd-ym1.sbatch}" "${testDir}/openqcd-ym1.sbatch"
          chmod 0755 "${testDir}/openqcd-ym1.sbatch"
          chown -R user1:users "${testDir}"
        '';
      };
    })
  ];
}
