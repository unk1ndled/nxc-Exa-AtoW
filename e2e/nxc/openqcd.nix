let
  input = ../openqcd-ym1.in;
  job = ../../examples/openqcd-ym1.sbatch;
  testDir = "/users/user1/openqcd-e2e";
in
{
  frontendModule =
    { ... }:
    {
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
          cp "${input}" "${testDir}/openqcd-ym1.in"
          cp "${job}" "${testDir}/openqcd-ym1.sbatch"
          chmod 0755 "${testDir}/openqcd-ym1.sbatch"
          chown -R user1:users "${testDir}"
        '';
      };
    };

  testScript = ''
    frontend.succeed(
      "set -eu; "
      "systemctl start setup-openqcd-test.service; "
      "command -v ym1 >/dev/null; "
      "! command -v mpi-hello >/dev/null; "
      "su - user1 -c 'cd ${testDir} && "
      "sbatch --wait openqcd-ym1.sbatch openqcd-ym1.in'; "
      "test -s ${testDir}/openqcd-e2e.log; "
      "test -s ${testDir}/openqcd-e2en1"
    )
  '';
}
