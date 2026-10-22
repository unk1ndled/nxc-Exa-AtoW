# Runs on the frontend once the cluster is ready. Needs
# `exa-atow.pkgs.openqcd.testFixtures = true` on the frontend.
rec {
  testDir = "/users/user1/openqcd-e2e";

  testScript = ''
    frontend.succeed("systemctl start setup-openqcd-test.service")
    frontend.succeed("command -v ym1")
    frontend.succeed(
      "su - user1 -c 'cd ${testDir} && sbatch --wait openqcd-ym1.sbatch openqcd-ym1.in'"
    )
    frontend.succeed("test -s ${testDir}/openqcd-e2e.log")
    frontend.succeed("test -s ${testDir}/openqcd-e2en1")
  '';
}
