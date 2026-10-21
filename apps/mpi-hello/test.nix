# Runs on the frontend once the cluster is ready. Needs
# `exa-atow.apps.mpi-hello.testFixtures = true` on the frontend.
rec {
  testDir = "/users/user1/mpi-hello-e2e";

  testScript = ''
    frontend.succeed("systemctl start setup-mpi-hello-test.service")
    frontend.succeed("command -v mpi-hello")
    frontend.succeed("su - user1 -c 'cd ${testDir} && sbatch --wait mpi-hello.sbatch'")
    frontend.succeed("test -s ${testDir}/mpi-hello.out")
  '';
}
