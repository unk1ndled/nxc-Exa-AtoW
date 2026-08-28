{
  # A profile is the public composition unit: module placement and the check
  # proving that placement belong to the same declaration.
  mpi-hello = {
    modules = [ ../modules/applications/mpi-hello.nix ];
    check = import ../../checks/nixos/profiles/mpi-hello.nix { };
  };

  openqcd = {
    modules = [ ../modules/applications/openqcd.nix ];
    check = import ../../checks/nixos/profiles/openqcd.nix { };
  };

  multi-software-composition = {
    modules = [
      ../modules/applications/mpi-hello.nix
      ../modules/applications/openqcd.nix
    ];
    check = import ../../checks/nixos/profiles/multi-software-composition.nix;
  };

  heterogeneous-cluster = {
    frontendModules = [
      ../modules/applications/mpi-hello.nix
      ../modules/applications/openqcd.nix
    ];
    computeNodes = {
      compute1 = {
        modules = [
          ../modules/applications/mpi-hello.nix
          ../modules/applications/openqcd.nix
        ];
        features = [
          "mpi-hello"
          "openqcd"
        ];
      };
      compute2 = {
        modules = [ ../modules/applications/openqcd.nix ];
        features = [ "openqcd" ];
      };
    };
    check = import ../../checks/nixos/profiles/heterogeneous-cluster.nix;
  };
}
