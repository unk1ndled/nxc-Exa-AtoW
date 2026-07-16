let
  job = ../../examples/mpi-hello.sbatch;
  testDir = "/users/user1/mpi-hello-e2e";
in
{
  frontendModule =
    { ... }:
    {
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
          cp "${job}" "${testDir}/mpi-hello.sbatch"
          chmod 0755 "${testDir}/mpi-hello.sbatch"
          chown -R user1:users "${testDir}"
        '';
      };
    };

  testScript = ''
    frontend.succeed(
      "set -eu; "
      "systemctl start setup-mpi-hello-test.service; "
      "command -v mpi-hello >/dev/null; "
      "! command -v ym1 >/dev/null; "
      "su - user1 -c 'cd ${testDir} && sbatch --wait mpi-hello.sbatch'; "
      "test -s ${testDir}/mpi-hello.out"
    )
  '';
}
