{
  # Each key becomes an NXC composition name. A value may be one module or a
  # list for uniform nodes, or an attribute set for per-node software.
  mpi-hello = ./mpi-hello.nix;
  openqcd = ./openqcd.nix;
  multi-software-composition = [
    ./mpi-hello.nix
    ./openqcd.nix
  ];
  heterogeneous-cluster = {
    frontendModules = [
      ./mpi-hello.nix
      ./openqcd.nix
    ];
    computeNodes = {
      compute1 = {
        modules = [
          ./mpi-hello.nix
          ./openqcd.nix
        ];
        features = [
          "mpi-hello"
          "openqcd"
        ];
      };
      compute2 = {
        modules = [ ./openqcd.nix ];
        features = [ "openqcd" ];
      };
    };
  };
}
