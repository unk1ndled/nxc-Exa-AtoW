# The compositions NXC builds. Each sets the options of cluster/topology.nix;
# the frontend and each compute group's `node` are plain NixOS configuration
# that enables the packages it should run (see pkgs/modules.nix).
#
# `openqcd` is the default cluster: ebuffer, ebservice, the SLURM frontend and
# controller, and the two compute nodes the OpenQCD ym1 job needs. To try
# another mix, add an entry here with its own compute groups and counts.
let
  topology = import ./cluster/topology.nix;
  openqcdTest = import ./pkgs/openqcd/test.nix;
in
{
  openqcd = topology {
    frontend.exa-atow.pkgs.openqcd = {
      enable = true;
      testFixtures = true;
    };
    computeGroups.compute = {
      count = 2;
      node.exa-atow.pkgs.openqcd.enable = true;
    };
    testScript = openqcdTest.testScript;
  };
}
