{
  mpi-hello = import ./mpi-hello.nix { };
  openqcd = import ./openqcd.nix { };
  multi-software-composition = import ./multi-software-composition.nix;
  heterogeneous-cluster = import ./heterogeneous-cluster.nix;
}
