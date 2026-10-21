# Every composition. Each node is plain NixOS configuration that enables the
# apps it should run; see apps/default.nix for the available apps.
let
  topology = import ./cluster/topology.nix;
  mpiHelloTest = import ./apps/mpi-hello/test.nix;
  openqcdTest = import ./apps/openqcd/test.nix;
in
{
  mpi-hello = topology {
    frontend.exa-atow.apps.mpi-hello = {
      enable = true;
      testFixtures = true;
    };
    computeNodes = {
      compute1.exa-atow.apps.mpi-hello.enable = true;
      compute2.exa-atow.apps.mpi-hello.enable = true;
    };
    testScript = mpiHelloTest.testScript;
  };

  openqcd = topology {
    frontend.exa-atow.apps.openqcd = {
      enable = true;
      testFixtures = true;
    };
    computeNodes = {
      compute1.exa-atow.apps.openqcd.enable = true;
      compute2.exa-atow.apps.openqcd.enable = true;
    };
    testScript = openqcdTest.testScript;
  };

  # Both apps on every node; both two-node jobs must pass.
  multi-software-composition = topology {
    frontend.exa-atow.apps = {
      mpi-hello = {
        enable = true;
        testFixtures = true;
      };
      openqcd = {
        enable = true;
        testFixtures = true;
      };
    };
    computeNodes = {
      compute1.exa-atow.apps = {
        mpi-hello.enable = true;
        openqcd.enable = true;
      };
      compute2.exa-atow.apps = {
        mpi-hello.enable = true;
        openqcd.enable = true;
      };
    };
    testScript = mpiHelloTest.testScript + openqcdTest.testScript;
  };

  # Different software per compute node. OpenQCD runs on both nodes; MPI Hello
  # is installed only on compute1.
  heterogeneous-cluster = topology {
    frontend.exa-atow.apps = {
      mpi-hello.enable = true;
      openqcd = {
        enable = true;
        testFixtures = true;
      };
    };
    computeNodes = {
      compute1.exa-atow.apps = {
        mpi-hello.enable = true;
        openqcd.enable = true;
      };
      compute2.exa-atow.apps.openqcd.enable = true;
    };
    testScript = openqcdTest.testScript + ''
      compute1.succeed("command -v mpi-hello")
      compute1.succeed("command -v ym1")
      compute2.fail("command -v mpi-hello")
      compute2.succeed("command -v ym1")
      controller.succeed(
        "scontrol show node compute1 --oneliner | grep -Eq 'AvailableFeatures=[^ ]*mpi-hello'"
      )
      controller.succeed(
        "scontrol show node compute2 --oneliner | grep -Eq 'AvailableFeatures=openqcd([[:space:]]|$)'"
      )
    '';
  };
}
